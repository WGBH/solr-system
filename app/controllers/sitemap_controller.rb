class SitemapController < ApplicationController
  caches_page :index
  def index
    @ids = RSolr.connect(url: 'http://localhost:8983/solr/')
           .get('select', params: {
                  'q' => '*:*',
                  'fl' => 'id',
                  'rows' => '50000' # Max for sitemaps
                })['response']['docs'].map { |d| d['id'] }
    respond_to do |format|
      format.xml do
        render
      end
    end
  end
end
