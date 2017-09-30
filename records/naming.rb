#!/usr/bin/ruby

require_relative 'common'

=begin

Helper routine to test 'parse_index' function on some dir. Mentioned function
try to extract date and teaching number from filename of all files in directory
recursively and outputs all paths that it is fail to operate.

=end

if ARGV.size < 1
  puts "Usage ./naming.rb <hashes_dir>"
  exit 1
end

hashes_dir = ARGV[0]

files = scan_dir_hash(hashes_dir)
paths = files.collect { |file| file[:path] }

paths.each do |path|
  puts path if parse_index(path).nil?
end
