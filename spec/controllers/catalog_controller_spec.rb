require 'rails_helper'

describe CatalogController do
  describe 'GET :show' do
    context 'with an invalid record id' do
      before { get :show, id: 'invalid-record-id' }

      it 'renders the a 404 page, with a 404 status, using the main application layout' do
        expect(response).to have_http_status :not_found
        expect(response).to render_template file: '404.html.erb', layout: ApplicationController._layout
      end
    end
  end
end
