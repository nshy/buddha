#!/bin/ruby

require_relative 'common'

=begin

Takes <hashes_dir> as input that holds files which contents is md5 hashes (see
digest.rb) and finds recursively files with same contents (that is md5 hashes
of files from some different root).

=end

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
