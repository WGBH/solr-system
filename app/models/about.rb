class About < Cmless
  ROOT = File.expand_path('../views/about', File.dirname(__FILE__))
  attr_reader :head_html
  attr_reader :main_html
  attr_reader :links_html
end
