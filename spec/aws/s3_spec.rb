require 'aws-sdk'
require 'json'
require 'curl'
require 'rails_helper'

describe 'S3' do
  describe 'policy implementation', not_on_travis: true do
    def to_pretty_json(string_io)
      JSON.pretty_generate(JSON.parse(string_io.string))
    end
    let(:client) { Aws::S3::Client.new(region: 'us-east-1') }
    it 'has expected policy' do
      expect(
        to_pretty_json(client.get_bucket_policy(bucket: 'openvault.wgbh.org').policy)
      ).to eq(File.read(__dir__ + '/../fixtures/aws/bucket-policy.json'))
    end
  end
  describe 'policy effect' do
    it 'allows thumbnail without referer' do
      curl = Curl::Easy.http_get('https://s3.amazonaws.com/openvault.wgbh.org/catalog/asset_thumbnails/A_00000000_MOCK.jpg')
      curl.perform
      expect(curl.status).to eq('200 OK')
    end
    it 'disallows proxies without referer' do
      curl = Curl::Easy.http_get('https://s3.amazonaws.com/openvault.wgbh.org/catalog/asset_proxies/A_00000000_MOCK.mp3')
      curl.perform
      expect(curl.status).to eq('403 Forbidden')
    end
    describe 'allows proxies with appropriate referers' do
      [
        'http://openvault.wgbh.org',
        'http://demo.openvault.wgbh.org',
        'http://localhost:3000',
        'http://foo.wgbh-mla.org',
        'http://foo.wgbh-mla-test.org'
      ].each do |host|
        it "loads from #{host}" do
          curl = Curl::Easy.http_get('https://s3.amazonaws.com/openvault.wgbh.org/catalog/asset_proxies/A_00000000_MOCK.mp3')
          curl.headers['Referer'] = "#{host}/foo-bar"
          curl.perform
          expect(curl.status).to eq('200 OK')
        end
      end
    end
  end
end
