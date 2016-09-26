require 'nokogiri'
require 'open-uri'

def save_xml(path, xml)
  File.open(path, "w") do |file|
    file << xml.to_xml(:encoding => 'utf-8')
  end
end

def parse_html(path)
  f = File.open(path)
  yield Nokogiri::HTML(f, nil, 'utf-8')
  f.close
end
