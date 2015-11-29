#!/bin/ruby

require_relative 'common'

=begin

Compares hashes and dates correspodence from files in <dir_a> and <dir_b>.
If hashes are the same then indexes (see 'parse_index') should be
the same too. This routine prints all hashes correnspondencies that
have not index correspondenses.

=end

if ARGV.size < 2
  puts "Usage #{$0} <hashes_dir_a> <hashes_dir_b>"
  exit 1
end

hashes_dir_a = ARGV[0]
hashes_dir_b = ARGV[1]

files = scan_dir_hash(hashes_dir_a) + scan_dir_hash(hashes_dir_b)
grouped_paths = group_paths(files)
dups = grouped_paths.select { |paths| paths.size > 1 }

dups.each do |paths|
  indexes = paths.collect { |path| parse_index(path) }
  next if indexes.uniq.size == 1
  first = paths.pop
  puts "#{first} [#{parse_index(first)}]"
  paths.each do |path|
    puts "  #{path} [#{parse_index(path)}]"
  end
end
