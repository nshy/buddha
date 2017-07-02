#!/bin/ruby

require 'listen'
require_relative 'convert'
require_relative 'helpers'

include CommonHelpers

$stdout.sync = true

def listen_to(dir, options = {})
  l = Listen.to(dir, relative: true) do |u, a, d|
    database[:errors].where(path: u + a + d).delete
    yield u, a, d
  end
  l.only(options[:only]) if options[:only]
  l.start
end

def watch_klass(k)
  klass = site_class(k)
  klass.dirs.each do |dir|
    listen_to(dir.dir) do |*d|
      d = d.map { |s| s.select { |p| dir.match(p) } }
      table_update(klass, *d)
    end
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
  listen_to(site_path("news"), only: /\.scss$/) do |u, a, d|
    sync_watch_paths(u, a, d, Assets::News)
  end
end

def watch_main
  listen_to(StyleSrc, only: /\.scss$/) do |u, a, d|
    if u.include?(Mixins)
    puts "a U #{Mixins}"
      compile_all
    else
      sync_watch_paths(u, a, d, Assets::Public)
    end
    concat
  end
end

Sites.each do |s|
  Site.for(s).instance_eval do
    watch_main
    watch_news
    Sync::Klasses.each { |k| watch_klass(k) }
  end
end

sleep
