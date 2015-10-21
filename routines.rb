require 'nokogiri'
require_relative 'models'
require 'uri'

def theme_file(name)
  "data/themes/#{name}.xml"
end

def parse_xml(path)
  f = File.open(path)
  yield Nokogiri::XML(f, nil, 'utf-8')
  f.close
end

def save_xml(path, xml)
  File.open(path, "w") do |file|
    file << xml.to_xml(:encoding => 'utf-8')
  end
end

def each_file(dir)
  Dir.entries(dir).each do |p|
    next if p == '.' or p == '..'
    next if (/.un~$/ =~ p) != nil
    yield dir + '/' +  p
  end
end

def delete_elements(xml, xpath)
  xml.xpath(xpath).each do |e|
    raise 'format error' if not e.previous.text? or not e.previous.text.strip.empty?
    e.previous.remove
    e.remove
  end
end

def rename_elements(xml, xpath, name)
  xml.xpath(xpath).each do |e|
    e.name = name
  end
end

def check_themes_for_download_urls
  each_file('data/themes') do |path|
    theme = nil
    File.open(path) do |file|
      theme = ThemeDocument.new(Nokogiri::XML(file)).theme
    end
    bad = theme.record.detect { |r| r.audio_url.nil? and r.video_url.nil? }
    puts path if not bad.nil?
  end
end

def check_themes_for_undefined_sizes
  each_file('data/themes') do |path|
    theme = nil
    File.open(path) do |file|
      theme = ThemeDocument.new(Nokogiri::XML(file)).theme
    end
    bad = theme.record.detect do |r|
      (not r.audio_url.nil? and r.audio_size.nil?) or
      (not r.video_url.nil? and r.video_size.nil?)
    end
    puts path if not bad.nil?
  end
end
