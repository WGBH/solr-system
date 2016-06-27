module XmlBacked
  def initialize(xml)
    @xml = xml
    @doc = REXML::Document.new xml
  end

  def xpath(xpath)
    REXML::XPath.match(@doc, xpath).tap do |matches|
      if matches.length != 1
        fail NoMatchError, "Expected 1 match for '#{xpath}'; got #{matches.length}"
      else
        return XmlBacked.text_from(matches.first)
      end
    end
  end

  def xpath_optional(xpath)
    REXML::XPath.match(@doc, xpath).tap do |matches|
      if matches.length > 1
        fail NoMatchError, "Expected at most 1 match for '#{xpath}'; got #{matches.length}"
      elsif matches.first
        return XmlBacked.text_from(matches.first)
      else
        return nil
      end
    end
  end

  def xpaths(xpath)
    REXML::XPath.match(@doc, xpath).map { |node| XmlBacked.text_from(node) }
  end

  def xpath_boolean(xpath)
    case xpaths(xpath)
    when ['YES']
      true
    when []
      false
    else throw "Expected #{xpath} if present to be 'YES'"
    end
  end

  def self.text_from(node)
    ((node.respond_to?('text') ? node.text : node.value) || '').strip.tap do |s|
      fail("Empty element in XML: #{node}") if s == ''
    end
  end

  def pairs_by_type(element_xpath, attribute_xpath)
    REXML::XPath.match(@doc, element_xpath).map do |node|
      key = REXML::XPath.first(node, attribute_xpath)
      [
        key ? key.value : nil,
        node.text
      ]
    end
  end

  def hash_by_type(element_xpath, attribute_xpath)
    Hash[pairs_by_type(element_xpath, attribute_xpath)]
  end

  # TODO: If we can just iterate over pairs, we don't need either of these.
  #
  #  def multi_hash_by_type(element_xpath, attribute_xpath) # Not tested
  #    Hash[
  #      pairs_by_type(element_xpath, attribute_xpath).group_by{|(key,value)| key}.map{|key,pair_list|
  #        [key, pair_list.map{|(key,value)| value}]
  #      }
  #    ]
  #  end

  class NoMatchError < StandardError
  end
end
