#!/bin/ruby

require 'nokogiri'
require_relative '../../helpers.rb'
require_relative '../../models.rb'

include CommonHelpers
include TeachingsHelper

SiteData = '../../data'

def download_link(url)
  return if url.nil? or url.empty?
  file = url.gsub(/^.*\//, '')
  return File.exists?("download/#{file}")
  `wget -cP tmp #{url}`
  File.rename("tmp/#{file}", "download/#{file}") if $?.success?
end

teachings = load_teachings
teachings.each do |id, season|
  season.theme.each do |theme|
    theme.record.each do |record|
      download_link(record.video_url)
    end
  end
end
