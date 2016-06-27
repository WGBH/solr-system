require 'rails_helper'
require_relative '../support/validation_helper'

describe 'Overrides' do
  Dir['app/views/override/**/*']
    .reject { |file| File.directory?(file) }
    .reject { |file| file.match(/\.erb$/) }
    .each do |override|
      path = override.gsub(/app\/views(\/override)?/, '').sub('.md', '')

      it "#{path} method works" do
        visit path
        expect(page.status_code).to eq(200)
        expect_fuzzy_xml
      end
    end

  it 'Gives 404 for no such page' do
    visit '/nothing/here'
    expect(page.status_code).to eq(404)
  end
end
