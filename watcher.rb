#!/bin/ruby

require 'listen'
require_relative 'convert'

$stdout.sync = true

def convert_paths(paths, fileset)
  paths = paths.select { |p| fileset.match(p) }
end

def listen(klass)
  klass.filesets.each do |fileset|
    listener = Listen.to(fileset.dir,
                         relative: true) do |updated, added, deleted|
      update_table(klass,
                   convert_paths(updated, fileset),
                   convert_paths(added, fileset),
                   convert_paths(deleted, fileset))
    end
    listener.only(fileset.only) if not fileset.only.nil?
    listener.start
  end
end

listen(Cache::Teaching)
listen(Cache::News)
listen(Cache::Book)
listen(Cache::BookCategory)
listen(Cache::Digest)

sleep
