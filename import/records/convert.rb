#!/bin/ruby

require 'fileutils'
require_relative 'routines'
require_relative 'tmp/pages'

def parse_url(record, classname)
  field = record.at_css("td.#{classname}")
  ref = field.at_xpath('a')
  return nil if ref.nil?
  ref.attribute('href')
end

def save_field(xml, description, record, name)
  return if not description.has_key?(name)
  element = Nokogiri::XML::Node.new name.to_s, xml
  element.parent = record
  element.content = description[name]
end

def save_node(path, records, node)
  xml = Nokogiri::XML::Document.new

  theme = Nokogiri::XML::Node.new 'theme', xml
  theme.parent = xml

  geshe = Nokogiri::XML::Node.new 'geshe-node', xml
  geshe.parent = theme
  geshe.content = node.to_s

  records.each do |record|
    element = Nokogiri::XML::Node.new 'record', xml
    element.parent = theme

    if not record.has_key?(:record_date)
      throw "Date must be set for record, path: #{path}"
    end

    save_field(xml, record, element, :description)
    save_field(xml, record, element, :record_date)
    save_field(xml, record, element, :audio_url)
    save_field(xml, record, element, :video_url)
  end

  save_xml(path, xml)
end

FileUtils.rm_rf('tmp/xml')
Dir.mkdir('tmp/xml')

PAGES.each do |node, filename|
  parse_html("tmp/html/#{filename}.html") do |html|
    records = []
    html.xpath('//table/tbody/tr').each do |record|
      audio_url =  parse_url(record, 'views-field-field-lect-mp3-hi-fid')
      if audio_url.nil?
        audio_url =  parse_url(record, 'views-field-field-lect-mp3-me-fid')
      end
      if audio_url.nil?
        audio_url =  parse_url(record, 'views-field-field-lect-mp3-lo-fid')
      end

      records << {
      description: record.at_css('td.views-field-title').text.strip,
      record_date: record.at_css('td.views-field-field-lect-date-value').text.strip,
      audio_url: audio_url,
      video_url: parse_url(record, 'views-field-field-lect-avi-lo-fid'),
      }
    end
    save_node("tmp/xml/#{filename}.xml", records, node)
  end
end
