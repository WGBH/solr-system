require_relative '../../app/models/validated_pb_core'
require 'active_support'
require 'rails_helper'

describe 'Validated and plain PBCore' do
  pbc_xml = File.read('spec/fixtures/pbcore/good-all-fields.xml')

  describe ValidatedPBCore do
    describe 'valid docs' do
      Dir['spec/fixtures/pbcore/*.xml'].each do |path|
        it "accepts #{File.basename(path)}" do
          expect { ValidatedPBCore.new(File.read(path)) }.not_to raise_error
        end
      end
    end

    describe 'invalid docs' do
      #      it 'rejects missing closing brace' do
      #        invalid_pbcore = pbc_xml.sub(/>\s*$/, '')
      #        expect { ValidatedPBCore.new(invalid_pbcore) }.to(
      #          raise_error(/missing tag start/))
      #      end

      it 'rejects missing closing tag' do
        invalid_pbcore = pbc_xml.sub(/<\/[^>]+>\s*$/, '')
        expect { ValidatedPBCore.new(invalid_pbcore) }.to(
          raise_error(/Missing end tag/))
      end

      it 'rejects missing namespace' do
        invalid_pbcore = pbc_xml.sub(/xmlns=['"][^'"]+['"]/, '')
        expect { ValidatedPBCore.new(invalid_pbcore) }.to(
          raise_error(/Element 'pbcoreDescriptionDocument': No matching global declaration/))
      end

      it 'rejects empty element' do
        invalid_pbcore = pbc_xml.sub(/<pbcoreSubject>[^<]+</, '<pbcoreSubject><')
        expect { ValidatedPBCore.new(invalid_pbcore) }.to(
          raise_error(/Empty element in XML: <pbcoreSubject\/>/))
      end

      it 'rejects unexpected title type' do
        invalid_pbcore = pbc_xml.sub(/titleType="Series"/, 'titleType="Spanish Inquisition"')
        expect { ValidatedPBCore.new(invalid_pbcore) }.to(
          raise_error(/Attribute validation errors: Title: Spanish Inquisition/))
      end

      it 'rejects unexpected description type' do
        invalid_pbcore = pbc_xml.sub(/descriptionType="Series Description"/, 'descriptionType="Spanish Inquisition"')
        expect { ValidatedPBCore.new(invalid_pbcore) }.to(
          raise_error(/Attribute validation errors: Description: Spanish Inquisition/))
      end

      it 'rejects unexpected annotation type' do
        invalid_pbcore = pbc_xml.sub(/annotationType="Geoblock"/, 'annotationType="Spanish Inquisition"')
        expect { ValidatedPBCore.new(invalid_pbcore) }.to(
          raise_error(/Attribute validation errors: Annotation: Spanish Inquisition/))
      end

      it 'rejects unexpected outside URL' do
        invalid_pbcore = pbc_xml.sub(/Outside URL">http:\/\/americanarchive.org/, 'Outside URL">http://inquisition.es')
        expect { ValidatedPBCore.new(invalid_pbcore) }.to(
          raise_error(/Outside URL not of expected form/))
      end

      #      it 'rejects unknown media types at creation' do
      #        invalid_pbcore = pbc_xml.gsub(
      #          /<instantiationMediaType>[^<]+<\/instantiationMediaType>/,
      #          '<instantiationMediaType>unexpected</instantiationMediaType>')
      #        expect { ValidatedPBCore.new(invalid_pbcore) }.to(
      #          raise_error(/Unexpected media types: \["unexpected"\]/))
      #      end

      #      it 'rejects multi "Level of User Access"' do
      #        invalid_pbcore = pbc_xml.sub(
      #          /<pbcoreAnnotation/,
      #          "<pbcoreAnnotation annotationType='Level of User Access'>On Location</pbcoreAnnotation><pbcoreAnnotation")
      #        expect { ValidatedPBCore.new(invalid_pbcore) }.to(
      #          raise_error(/Should have at most 1 "Level of User Access" annotation/))
      #      end

      #      it 'rejects digitized w/o "Level of User Access"' do
      #        invalid_pbcore = pbc_xml.gsub(
      #          /<pbcoreAnnotation annotationType='Level of User Access'>[^<]+<[^>]+>/,
      #          '')
      #        expect { ValidatedPBCore.new(invalid_pbcore) }.to(
      #          raise_error(/Should have "Level of User Access" annotation if digitized/))
      #      end

      #      it 'rejects undigitized w/ "Level of User Access"' do
      #        invalid_pbcore = pbc_xml.gsub(
      #          /<pbcoreIdentifier source='Sony Ci'>[^<]+<[^>]+>/,
      #          '')
      #        expect { ValidatedPBCore.new(invalid_pbcore) }.to(
      #          raise_error(/Should not have "Level of User Access" annotation if not digitized/))
      #      end

      #      it 'rejects "Outside URL" if not explicitly ORR' do
      #        invalid_pbcore = pbc_xml.gsub( # First make it un-digitized
      #          /<pbcoreIdentifier source='Sony Ci'>[^<]+<[^>]+>/,
      #          '').gsub( # Then remove access
      #            /<pbcoreAnnotation annotationType='Level of User Access'>[^<]+<[^>]+>/,
      #            '')
      #        expect { ValidatedPBCore.new(invalid_pbcore) }.to(
      #          raise_error(/If there is an Outside URL, the record must be explicitly public/))
      #      end
    end
  end

  describe PBCore do
    describe 'full' do
      id = 'A_00000000_MOCK'
      base = 'https://s3.amazonaws.com/openvault.wgbh.org/catalog'
      assertions = {
        series_title: 'SERIES',
        program_title: 'PROGRAM',
        program_number: 'PROGRAM-NUMBER',
        asset_title: 'ASSET',
        date: '12/31/1999',
        year: '1999',
        title: 'SERIES; PROGRAM; ASSET',
        short_title: 'ASSET',
        duration: '01:23:45',
        asset_type: 'Broadcast program',
        this_isnt_all?: true,
        series_description: 'SERIES-DESCRIPTION',
        program_description: 'PROGRAM-DESCRIPTION',
        asset_description: 'ASSET-DESCRIPTION',
        id: 'A_00000000_MOCK',
        thumbnail_src: "#{base}/asset_thumbnails/#{id}.jpg",
        proxy_srcs: %w(mp3).map { |ext| "#{base}/asset_proxies/#{id}.#{ext}" },
        rights_summary: 'RIGHTS-SUMMARY',
        contributors: [
          PBCoreNameRole.new('contributor', 'CONTRIBUTOR-NAME-1', 'CONTRIBUTOR-ROLE-1'),
          PBCoreNameRole.new('contributor', 'CONTRIBUTOR-NAME-2', 'CONTRIBUTOR-ROLE-2')],
        creators: [
          PBCoreNameRole.new('creator', 'CREATOR-NAME-1', 'CREATOR-ROLE-1'),
          PBCoreNameRole.new('creator', 'CREATOR-NAME-2', 'CREATOR-ROLE-2')],
        publishers: ['PUBLISHER-1', 'PUBLISHER-2'],
        media_type: 'Audio',
        video?: false,
        audio?: true,
        image?: false,
        digitized?: true,
        access: ['All Records', 'Available Online'],
        subjects: ['SUBJECT-1', 'SUBJECT-2'],
        genres: ['GENRE-1', 'GENRE-2'],
        topics: ['TOPIC-1', 'TOPIC-2'],
        locations: ['LOCATION-1', 'LOCATION-2'],
        blocked_country_codes: ['---'],
        password_required?: true,
        aapb_url: 'http://americanarchive.org/',
        boston_tv_news_url: nil,
        playlist_group: 'demo',
        playlist_order: 1,
        playlist_map: { 1 => 'A_00000000_MOCK', 2 => 'A_00B0C50853C64A71935737EF7A4DA66C' },
        playlist_next_id: 'A_00B0C50853C64A71935737EF7A4DA66C',
        playlist_prev_id: nil,
        extensions: %w(mp3),
        outside_url: 'http://americanarchive.org/' }
      assertions[:to_solr] = assertions.slice(
        :id, :title, :short_title, :thumbnail_src, :year, :series_title, :program_title,
        :subjects, :locations, :access, :genres, :topics, :asset_type, :media_type,
        :playlist_group, :playlist_order)
                             .merge(xml: pbc_xml,
                                    text: ['SERIES', 'PROGRAM', 'PROGRAM-NUMBER', 'ASSET', 'SERIES; PROGRAM; ASSET',
                                           '12/31/1999', '1999',
                                           'SERIES-DESCRIPTION', 'PROGRAM-DESCRIPTION', 'ASSET-DESCRIPTION',
                                           'CONTRIBUTOR-NAME-1', 'CONTRIBUTOR-ROLE-1',
                                           'CONTRIBUTOR-NAME-2', 'CONTRIBUTOR-ROLE-2',
                                           'CREATOR-NAME-1', 'CREATOR-ROLE-1',
                                           'CREATOR-NAME-2', 'CREATOR-ROLE-2',
                                           'PUBLISHER-1', 'PUBLISHER-2',
                                           'SUBJECT-1', 'SUBJECT-2',
                                           'LOCATION-1', 'LOCATION-2',
                                           'GENRE-1', 'GENRE-2',
                                           'TOPIC-1', 'TOPIC-2',
                                           'RIGHTS-SUMMARY'])

      pbc = PBCore.new(pbc_xml)

      assertions.each do |method, value|
        it "\##{method} method works" do
          expect(pbc.send(method)).to eq(value)
        end
      end

      it 'tests everthing' do
        expect(assertions.keys.sort).to eq(PBCore.instance_methods(false).sort)
      end
    end
  end
end
