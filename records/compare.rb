#!/bin/ruby

require 'yaml'
require_relative 'common'
require_relative 'chroma'

=begin

Compare files by chromaprint for every pair in <math_file>. We try to find out
is one file is edited version of the other. We assume the edit is ether some
kind of filtering (reencoding, noise reduction) or cutting (at beginning or
the end). Chromaprint length is 120s from beginning of the file and maximum
chromaprint offset on compare is 100s. So we assume that cutting is not too
lengthy. The result of comparison is minimum value of chromaprint convolution
for different offsets. In case of one file is edited version of the other the
result will be close to zero.

=end

if ARGV.size < 1 or ARGV.size > 1
  puts "Usage #{$0} <match_file>"
  exit 1
end

match_file = ARGV[0]
match = nil
File.open(match_file, 'r') do |file|
  match = YAML.load(file.read)
end

def file_paths(hash_path)
  {
    meta: hash_path.gsub(/^hashes/, 'meta'),
    chroma: hash_path.gsub(/^hashes/, 'chromaprint')
  }
end

match.each do |ref, base_list|
  if base_list.size > 1
    puts "we expect only on-by-one matches, assumption is failed for #{ref}"
    exit
  end
  base = base_list.first
  c = chroma_compare(file_paths(ref), file_paths(base))
  puts "index: #{parse_index(ref)} min: #{c[:min]}"
end
