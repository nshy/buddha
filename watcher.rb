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

def self.sync_watch_paths(updated, added, deleted, dest,
                          compile = :compile, db = nil)
  if db
    (deleted + added + updated).each do |p|
      db[:errors].where(path: path_from_db(p)).delete
    end
  end
  m = method(compile)
  deleted.each do |p|
    puts "a D #{p}"
    css = dest.call(p)
    File.delete(css) if File.exists?(css)
  end
  added.each do |p|
    puts "a A #{p}"
    m.call(p, dest.call(p), db)
  end
  updated.each do |p|
    puts "a U #{p}"
    m.call(p, dest.call(p), db)
  end
end

def self.watch_news(db)
  listener = Listen.to("#{db[:dir]}/news", relative: true) do |*a|
    sync_watch_paths(*a, method(:dest_news), :compile_news, db[:db])
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
  db = db_open(p)
  Sync.watch_news(db)
  Sync.watch_db(db)
end

sleep
