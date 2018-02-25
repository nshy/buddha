#!/usr/bin/ruby

require 'listen'
require_relative 'helpers'
require_relative 'convert'
require_relative 'assets'
require_relative 'resources'
require_relative 'gesheru'
require_relative 'himalai'

include CommonHelpers

module Sync

def handle_resource(resource)
  files = resource.dirs.collect { |d| d.files }.flatten
  d = Cache.diff(database, resource.table, files)
  Cache.diffmsg(*d, 'b')
  table_update(resource, *d)
end

def find_changes(assets)
  assets.instance_eval do
    u = src.files.collect do |s|
      d = src_to_dst(self, s)
      (File.exist?(d) and File.mtime(s) > File.mtime(d)) ? s : nil
    end.compact
    a = src.files.collect do |s|
      d = src_to_dst(self, s)
      (not File.exist?(d)) ? s : nil
    end.compact
    d = dst.files.collect do |d|
      s = dst_to_src(self, d)
      (not File.exist?(s)) ? s : nil
    end.compact
    a.delete(assets.mixins) if assets.respond_to?(:mixins)
    Cache.diffmsg(u, a, d, 'a')
    [u, a, d]
  end
end

def mixin_changed?(assets)
  t = File.mtime(assets.mixins)
  assets.dst.files.each { |p| return true if File.mtime(p) < t }
  false
end

def handle_assets(assets)
  d = assets.dst.dir
  Dir.mkdir(d) if not File.exist?(d)
  c = find_changes(assets)
  mixin_changed = false
  if assets.respond_to?(:mixins) and mixin_changed?(assets)
    puts "a U #{assets.mixins}"
    mixin_changed = true
  end
  update_assets(assets, *c, mixin_changed)
end

end # module Sync

module Watch

def listen_to(dir, options)
  l = Listen.to(dir.dir, relative: true) do |*d|
    d = d.map { |s| s.select { |p| dir.match(p) } }
    Cache.diffmsg(*d, options[:prefix])
    yield *d
  end
  l.start
end

def handle_resource(resource)
  resource.dirs.each do |dir|
    listen_to(dir, prefix: "b") do |*d|
      clean_errors(*d)
      table_update(resource, *d)
    end
  end
end

def handle_assets(assets)
  listen_to(assets.src, prefix: "a") do |u, a, d|
    mixin_changed = false
    if assets.respond_to?(:mixins)
      mixin_changed = u.delete(assets.mixins) != nil
    end
    clean_errors(u, a, d)
    update_assets(assets, u, a, d, mixin_changed)
  end
end

end # module Watch

USAGE = <<USAGE
usage: sync.rb [ --watch ]

Options:
  --watch                  continue watch for changes after sync

USAGE

$stdout.sync = true
sync_lock

watch = false
while not ARGV.empty? and ARGV.first.start_with?('--')
  case ARGV.shift
    when '--watch' then watch = true
    else usage
  end
end

sync(Sync)
if watch
  sync(Watch)

  Thread.new do
    while true
      Gesheru.update
      Himalai.update
      sleep(3600)
    end
  end

  sleep
end
