class RobotsController < ApplicationController
  REAL_HOST = 'openvault.wgbh.org'
  def show
    respond_to do |format|
      format.txt do
        render text:
          if request.host == REAL_HOST
            <<EOF
User-agent: *
Disallow: /catalog?
Disallow: /plain/
EOF
          else
            <<EOF
User-agent: *
Disallow: /
# Only #{REAL_HOST} should be indexed.
EOF
          end +
            'Sitemap: http://openvault.wgbh.org/sitemap.xml'
      end
    end
  end
end
