#!/bin/ruby

require_relative 'helpers'

include CommonHelpers

def full_path(dir, name)
  "#{dir}/#{name}"
end

def list_dir(dir)
  files = Dir.entries(dir).select do |e|
    not e =~ /^\./ \
      and File.file?(full_path(dir, e)) \
      and e =~ /\.(jpg|gif|pdf|doc|swf)$/
  end
  dirs = Dir.entries(dir).select do |e|
    not e =~ /^\./ and File.directory?(full_path(dir, e))
  end
  files = files.map { |e| full_path(dir, e) }
  dirs = dirs.map { |e| list_dir(full_path(dir, e)) }.flatten
  files + dirs
end

def path_steps(path)
  s = path_split(path)
  (1..s.size).to_a.map { |l| s.slice(0, l).join('/') }
end

def path_conversion(path)
  n = path.sub(/^main/, 'edit')
end

files = list_dir('main')
dirs = files.map { |p| File.dirname(p) }.uniq
# make sure we have all parent dirs too
dirs = dirs.map { |p| path_steps(p) }.flatten.uniq.sort

dirs.each do |d|
  n = path_conversion(d)
  Dir.mkdir(n) if not File.exists?(n)
end

files.each { |p| File.link(p, path_conversion(p)) }
