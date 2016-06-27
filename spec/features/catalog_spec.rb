require 'rails_helper'
require_relative '../support/validation_helper'
require_relative '../../scripts/lib/pb_core_ingester'

describe 'Catalog' do
  before(:all) do
    PBCoreIngester.load_fixtures
  end

  def expect_count(count)
    case count
    when 0
      expect(page).to have_text('Consider using other search terms')
    when 1
      expect(page).to have_text('1 entry found')
    else
      expect(page).to have_text("1 - #{[count, 12].min} of #{count}")
    end
  end

  describe '#index' do
    it 'loads the index page' do
      visit '/catalog'
      expect(page.status_code).to eq(200)
      expect_fuzzy_xml
    end

    it 'redirects missing access' do
      visit '/catalog?q='
      expect(page.status_code).to eq(200)
      expect(URI.parse(current_url).query).to eq('f[access][]=Available+Online&q=')
      expect(page).not_to have_content 'You searched for:'
    end

    it 'redirects missing everything' do
      visit '/catalog?'
      expect(page.status_code).to eq(200)
      expect(URI.parse(current_url).query).to eq('f[access][]=Available+Online')
      expect(page).not_to have_content 'You searched for:'
    end

    it 'has a helpful all-records link' do
      visit '/catalog?q=asdfasfasdf'
      expect(page.status_code).to eq(200)
      expect(page).to have_content 'Or search all records, not just media.'
      expect_fuzzy_xml
    end

    it 'has dead-end no-results' do
      visit '/catalog?q=asdfasfasdf&f[access][]=All+Records'
      expect(page.status_code).to eq(200)
      expect(page).to have_content 'Consider using other search terms or removing filters.'
      expect(page).to have_content 'You searched for:'
      expect_fuzzy_xml
    end

    it 'sorts by title ascending, ignoring articles' do
      visit '/catalog?f[access][]=All+Records&q=sort&sort=title+asc'
      expect(page.status_code).to eq(200)
      expect(page).to have_content 'You searched for:'
      expect_fuzzy_xml
      expect(page.all('.info').map(&:text)).to eq([
        'An. stays: not an article: sort 0',
        'The removed: sort 1',
        'An REMOVED: SORT 2',
        'A removed: sort 3'
      ])
    end

    it 'sorts by title descending, ignoring articles' do
      visit '/catalog?f[access][]=All+Records&q=sort&sort=title+desc'
      expect(page.status_code).to eq(200)
      expect(page).to have_content 'You searched for:'
      expect_fuzzy_xml
      expect(page.all('.info').map(&:text)).to eq([
        'A removed: sort 3',
        'An REMOVED: SORT 2',
        'The removed: sort 1',
        'An. stays: not an article: sort 0'
      ])
    end

    describe 'support facet ORs' do
      describe 'URL support' do
        # OR is supported on all facets, even if not in the UI.
        assertions = [
          ['media_type', 'Video', 0],
          ['media_type', 'Audio', 2],
          ['media_type', 'Image', 1],
          ['media_type', 'Video OR Audio', 2],
          ['media_type', 'Audio OR Image', 3],
          ['media_type', 'Image OR Video', 1],
          ['media_type', 'Video OR Audio OR Image', 3],
          ['series_title', 'SERIES', 1],
          ['program_title', 'PROGRAM', 1],
          ['genres', 'GENRE-1', 1],
          ['topics', 'TOPIC-1', 1],
          ['asset_type', 'Original footage', 2]
        ]
        assertions.each do |facet, value, value_count|
          url = '/catalog?' + {
            f: { access: [PBCore::ONLINE],
                 facet => [value] }
          }.to_query
          describe "visiting #{url}" do
            it "has #{value_count} results" do
              visit url
              expect_count(value_count)
            end
          end
        end
      end
    end

    def url_params_to_hash(url)
      CGI.parse(URI.parse(url).query)
    end

    it 'Preserves facets with new searches' do
      orig_url = '/catalog?f[access][]=X&f[asset_type][]=X&f[genres][]=X&f[media_type][]=X&f[topics][]=X&q=X'
      visit orig_url
      find('//form/button').click
      expect(url_params_to_hash(current_url)).to eq(url_params_to_hash(orig_url))
    end

    it 'Gives 404 for bad query' do
      visit '/catalog?f[access]='
      expect(page.status_code).to eq(404)
    end
  end

  describe '#show' do
    describe 'all fixtures' do
      Dir['spec/fixtures/pbcore/*.xml'].each do |fixture|
        doc = Nokogiri::XML(File.read(fixture))
        doc.remove_namespaces!
        id = doc.xpath('/*/pbcoreIdentifier[@source="Open Vault UID"]').text
        path = "/catalog/#{id}"
        it "loads #{path}" do
          visit path
          expect(page.status_code).to eq(200)
          expect_fuzzy_xml
        end
      end
    end

    it 'Respects line-breaks in source data' do
      visit '/catalog/A_00B0C50853C64A71935737EF7A4DA66C'
      expect(page.html).to match(/<p>Line breaks\s+do not matter, but<\/p><p>empty lines do\.<\/p>/)
    end

    it 'Has extra messaging, as appropriate' do
      visit '/catalog/A_00000000_MOCK'
      expect(page.html).to match(/More material is available from this program at the WGBH Archive/)
    end

    it 'Gives 404 for bad item' do
      visit '/catalog/nope'
      expect(page.status_code).to eq(404)
    end
  end
end
