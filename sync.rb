#!/bin/ruby

require_relative 'helpers'
require_relative 'convert'

include CommonHelpers

$stdout.sync = true

def convert(set)
  set.to_a.map { |v| v[:path] }
end


def sync_klass(k)
  klass = site_class(k)
  table = klass.table

  klass.dirs.map do |dir|
    dir.files.each do |path|
      database[:disk_state].insert(path: path,
                                   mtime: File.mtime(path))
    end
  end

  deleted = database[table].join_table(:left, :disk_state, path: :path).
              where(Sequel[:disk_state][:path] => nil).
                select(Sequel[table][:path])

  table_delete(klass, convert(deleted))

  klass.dirs.map do |dir|
    updated = database[:disk_state].join_table(:left, table, path: :path).
                where{ Sequel[table][:mtime] <
                       Sequel[:disk_state][:mtime] }.
                  select(Sequel[:disk_state][:path])

    added = database[:disk_state].join_table(:left, table, path: :path).
              where(Sequel[table][:path] => nil).
                select(Sequel[:disk_state][:path])

    table_add(klass, dir, convert(added))
    table_update(klass, dir, convert(updated))
  end

  database[:disk_state].delete
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

def sync_news
  dir = site_path("news")
  build = site_build_path("news")
  Dir.mkdir(build) if not File.exists?(build)
  list_files(build, 'css') { |p| clean_path(p, Assets::News) }
  Dir.entries(dir).each do |e|
    p = "#{dir}/#{e}"
    next if not File.directory?(p) or e == '.' or e == '..'
    f = "#{p}/style.scss"
    next if not File.exists?(f)
    sync_path(f, Assets::News)
  end
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

Dir.mkdir("build") if not File.exists?("build")
Sites.each do |s|
  Site.for(s).instance_eval do
    Dir.mkdir(build_dir) if not File.exists?(build_dir)
    database[:errors].delete
    database.create_table :disk_state, temp: true do
      String :path, primary_key: true
      DateTime :mtime , null: false
    end

    sync_main
    sync_news
    Sync::Klasses.each { |k| sync_klass(k) }
  end
end
