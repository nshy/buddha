require 'nokogiri'
require 'sequel'
require_relative 'models'
require_relative 'helpers'
require_relative 'resource'
require 'uri'
require 'net/http'

include CommonHelpers

DB = Sequel.connect('sqlite://site.db')

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

def reinsert_elements(xml, parent, child)
  e = xml.create_element child.name
  parent.add_child(e)

  if child.children.size > 1
    child.children.each do |c|
      next if c.text?
      reinsert_elements(xml, e, c)
    end
  elsif child.children.size == 1 and child.children.first.text?
    e.content = child.children.first.text
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

def mark_all_delivered_type(type)
  options = Class.new.extend(type).options
  each_file("data/#{options[:dir]}") do |path|
    DB[:delivery].insert(rid: path_to_id(path), type: options[:type])
  end
end

def mark_all_delivered
  DB.transaction do
    mark_all_delivered_type(News)
    mark_all_delivered_type(Books)
    mark_all_delivered_type(TimeUpdates)
  end
end

def get_url_size(url)
  size = 0
  url2 = URI.escape(url)
  Net::HTTP.start(URI(url2).hostname) do |http|
    size = http.request_head(url2)['content-length'].to_i >> 20
  end
  size
end

def update_url_size(record, prefix)
  url_element = record.at_xpath("#{prefix}_url")
  return false if url_element.nil?
  url = url_element.text.to_s
  return false if url.empty?

  size_tag = "#{prefix}_size"
  size_element = record.at_xpath(size_tag)
  return false if not size_element.nil?

  url_element.add_next_sibling "\n      <#{size_tag}>#{get_url_size(url)}</#{size_tag}>"
  return true
end

def update_records_sizes
  each_file('data/teachings') do |path|
    parse_xml(path) do |xml|
      save = false
      xml.xpath('//record').each do |record|
        save = true if update_url_size(record, 'audio')
        save = true if update_url_size(record, 'video')
      end
      save_xml(path, xml) if save
    end
  end
end
