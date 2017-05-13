#!/bin/ruby

require 'listen'
require_relative 'convert'

$stdout.sync = true

class Database
  def filter_paths(paths, dir)
    paths.select { |p| dir.match(p) }
  end

  def watch_klass(klass)
    klass.dirs(@dir).each do |dir|
      listener = Listen.to(dir.dir, relative: true) do |updated, added, deleted|
        update_table(klass,
                     filter_paths(updated, dir),
                     filter_paths(added, dir),
                     filter_paths(deleted, dir))
      end
      listener.start
    end
  end

  def watch
    watch_klass(Cache::Teaching)
    watch_klass(Cache::News)
    watch_klass(Cache::Book)
    watch_klass(Cache::BookCategory)
    watch_klass(Cache::Digest)
  end
end

databases_run(:watch)

sleep
