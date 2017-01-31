#!/bin/ruby

require 'digest'

file = File.open("../digests.txt", 'w')

def add_file_info(file, base, path)
  return if /\.un~$/ =~ path
  path.gsub!(/^./, '')
  full = "#{base}/#{path}"
  sha1 = nil
  File.open(full) do |file|
    sha1 = Digest::SHA1.hexdigest(file.read)
  end
  file.puts "#{sha1} #{path}"
end

`cd ../public; find . -type f`.split.each do |path|
  next if path.start_with?('./3d-party')
  add_file_info(file, '../public', path)
end

`cd ../data; find . -type f`.split.each do |path|
  next if not /\.(jpg|gif|swf|css|doc|pdf|)$/ =~ path
  add_file_info(file, '../data', path)
end

file.close
