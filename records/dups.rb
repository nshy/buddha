#!/bin/ruby

require_relative 'common'

if ARGV.size < 1
  puts "Usage ./dups.rb <hashes_dir>"
  exit 1
end

hashes_dir = ARGV[0]

grouped_paths = group_paths(scan_dir(hashes_dir))
dups = grouped_paths.select { |paths| paths.size > 1 }

dups.each do |paths|
  puts paths.pop
  paths.each do |path|
    puts "  #{path}"
  end
end
