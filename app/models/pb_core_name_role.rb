class PBCoreNameRole
  def initialize(rexml_or_stem, name = nil, role = nil, _affiliation = nil)
    if name
      # for testing only
      @stem = rexml_or_stem
      @name = name
      @role = role
    else
      @rexml = rexml_or_stem
      @stem = @rexml.name.gsub('pbcore', '').downcase
    end
  end

  def ==(other)
    self.class == other.class &&
      stem == other.stem &&
      name == other.name &&
      role == other.role
  end

  attr_reader :stem

  def name
    @name ||= REXML::XPath.match(@rexml, @stem).first.text
  end

  def role
    @role ||= begin
      node = REXML::XPath.match(@rexml, "#{@stem}Role").first
      node ? node.text : nil
    end
  end

  def to_a
    [name, role].select { |x| x }
  end

  def to_s
    "#{name} (#{role})"
  end
end
