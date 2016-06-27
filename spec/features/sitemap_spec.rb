require 'rails_helper'

describe 'sitemap.xml' do
  it 'has at least one URL' do
    visit '/sitemap.xml'
    expect(page.status_code).to eq(200)
    expect(page).to have_text('http://openvault.wgbh.org/catalog/A_00000000_MOCK')
  end
  it 'has reference from robots.txt' do
    visit '/robots.txt'
    expect(page.status_code).to eq(200)
    expect(page).to have_text('http://openvault.wgbh.org/sitemap.xml')
  end
end
