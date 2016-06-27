require 'nokogiri'

class Captioner
  CAP_XSLT = Nokogiri::XSLT(File.read(__dir__ + '/xslt/tei_to_vtt.xsl'))
  Segment = Struct.new(:begin, :end, :speaker, :text)
  class << self
    def from_tei(tei_xml)
      tei_doc = Nokogiri::XML(tei_xml)
      caption_doc = CAP_XSLT.transform(tei_doc)
      "WEBVTT FILE\n\n" + caption_doc.css('segment').map do |s|
        Segment.new(
          parse(s.css('begin').text.strip),
          parse(s.css('end').text.strip),
          s.css('speaker').text.strip.gsub(/:$/, ''),
          s.css('text').text.strip.gsub(/\s+/, ' ')
        )
      end.map do |h|
        split(h)
      end.flatten.map do |h|
        "#{format(h.begin)} --> #{format(h.end)}\n#{h.speaker}: #{h.text}\n"
      end.join
    end

    private

    def parse(t)
      h, m, s = t.split(':')
      h.to_f * 60 * 60 + m.to_f * 60 + s.to_f
    end

    def format(t)
      Time.at(t).utc.strftime('%H:%M:%S.%L')
    end

    def split(seg)
      chunks = seg.text.split(/(?<=\.\s)(?<!Mr\.\s)(?<!Dr\.\s)(?<!Mrs\.\s)(?<!Ms\.\s)/)
      duration = seg.end - seg.begin
      seg_length = seg.text.length
      to_return = []
      t = seg.begin
      chunks.each do |chunk|
        chunk_duration = duration * chunk.length / seg_length
        to_return << Segment.new(t, t + chunk_duration, seg.speaker, chunk)
        t += chunk_duration
      end
      to_return
    end
  end
end
