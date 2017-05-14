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

def self.watch(db)
  Klasses.each { |klass| watch_klass(db, klass) }
end

end

Sync.watch(db_open(DbPathsMain))
Sync.watch(db_open(DbPathsEdit))

sleep
