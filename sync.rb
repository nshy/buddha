#!/usr/bin/ruby

require_relative 'helpers'
require_relative 'convert'
require_relative 'assets'
require_relative 'resources'

include CommonHelpers

$stdout.sync = true
sync_lock

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
  c = find_changes(assets)
  mixin_changed = false
  if assets.respond_to?(:mixins) and mixin_changed?(assets)
    puts "a U #{assets.mixins}"
    mixin_changed = true
  end
  update_assets(assets, *c, mixin_changed)
end

end # module Sync

sync(Sync, true)
