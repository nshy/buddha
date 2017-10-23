#!/usr/bin/ruby

require_relative 'helpers'
require_relative 'convert'
require_relative 'assets'
require_relative 'resources'

include CommonHelpers

$stdout.sync = true
sync_lock

def sync_klass(k)
  klass = site_class(k)
  files = klass.dirs.collect { |d| d.files }.flatten
  d = Cache.diff(database, klass.table, files)
  Cache.diffmsg(*d, 'b')
  table_update(klass, *d)
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

def sync_assets(assets)
  a = mixin(assets)
  c = find_changes(a)
  mixin_changed = false
  if a.respond_to?(:mixins) and mixin_changed?(a)
    puts "a U #{a.mixins}"
    mixin_changed = true
  end
  update_assets(a, *c, mixin_changed)
end

sync_assets(Assets::Public)
Dir.mkdir(".build") if not File.exists?(".build")
Sites.each do |s|
  Site.for(s).instance_eval do
    Dir.mkdir(site_build_dir) if not File.exists?(site_build_dir)
    # We can not clean errors in update functions based on (u, a, d) triplet.
    # Because we can not detect deleted file in case of error as there
    # is no product object.
    database[:errors].delete

    sync_assets(Assets::News)
    Resources::Klasses.each { |k| sync_klass(k) }
  end
end
