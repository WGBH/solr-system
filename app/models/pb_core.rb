require 'rexml/document'
require 'rexml/xpath'
require 'solrizer'
require 'rsolr'
require_relative '../../lib/open_vault'
require_relative 'xml_backed'
require_relative 'pb_core_name_role'
require_relative '../../lib/formatter'

class PBCore # rubocop:disable Metrics/ClassLength
  # rubocop:disable Style/EmptyLineBetweenDefs
  include XmlBacked

  def id
    @id ||= xpath('/*/pbcoreIdentifier[@source="Open Vault UID"]')
  end

  def series_title
    @series_title ||= xpath_optional('/*/pbcoreTitle[@titleType="Series"]')
  end
  def program_title
    @program_title ||= xpath_optional('/*/pbcoreTitle[@titleType="Program"]')
  end
  def program_number
    @program_number ||= xpath_optional('/*/pbcoreTitle[@titleType="Program Number"]')
  end
  def asset_title
    @asset_title ||= xpath_optional('/*/pbcoreTitle[@titleType="Open Vault Title"]')
  end

  def title
    @title ||= [series_title, program_title, asset_title].select { |x| x }.join('; ')
  end
  def short_title
    @short_title ||= (asset_title || program_title || series_title)
                     .gsub(/^.*Interview\s+with\s+/i, '')
    # N-of-N will be stripped downstream, but we keep it here
    # so that we can distinguish the 1-of-N from the others.
  end

  def date
    @date ||= xpath_optional('/*/pbcoreAssetDate[@dateType="Item Date"]')
  end
  def year
    @year ||= date.match(/(\d{4})/)[1] if date
  end

  def duration
    @duration ||= begin
      full = xpath_optional('/*/pbcoreAnnotation[@annotationType="Duration"]')
      full.gsub(/(\d\d:\d\d:\d\d):\d\d/, '\1') if full
    end
  end
  def asset_type
    @asset_type ||= xpath('/*/pbcoreAssetType')
  end
  def this_isnt_all?
    asset_type == 'Broadcast program'
  end
  def series_description
    @series_description ||= xpath_optional('/*/pbcoreDescription[@descriptionType="Series Description"]')
  end
  def program_description
    @program_description ||= xpath_optional('/*/pbcoreDescription[@descriptionType="Program Description"]')
  end
  def asset_description
    @asset_description ||= xpath_optional('/*/pbcoreDescription[@descriptionType="Asset Description"]')
  end
  def contributors
    @contributors ||= REXML::XPath.match(@doc, '/*/pbcoreContributor').map do|rexml|
      PBCoreNameRole.new(rexml)
    end
  end
  def creators
    @creators ||= REXML::XPath.match(@doc, '/*/pbcoreCreator').map do|rexml|
      PBCoreNameRole.new(rexml)
    end
  end
  def publishers
    @publishers ||= xpaths('/*/pbcorePublisher/publisher')
  end
  def subjects
    @subjects ||= xpaths('/*/pbcoreSubject')
  end
  def locations
    @locations ||= xpaths('/*/pbcoreCoverage[coverageType="Spatial"]/coverage')
  end
  def genres
    @genre ||= xpaths('/*/pbcoreGenre[@source="Series Genre"]')
  end
  def topics
    @topic ||= xpaths('/*/pbcoreGenre[@source="Series Topic"]')
  end

  def rights_summary
    @rights_summary ||= xpath_optional('/*/pbcoreRightsSummary/rightsSummary')
  end

  VIDEO = 'Video'
  AUDIO = 'Audio'
  IMAGE = 'Image'
  def media_type
    @media_type ||= xpath('/*/pbcoreAnnotation[@annotationType="Media Type"]')
  end
  def video?
    media_type == VIDEO
  end
  def audio?
    media_type == AUDIO
  end
  def image?
    media_type == IMAGE
  end
  def extensions
    case media_type
    when VIDEO
      %w(webm mp4)
    when AUDIO
      ['mp3']
    when IMAGE
      ['jpg']
    else
      fail("Unrecognized media_type: #{media_type}")
    end
  end

  URL_BASE = 'https://s3.amazonaws.com/openvault.wgbh.org/catalog'
  def thumbnail_src
    @thumb_src ||= begin
      if xpath_boolean('/*/pbcoreAnnotation[@annotationType="Thumbnail"]')
        "#{URL_BASE}/asset_thumbnails/#{id}.jpg"
      elsif aapb_url && media_type == VIDEO # TODO: Could some AAPB audio have thumbnails?
        aapb_id = aapb_url.gsub(/.*\//, '')
        "http://s3.amazonaws.com/americanarchive.org/thumbnail/#{aapb_id}.jpg"
      else
        case media_type
        when VIDEO
          digitized? ? '/images/video_digitized_icon.png' : '/images/video_undigitized_icon.png'
        when AUDIO
          digitized? ? '/images/audio_digitized_icon.png' : '/images/audio_undigitized_icon.png'
        when IMAGE
          '/images/image_icon.png' # TODO: Should we ever reach this?
        else
          fail("Unrecognized media_type: #{media_type}")
        end
      end
    end
    # TODO: some have defaults?
  end
  ONLINE = 'Available Online'
  ALL = 'All Records'
  def access
    @access ||=
      [ALL].tap do |access|
        access << ONLINE if digitized?
      end
  end
  def digitized?
    # (Cast to boolean)
    (outside_url ? true : false) || xpath_boolean('/*/pbcoreAnnotation[@annotationType="Digitized"]')
  end
  def proxy_srcs
    @proxy_srcs ||=
      if xpath_boolean('/*/pbcoreAnnotation[@annotationType="Digitized"]')
        extensions.map { |ext| "#{URL_BASE}/asset_proxies/#{id}.#{ext}" }
      else
        []
      end
  end

  def blocked_country_codes
    @blocked_country_codes ||=
      xpaths('/*/pbcoreAnnotation[@annotationType="Geoblock"]')
  end

  def password_required?
    xpath_boolean('/*/pbcoreAnnotation[@annotationType="Password Restriction"]')
  end

  AAPB_RE = /^http:\/\/americanarchive.org\//
  NEWS_RE = /^http:\/\/bostonlocaltv.org\//
  def outside_url
    @outside_url ||=
      xpath_optional('/*/pbcoreAnnotation[@annotationType="Outside URL"]')
  end
  def aapb_url
    @aapb_url ||= begin
      outside_url if outside_url && outside_url.match(AAPB_RE)
    end
  end
  def boston_tv_news_url
    @boston_tv_news_url ||= begin
      outside_url if outside_url && outside_url.match(NEWS_RE)
    end
  end

  def playlist_group
    @playlist_group ||= xpath_optional('/*/pbcoreAnnotation[@annotationType="Playlist Group"]')
  end
  def playlist_order
    @playlist_order ||= xpath_optional('/*/pbcoreAnnotation[@annotationType="Playlist Order"]').to_i
  end
  def playlist_map
    @playlist_map ||= begin
      response = RSolr.connect(url: 'http://localhost:8983/solr/')
                 .get('select', params: {
                        'fl' => 'playlist_order,id',
                        'fq' => "playlist_group:#{playlist_group}",
                        'rows' => '100'
                      }
                     )
      Hash[response['response']['docs'].map { |doc| [doc['playlist_order'].to_i, doc['id']] }]
    end if playlist_group
  end
  def playlist_next_id
    @playlist_next_id ||= begin
      playlist_map[playlist_map.keys.select { |k| k > playlist_order }.min]
    end if playlist_map
  end
  def playlist_prev_id
    @playlist_prev_id ||= begin
      playlist_map[playlist_map.keys.select { |k| k < playlist_order }.max]
    end if playlist_map
  end

  # rubocop:enable Style/EmptyLineBetweenDefs

  def to_solr
    {
      id: id,
      xml: @xml,

      # indexed:
      text: text,

      # *************************************
      #     Keep in sync with schema.xml
      # *************************************

      title: title,
      thumbnail_src: thumbnail_src,
      short_title: short_title,

      year: year,

      # links from details and series pages:
      series_title: series_title,
      program_title: program_title,

      subjects: subjects,
      locations: locations,

      # UI facets
      access: access,

      genres: genres,
      topics: topics,

      asset_type: asset_type,
      media_type: media_type,

      # playlist
      playlist_group: playlist_group,
      playlist_order: playlist_order
    }
  end

  private

  # These methods are only used by to_solr.

  def text
    @text = begin
      ignores = [
        :text, :to_solr, :id, :duration, :short_title,
        :media_type, :asset_type, :access, :digitized?,
        :extensions, :blocked_country_codes,
        :playlist_group, :playlist_order, :playlist_map,
        :playlist_next_id, :playlist_prev_is
      ]
      (PBCore.instance_methods(false) - ignores)
      .reject { |method| method =~ /(\?|srcs?|url)$/ } # skip booleans, urls
      .map { |method| send(method) } # method -> value
      .select { |x| x } # skip nils
      .flatten # flattens list accessors
      .map { |x| x.respond_to?(:to_a) ? x.to_a : x } # get elements of compounds
      .flatten.uniq
    end
  end
end
