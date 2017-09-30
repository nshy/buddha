#!/usr/bin/ruby

require_relative '../../routines.rb'

SiteData = '../../data'
include TeachingsHelper

def check_link(url, types)
  return if url.nil?
  e = URI.escape(url)
  Net::HTTP.start(URI(e).hostname) do |http|
    response = http.request_head(e)
    if response.code != '200' or
       not types.include?(response['content-type'])
      puts url
    end
  end
end

teachings = load_teachings
teachings.each do |id, season|
  season.theme.each do |theme|
    theme.record.each do |record|
      check_link(record.audio_url, ['audio/mpeg'])
      check_link(record.video_url, ['video/x-msvideo', 'video/mp4'])
    end
  end
end
