#!/usr/bin/ruby

require_relative 'common'
require 'yaml'

=begin

Matches files by indexes. Index is is a 'yyyy-mm-dd-num' extracted from file
name. Filenames to be matched are taken from <diff_file>.  Match is done
against files in directory <dir>. There can be multiple matches for a file.
Result is presented in YAML format.

=end

if ARGV.size < 2
  puts "Usage #{$0} <diff_file> <dir>"
  exit 1
end

def scan_dir_index(root_dir)
  scan_dir(root_dir) do |path|
    { index: parse_index(path), path: path }
  end
end

def group_by_index(files)
  grouped_files = files.group_by { |file| file[:index] }
  grouped_paths = {}
  grouped_files.each do |index, files|
    grouped_paths[index] = files.collect { |file| file[:path] }
  end
  grouped_paths
end

diff_file = ARGV[0]
dir = ARGV[1]

unmatched = nil
File.open(diff_file, 'r') do |file|
  unmatched = file.read.split("\n")
end

base = group_by_index(scan_dir_index(dir))

match = {}
unmatched.each do |path|
  match[path] = base[parse_index(path)]
end

puts match.to_yaml
