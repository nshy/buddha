#!/usr/bin/ruby

require_relative 'convert'
require_relative 'models'

include NewsHelpers
include CommonHelpers

def check_news(path, doc)
  news_urls(Nokogiri::HTML(doc)) do |e|
    next if not e
    uri = URI(e)
    next if uri.absolute or uri.path.empty?
    p = e.content
    id = path_split(path)[2]
    p = p[0] == '/' ? p : "/news/#{id}/#{p}"

    next if p == '/timetable?show=week'
    next if p == '/timetable?show=schedule'
    next if File.exist?("main/#{p}")
    if p.start_with?('/teachings/')
      tid = path_split(p)[1]
      next if File.exist?("main/teachings/#{tid}.xml")
    end
    puts "#{path}: #{e.content}"
  end
end

Site.new(:main).execute do
  Sync::NewsDir.new(site_dir).files.each do |p|
    n = NewsDocument.new(p)
    check_news(p, n.body)
    check_news(p, n.cut)
  end
end
