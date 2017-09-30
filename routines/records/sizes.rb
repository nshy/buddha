#!/usr/bin/ruby

require_relative '../../routines.rb'
include CommonHelpers

def get_url_size(url)
  size = 0
  e = URI.escape(url)
  Net::HTTP.start(URI(e).hostname) do |http|
    size = http.request_head(e)['content-length'].to_i >> 20
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
  return false if (not size_element.nil?) and size_element.text.to_i != 0

  url_element.add_next_sibling "\n      <#{size_tag}>#{get_url_size(url)}</#{size_tag}>"
  return true
end

each_file('../../data/teachings') do |path|
  parse_xml(path) do |xml|
    save = false
    xml.xpath('//record').each do |record|
      save = true if update_url_size(record, 'audio')
      save = true if update_url_size(record, 'video')
    end
    save_xml(path, xml) if save
  end
end
