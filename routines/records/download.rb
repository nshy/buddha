#!/usr/bin/ruby

require 'nokogiri'
require_relative '../../helpers.rb'
require_relative '../../models.rb'

include CommonHelpers
include TeachingsHelper

SiteData = '../../data'

def download_link(url)
  return if url.nil?
  url = url.strip
  return if url.empty?
  file = "download/#{File.basename(url)}"
  tmp = "tmp/#{File.basename(url)}"
  return if File.exist?(file)

  `wget -cP tmp #{url}`
  File.rename(tmp, file) if $?.success?
end

teachings = load_teachings
teachings.each do |id, season|
  season.theme.each do |theme|
    theme.record.each do |record|
      next if not record.youtube_id.nil?
      download_link(record.video_url)
    end
  end
end
