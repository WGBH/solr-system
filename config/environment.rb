# Load the Rails application.
require File.expand_path('../application', __FILE__)

# Initialize the Rails application.
Rails.application.initialize!

# Monkey-patches which might be made into PRs?

module Blacklight::Solr
  class SearchBuilder < Blacklight::SearchBuilder
    def facet_value_to_fq_string(facet_field, value)
      facet_config = blacklight_config.facet_fields[facet_field]

      local_params = []
      local_params << "tag=#{facet_config.tag}" if facet_config and facet_config.tag

      prefix = ''
      prefix = "{!#{local_params.join(' ')}}" unless local_params.empty?

      case
      when (facet_config and facet_config.query)
        facet_config.query[value][:fq]
      when (facet_config and facet_config.date)
        # in solr 3.2+, this could be replaced by a !term query
        "#{prefix}#{facet_field}:#{RSolr.solr_escape(value)}"
      when (value.is_a?(DateTime) or value.is_a?(Date) or value.is_a?(Time))
        "#{prefix}#{facet_field}:#{RSolr.solr_escape(value.to_time.utc.strftime('%Y-%m-%dT%H:%M:%SZ'))}"
      when (value.is_a?(TrueClass) or value.is_a?(FalseClass) or value == 'true' or value == 'false'),
             (value.is_a?(Integer) or (value.to_i.to_s == value if value.respond_to? :to_i)),
             (value.is_a?(Float) or (value.to_f.to_s == value if value.respond_to? :to_f))
        "#{prefix}#{facet_field}:#{RSolr.solr_escape(value.to_s)}"
      when value.is_a?(Range)
        "#{prefix}#{facet_field}:[#{value.first} TO #{value.last}]"
      else
        # Before monkey-patching:
        # "{!raw f=#{facet_field}#{(" " + local_params.join(" ")) unless local_params.empty?}}#{value}"
        # Do all the extra parts matter?
        # BEGIN patch replace
        prefix + value.split(OpenVault::QUERY_OR).map { |single| "#{facet_field}:\"#{single}\"" }.join(' ')
        # END patch
      end
    end
  end
end

module Blacklight::UrlHelperBehavior
  def add_facet_params(field, item, source_params = params)
    field = item.field if item.respond_to? :field

    facet_config = facet_configuration_for_field(field)

    url_field = facet_config.key

    value = facet_value_for_facet_item(item)

    p = reset_search_params(source_params)
    p[:f] = (p[:f] || {}).dup # the command above is not deep in rails3, !@#$!@#$
    p[:f][url_field] = (p[:f][url_field] || []).dup

    p[:f][url_field] = [] if facet_config.single and !p[:f][url_field].empty?

    p[:f][url_field].push(value)
    # BEGIN patch addition:
    p[:f] = Hash[p[:f].map { |k, v| [k, [v.join(OpenVault::QUERY_OR)]] }]
    # END patch

    if item and item.respond_to?(:fq) and item.fq
      item.fq.each do |f, v|
        p = add_facet_params(f, v, p)
      end
    end

    p
  end

  def remove_facet_params(field, item, source_params = params)
    field = item.field if item.respond_to? :field

    facet_config = facet_configuration_for_field(field)

    url_field = facet_config.key

    value = facet_value_for_facet_item(item)

    p = reset_search_params(source_params)
    # need to dup the facet values too,
    # if the values aren't dup'd, then the values
    # from the session will get remove in the show view...
    p[:f] = (p[:f] || {}).dup
    p[:f][url_field] = (p[:f][url_field] || []).dup
    p[:f][url_field] = p[:f][url_field] - [value]
    # The line above removes an exact match (ie in the filter list).
    # The line below removes just one term (ie in the side bar).
    # BEGIN patch addition
    p[:f][url_field] = (p[:f][url_field].map { |f| f.split(OpenVault::QUERY_OR) }.map { |terms| terms - [value] }).map { |terms| terms.join(' OR ') }
    # END patch
    p[:f].delete(url_field) if p[:f][url_field].size == 0
    p.delete(:f) if p[:f].empty?
    p
  end
end

module Blacklight::FacetsHelperBehavior
  def facet_in_params?(field, item)
    field = item.field if item and item.respond_to? :field

    value = facet_value_for_facet_item(item)

    params[:f] and params[:f][field] and
      # Before:
      #   params[:f][field].include?(value)
      # BEGIN patch replace
      params[:f][field].any? { |f| f.split(OpenVault::QUERY_OR).include?(value) }
    # END patch
  end

  # TODO: I don't redefine this method, but for some reason my custom render_facet_value
  # fails with "undefined method" unless I provide the def here.
  def path_for_facet(facet_field, item)
    facet_config = facet_configuration_for_field(facet_field)
    if facet_config.url_method
      send(facet_config.url_method, facet_field, item)
    else
      search_action_path(add_facet_params_and_redirect(facet_field, item))
    end
  end

  def render_facet_value(facet_field, item, options = {})
    path = path_for_facet(facet_field, item)
    # Before:
    # content_tag(:span, :class => "facet-label") do
    #  link_to_unless(options[:suppress_link], facet_display_value(facet_field, item), path, :class=>"facet_select")
    # end + render_facet_count(item.hits)
    content_tag(:span, class: 'facet-label') do
      link_to_unless(
        options[:suppress_link],
        facet_display_value(facet_field, item),
        path,
        class: 'facet_select',
        title: item.hits == 1 ? 'Only 1 item' : "#{item.hits} items"
      )
    end
  end

  def render_selected_facet_value(facet_field, item)
    # Before:
    # content_tag(:span, :class => "facet-label") do
    # content_tag(:span, facet_display_value(facet_field, item), :class => "selected") +
    # # remove link
    # link_to(content_tag(:span, '', :class => "glyphicon glyphicon-remove") + content_tag(:span, '[remove]', :class => 'sr-only'), search_action_path(remove_facet_params(facet_field, item, params)), :class=>"remove")
    # end + render_facet_count(item.hits, :classes => ["selected"])
    content_tag(:span, class: 'facet-label selected') do
      link_to(
        facet_display_value(facet_field, item),
        search_action_path(remove_facet_params(facet_field, item, params)),
        class: 'facet_select'
      )
    end
  end

  def should_collapse_facet?(_facet_field)
    # Before:
    #   !facet_field_in_params?(facet_field.field) && facet_field.collapse
    # BEGIN patch
    true # We never expand facets on load.
    # END patch
  end

  def render_facet_limit_list(items, facet_field, wrapping_element = :li)
    # OV: Changed from "paginator.items" to plain "items"
    safe_join(items.items
      .map { |item| render_facet_item(facet_field, item) }.compact
      .map { |item| content_tag(wrapping_element, item) }
             )
  end
end

module RangeLimitHelper
  def should_show_limit(_solr_field)
    true

    # We want the UI to be more consistent, even if it's not more useful.
    # Originally:
    # Show the limit area if:
    # 1) we have a limit already set
    # OR
    # 2) stats show max > min, OR
    # 3) count > 0 if no stats available.

    #    stats = stats_for_field(solr_field)
    #
    #    (params["range"] && params["range"][solr_field]) ||
    #    (  stats &&
    #      stats["max"] > stats["min"]) ||
    #    ( !stats  && @response.total > 0 )
  end
end
