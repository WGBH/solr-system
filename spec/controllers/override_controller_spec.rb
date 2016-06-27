require 'rails_helper'

describe OverrideController do
  describe 'GET :show' do
    context 'with an unknown path' do
      before { get :show, path: 'unknown/path' }

      it 'renders the a 404 page, with a 404 status, using the main application layout' do
        expect(response).to have_http_status :not_found
        expect(response).to render_template file: '404.html.erb', layout: ApplicationController._layout
      end
    end
  end
end
