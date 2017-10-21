#!/usr/bin/ruby

require 'listen'
require_relative 'convert'
require_relative 'helpers'

include CommonHelpers

$stdout.sync = true

def listen_to(dir, options = {})
  l = Listen.to(dir, relative: true) do |u, a, d|
    yield u, a, d
  end
  l.only(options[:only]) if options[:only]
  l.start
end

def watch_klass(k)
  klass = site_class(k)
  klass.dirs.each do |dir|
    listen_to(dir.dir) do |u, a, d|
      database[:errors].where(path: u + a + d).delete
      d = [u, a, d].map { |s| s.select { |p| dir.match(p) } }
      table_update(klass, *d)
    end
  end
end

def watch_news
  listen_to(site_path("news"), only: /\.scss$/) do |u, a, d|
    database[:errors].where(path: u + a + d).delete
    Cache.diffmsg(u, a, d, 'a')
    update_assets(u + a, d, Assets::News)
  end
end

def watch_main
  listen_to(StyleSrc, only: /\.scss$/) do |u, a, d|
    Cache.diffmsg(u, a, d, 'a')
    if u.include?(Mixins)
      c = []
      each_scss { |s| c << s }
    else
      c = u + a
      c.delete(Mixins)
    end
    update_assets(c, d, Assets::Public)
    concat
  end
end

watch_main
Sites.each do |s|
  Site.for(s).instance_eval do
    watch_news
    Sync::Klasses.each { |k| watch_klass(k) }
  end
end

sleep
