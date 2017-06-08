#!/bin/ruby

require 'listen'
require_relative 'convert'
require_relative 'helpers'

include CommonHelpers

$stdout.sync = true

def filter(paths, dir)
  paths.select { |p| dir.match(p) }
end

def watch_klass(klass)
  klass_dirs(klass).each do |dir|
    listener = Listen.to(dir.dir, relative: true) do |updated, added, deleted|
      update_table(klass,
                   filter(updated, dir),
                   filter(added, dir),
                   filter(deleted, dir))
    end
    listener.start
  end
end

def sync_watch_paths(updated, added, deleted, dest, compile = :compile)
  (deleted + added + updated).each do |p|
    database[:errors].where(path: path_from_db(p)).delete
  end
  m = method(compile)
  deleted.each do |p|
    puts "a D #{p}"
    css = dest.call(p)
    File.delete(css) if File.exists?(css)
  end
  added.each do |p|
    puts "a A #{p}"
    m.call(p, dest.call(p))
  end
  updated.each do |p|
    puts "a U #{p}"
    m.call(p, dest.call(p))
  end
end

def watch_news
  listener = Listen.to(site_path("news"), relative: true) do |*a|
    sync_watch_paths(*a, method(:dest_news), :compile_news)
  end
  listener.only /\.scss$/
  listener.start
end

def watch_main
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

Sites.each do |s|
  Site.new(s).execute do
    watch_main
    watch_news
    Sync::Klasses.each { |k| watch_klass(k) }
  end
end

sleep
