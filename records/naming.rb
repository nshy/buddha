#!/bin/ruby

require_relative 'common'

if ARGV.size < 1
  puts "Usage ./naming.rb <hashes_dir>"
  exit 1
end

hashes_dir = ARGV[0]

files = scan_dir(hashes_dir)
paths = files.collect { |file| file[:path] }

paths.each do |path|
  puts path if parse_index(path).nil?
end
