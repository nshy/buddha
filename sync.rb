#!/usr/bin/ruby

require_relative 'helpers'
require_relative 'convert'

include CommonHelpers

$stdout.sync = true

def sync_klass(k)
  klass = site_class(k)
  files = klass.dirs.collect { |d| d.files }.flatten
  d = Cache.diff(database, klass.table, files)
  table_update(klass, *d)
end

def find_changes(assets)
  mixin(assets).instance_eval do
    u = src_files.collect do |s|
      d = dst(s)
      (File.exist?(d) and File.mtime(s) > File.mtime(d)) ? s : nil
    end.compact
    a = src_files.collect do |s|
      d = dst(s)
      (not File.exist?(d)) ? s : nil
    end.compact
    d = dst_files.collect do |d|
      s = src(d)
      (not File.exist?(s)) ? s : nil
    end.compact
    Cache.diffmsg(u, a, d, 'a')
    [u, a, d]
  end
end

def sync_news
  u, a, d = find_changes(Assets::News)
  update_assets(u + a, d, Assets::News)
end

def mixin_changed?
  mixtime = File.mtime(Assets::Public::Mixins)
  mixin(Assets::Public).dst_files.each { |p| return true if File.mtime(p) < mixtime }
  false
end

def sync_main
  u, a, d = find_changes(Assets::Public)
  mixin_changed = mixin_changed?
  puts "a U #{Assets::Public::Mixins}" if mixin_changed?
  update_assets_main(u, a, d, mixin_changed)
end

sync_main
Dir.mkdir(".build") if not File.exists?(".build")
Sites.each do |s|
  Site.for(s).instance_eval do
    Dir.mkdir(build_dir) if not File.exists?(build_dir)
    database[:errors].delete

    sync_news
    Sync::Klasses.each { |k| sync_klass(k) }
  end
end
