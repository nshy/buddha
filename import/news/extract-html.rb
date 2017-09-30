#!/usr/bin/ruby

require_relative 'routines'

if ARGV[0].nil?
  puts "usage: #{$0} <start-node>"
  exit 1
end

extract_html ARGV[0].to_i
