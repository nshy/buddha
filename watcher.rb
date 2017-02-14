#!/bin/ruby

require 'listen'
require_relative 'convert'
require_relative 'helpers'

include CommonHelpers

$stdout.sync = true

def convert_paths(paths, to_url)
  paths.map { |p| to_url.call(p) }
end

Listeners = []
def listen(table, path, only, to_url, loader)
  Listeners << Listen.to(path,
                         only: only,
                         relative: true) do |updated, added, deleted|
    update_table(table,
                 convert_paths(updated, to_url),
                 convert_paths(added, to_url),
                 convert_paths(deleted, to_url)) { |url| loader.call(url) }
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

listen(:teachings,
       'data/teachings',
       /.xml$/,
       method(:path_to_id),
       method(:load_teachings))

# --------------------- news --------------------------

def resource_path_url(path)
  path_to_id(Pathname.new(path).each_filename.to_a[2])
end

listen(:news,
       'data/news',
       /.(adoc|erb|html)$/,
       method(:resource_path_url),
       method(:load_news))

# --------------------- library --------------------------

listen(:books,
       'data/book/',
       /info.xml$/,
       method(:resource_path_url),
       method(:load_books))

listen(:book_categories,
       'data/book-category/',
       /.xml$/,
       method(:resource_path_url),
       method(:load_book_categories))

listen_root(:top_categories, 'data/library.xml') { load_library() }

start
