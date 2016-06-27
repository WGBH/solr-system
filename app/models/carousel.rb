class Carousel < Cmless
  ROOT = (Rails.root + 'app/views/home').to_s
  attr_reader :head_html

  def parse
    Nokogiri::HTML(head_html).xpath('//a').map do |a|
      OpenStruct.new(
        text: a.children[0].attr('alt'),
        src: a.children[0].attr('src'),
        href: a.attr('href')
      )
    end
  end

  class << self
    def items
      if @items
        @items.shuffle
      else
        @items ||= Carousel.find_by_path('carousel').parse
      end
    end
  end
end
