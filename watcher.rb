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
    listen_to(dir.dir) do |*d|
      d = d.map { |s| s.select { |p| dir.match(p) } }
      clean_errors(*d)
      table_update(klass, *d)
    end
  end
end

def watch_assets(assets)
  s = mixin(assets)
  listen_to(s.src.dir, only: /\.scss$/) do |u, a, d|
    Cache.diffmsg(u, a, d, 'a')
    mixin_changed = false
    if s.respond_to?(:mixins)
      mixin_changed = u.delete(s.mixins) != nil
    else
      clean_errors(u, a, d)
    end
    update_assets(s, u, a, d, mixin_changed)
  end
end

watch_assets(Assets::Public)
Sites.each do |s|
  Site.for(s).instance_eval do
    watch_assets(Assets::News)
    Sync::Klasses.each { |k| watch_klass(k) }
  end
end

sleep
