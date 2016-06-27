require 'nokogiri'
require 'curl'
require_relative 'pb_core'

class ValidatedPBCore < PBCore
  SCHEMA = Nokogiri::XML::Schema(File.read('lib/pbcore-2.1.xsd'))

  def initialize(xml)
    super(xml)
    schema_validate
    attribute_validate
    method_validate
    value_validate
    url_validate
  end

  private

  def schema_validate
    document = Nokogiri::XML(@xml)
    errors = SCHEMA.validate(document)
    return if errors.empty?
    fail 'Schema validation errors: ' + errors.join("\n")
  end

  def unexpected_attributes(el, expected)
    (xpaths("/*/pbcore#{el}/@#{el.downcase}Type") - expected).map { |val| "#{el}: #{val}" }
  end

  def attribute_validate
    errors = []
    errors += unexpected_attributes(
      'Title',
      ['Series', 'Program', 'Program Number', 'Open Vault Title'])
    errors += unexpected_attributes(
      'Description',
      ['Series Description', 'Program Description', 'Asset Description'])
    # For reference:
    # grep pbcoreAnnotation app/models/pb_core.rb | ruby -pne '$_.gsub!(/.*@annotationType="/,"");$_.gsub!(/".*/,"");$_="\"#{$_.strip}\",\n"' | sort | uniq
    errors += unexpected_attributes(
      'Annotation',
      [
        'Digitized',
        'Duration',
        'Geoblock',
        'Media Type',
        'Outside URL',
        'Password Restriction',
        'Playlist Group',
        'Playlist Order',
        'Thumbnail',
        'Transcript'])
    return if errors.empty?
    fail 'Attribute validation errors: ' + errors.join("\n")
  end

  def method_validate
    # Warm the object and check for missing data, beyond what the schema enforces.
    errors = []
    (PBCore.instance_methods(false) - [:to_solr]).each do |method|
      begin
        send(method)
      rescue => e
        errors << (["'##{method}' failed: #{e.message}"] + e.backtrace[0..2]).join("\n")
      end
    end
    return if errors.empty?
    fail 'Method validation errors: ' + errors.join("\n")
  end

  def value_validate
    errors = []
    if outside_url && !(aapb_url || boston_tv_news_url)
      errors << "Outside URL not of expected form: #{outside_url}"
    end
    unless blocked_country_codes.all? { |code| code.match(/^[A-Z-]{3}$/) }
      errors << "Unexpected blocked country codes: #{blocked_country_codes}"
    end
    unless id[0].upcase == media_type[0]
      errors << "First char of ID does not match media: #{id[0].upcase} != #{media_type[0]}"
    end
    return if errors.empty?
    fail 'Value validation errors: ' + errors.join("\n")
  end

  def url_validate
    errors = []
    expected_url_methods = Set.new([
      :outside_url, :aapb_url, :boston_tv_news_url,
      :thumbnail_src, :proxy_srcs
    ])
    url_methods = Set.new(PBCore.instance_methods(false).grep(/(src|url)s?/))
    fail("Unexpected URL methods: #{url_methods.sort} != #{expected_url_methods.sort}") if url_methods != expected_url_methods
    url_methods.each do |method|
      urls = [send(method)].select { |u| u }.flatten
      urls.each do |url|
        begin
          if url.match(/^\//)
            # This is to make sure our placeholder icons are in place:
            path = __dir__ + '/../../public' + url
            errors << "No file at #{path}" unless File.exist?(path)
          else
            Curl::Easy.new(url).tap do |curl|
              curl.headers['Referer'] = 'http://openvault.wgbh.org/'
              curl.headers['User-Agent'] = 'openvault-spider'
              curl.http_head
              unless curl.response_code == 200
                errors << "HTTP HEAD from ##{method} not 200: #{curl.status}"
              end
            end
          end
        rescue => e
          errors << (["'##{method}' failed: #{e.message}"] + e.backtrace[0..2]).join("\n")
        end
      end
    end
    return if errors.empty?
    fail 'Method validation errors: ' + errors.join("\n")
  end
end
