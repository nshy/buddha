#!/bin/ruby

require 'listen'
require_relative 'convert'
require_relative 'helpers'

include CommonHelpers

$stdout.sync = true

def convert_paths(paths, klass)
  paths.map { |p| klass.path_to_id(p) }
end

Listeners = []
def listen(klass, path, only)
  Listeners << Listen.to(path,
                         only: only,
                         relative: true) do |updated, added, deleted|
    update_table(klass,
                 convert_paths(updated, klass),
                 convert_paths(added, klass),
                 convert_paths(deleted, klass))
  end
end

def listen_root(table, path, &block)
  Listeners << Listen.to('data',
                         relative: true) do |updated, added, deleted|
    # hack, Regexp.escape doesn't help in :only ...
    if updated.include?(path) ||
        added.include?(path) ||
        deleted.include?(path)
      sync_root_table(table, path) { block.call }
    end
  end
end

def start
  Listeners.each { |l| l.start }
  sleep
end

# --------------------- teachings --------------------------

listen(Cache::Teaching,
       'data/teachings',
       /.xml$/)

# --------------------- news --------------------------

listen(Cache::News,
       'data/news',
       /.(adoc|erb|html)$/)

# --------------------- library --------------------------

listen(Cache::Book,
       'data/books/',
       /info.xml$/)

listen(Cache::BookCategory,
       'data/book-categories/',
       /.xml$/)

listen_root(:top_categories, 'data/library.xml') { Cache.load_library() }

# --------------------- digests --------------------------

listen(Cache::Digest,
       'data/',
       /.(jpg|gif|swf|css|doc|pdf)$/)

listen(Cache::Digest,
       'public/',
       /.(png|svg|css|js|jpg)$/)

start
