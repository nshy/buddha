#!/bin/ruby

require 'listen'
require_relative 'convert'

$stdout.sync = true

def filter_paths(paths, dir)
  paths.select { |p| dir.match(p) }
end

def listen(klass)
  klass.dirs.each do |dir|
    listener = Listen.to(dir.dir, relative: true) do |updated, added, deleted|
      update_table(klass,
                   filter_paths(updated, dir),
                   filter_paths(added, dir),
                   filter_paths(deleted, dir))
    end
    listener.start
  end
end

listen(Cache::Teaching)
listen(Cache::News)
listen(Cache::Book)
listen(Cache::BookCategory)
listen(Cache::Digest)

sleep
