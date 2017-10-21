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

def clean_path(d, assets)
  a = clone
  a.extend(assets)
  s = a.src(d)
  if not File.exists?(s)
    puts "a D #{s}"
    File.delete(s)
  end
end

def sync_path(s, assets)
  a = clone
  a.extend(assets)
  d = a.dst(s)
  if not File.exists?(d)
    puts "a A #{s}"
    compile(a, s)
  elsif File.mtime(s) > File.mtime(d)
    puts "a U #{s}"
    compile(a, s)
  end
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

def assets_changed?
  buntime = File.mtime(Bundle)
  each_css { |p| return true if File.mtime(p) > buntime }
  false
end

def mixin_changed?
  mixtime = File.mtime(Mixins)
  each_css { |p| return true if File.mtime(p) < mixtime }
  false
end

def sync_main
  each_css { |p| clean_path(p, Assets::Public) }
  if mixin_changed?
    puts "a U #{Mixins}"
    compile_all
  else
    each_scss { |s| sync_path(s, Assets::Public) }
  end
  concat if File.mtime(StyleDst) > File.mtime(Bundle) or assets_changed?
end

Dir.mkdir(".build") if not File.exists?(".build")
Sites.each do |s|
  Site.for(s).instance_eval do
    Dir.mkdir(build_dir) if not File.exists?(build_dir)
    database[:errors].delete

    sync_main
    sync_news
    Sync::Klasses.each { |k| sync_klass(k) }
  end
end
