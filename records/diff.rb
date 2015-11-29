#!/bin/ruby

require 'set'
require_relative 'common'

=begin

Print hashes in dir_a that absent in dir_b.

=end

if ARGV.size < 2
  puts "Usage #{$0} <hashes_dir_a> <hashes_dir_b>"
  exit 1
end

def make_hash(a)
  h = {}
  a.each { |v| h[v[:digest]] = v[:path] }
  h
end

a = make_hash(scan_dir_hash(ARGV[0]))
b = make_hash(scan_dir_hash(ARGV[1]))

as = a.keys.to_set
bs = b.keys.to_set

diff = as - bs
diff.each do |hash|
  puts a[hash]
end
