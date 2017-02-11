#!/bin/ruby

# tests average load speed of major site pages
# usage:
#   speed.rb <address[:port]>

address = ARGV[0]
if address.nil?
  puts "usage: speed.rb <address[:port]>"
  exit
end

urls = [
  '/',
  '/book-category/geshe-la/',
  '/book/baykal-2009/',
  '/timetable?show=week',
  '/library/',
  '/news/2016-09-04/',
  '/news?top=true',
  '/timetable?show=schedule',
  '/teachings/2016-autumn/',
  '/archive/',
  '/teachers/'
]

res = []
urls.each do |url|
  out = `ab -c 1 -n 30 http://#{address}/#{url}`
  time = /^Total:.*/.match(out)[0].split[2]
  printf("%4s %s\n", time, url)
end
