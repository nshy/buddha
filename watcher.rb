#!/bin/ruby

require 'listen'
require_relative 'convert'
require_relative 'helpers'

include CommonHelpers

$stdout.sync = true

module Sync

def self.filter(paths, dir)
  paths.select { |p| dir.match(p) }
end

def self.watch_klass(db, klass)
  klass.dirs(db[:dir]).each do |dir|
    listener = Listen.to(dir.dir, relative: true) do |updated, added, deleted|
      update_table(db[:db], klass,
                   filter(updated, dir),
                   filter(added, dir),
                   filter(deleted, dir))
    end
    listener.start
  end
end

def self.watch_db(db)
  Klasses.each { |klass| watch_klass(db, klass) }
end

def self.sync_watch_paths(updated, added, deleted, dest)
  deleted.each do |p|
    puts "a D #{p}"
    css = dest.call(p)
    File.delete(css) if File.exists?(css)
  end
  added.each do |p|
    puts "a A #{p}"
    compile(p, dest.call(p))
  end
  updated.each do |p|
    puts "a U #{p}"
    compile(p, dest.call(p))
  end
end

def self.watch_news(d)
  listener = Listen.to("#{d}/news", relative: true) do |*a|
    sync_watch_paths(*a, method(:dest_news))
  end
  listener.only /\.scss$/
  listener.start
end

def self.watch_main
  listener = Listen.to('assets/css', relative: true) do |updated, added, deleted|
    if updated.include?('assets/css/_mixins.scss')
      sync_all
    else
      sync_watch_paths(updated, added, deleted, method(:dest_man))
    end
    concat
  end
  listener.only /\.scss$/
  listener.start
end

end

Sync.watch_main
[ DbPathsMain, DbPathsEdit ].each do |p|
  Sync.watch_news(p[:dir])
  Sync.watch_db(db_open(p))
end

sleep
