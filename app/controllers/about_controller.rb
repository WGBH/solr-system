class AboutController < ApplicationController
  def show
    @about = About.find_by_path(params[:id])
    @page_title = @about.title
  end
end
