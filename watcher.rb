#!/bin/ruby

require 'listen'
require_relative 'convert'
require_relative 'helpers'

include CommonHelpers

$stdout.sync = true

def filter(paths, dir)
  paths.select { |p| dir.match(p) }
end

def watch_klass(k)
  klass = site_class(k)
  klass.dirs.each do |dir|
    listener = Listen.to(dir.dir, relative: true) do |updated, added, deleted|
      database[:errors].where(path: (updated + added + deleted)).delete
      table_add(klass, dir, filter(added, dir))
      table_update(klass, dir, filter(updated, dir))
      table_delete(klass, filter(deleted, dir))
    end
    listener.start
  end
end

def sync_watch_paths(updated, added, deleted, assets)
  a = clone
  a.extend(assets)
  deleted.each do |p|
    puts "a D #{p}"
    css = a.dst(p)
    File.delete(css) if File.exists?(css)
  end
  added.each do |p|
    puts "a A #{p}"
    compile(a, p)
  end
  updated.each do |p|
    puts "a U #{p}"
    compile(a, p)
  end
end

def watch_news
  listener = Listen.to(site_path("news"), relative: true) do |*a|
    sync_watch_paths(*a, Assets::News)
  end
  listener.only /\.scss$/
  listener.start
end

def watch_main
  listener = Listen.to(StyleSrc, relative: true) do |updated, added, deleted|
    if updated.include?(Mixins)
    puts "a U #{Mixins}"
      compile_all
    else
      sync_watch_paths(updated, added, deleted, Assets::Public)
    end
    concat
  end
  listener.only /\.scss$/
  listener.start
end

Sites.each do |s|
  Site.for(s).instance_eval do
    watch_main
    watch_news
    Sync::Klasses.each { |k| watch_klass(k) }
  end
end

sleep
