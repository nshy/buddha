#!/bin/ruby

require_relative 'helpers'
require_relative 'convert'

include CommonHelpers

$stdout.sync = true

def convert(set)
  set.to_a.map { |v| v[:path] }
end


def sync_klass(klass)
  database.create_table :disk_state, temp: true do
    String :id, primary_key: true
    String :path, null: false, unique: true
    DateTime :last_modified , null: false
  end

  files = klass_dirs(klass).map { |d| d.files }.flatten
  files.each do |path|
    database[:disk_state].insert(id: klass.path_to_id(path),
                                 path: path,
                                 last_modified: File.mtime(path))
  end

  table = klass.table
  updated = database[:disk_state].join_table(:left, table, id: :id).
              where{ Sequel[table][:last_modified] <
                     Sequel[:disk_state][:last_modified] }.
                select(Sequel[:disk_state][:path])

  deleted = database[table].join_table(:left, :disk_state, id: :id).
              where(Sequel[:disk_state][:id] => nil).
                select(Sequel[table][:path])

  added = database[:disk_state].join_table(:left, table, id: :id).
            where(Sequel[table][:id] => nil).
              select(Sequel[:disk_state][:path])

  update_table(klass,
               convert(updated),
               convert(added),
               convert(deleted))

  database.drop_table :disk_state
end


def sync_path(s, d, compile = :compile)
  database[:errors].where(path: path_from_db(s)).delete
  m = method(compile)
  if File.exists?(s)
    if not File.exists?(d)
      puts "a A #{s}"
      m.call(s, d)
    elsif File.mtime(s) > File.mtime(d)
      puts "a U #{s}"
      m.call(s, d)
    end
  elsif File.exists?(d)
    puts "a D #{s}"
    File.delete(d)
  end
end

def sync_news
  dir = site_path("news")
  Dir.entries(dir).each do |e|
    p = "#{dir}/#{e}"
    next if not File.directory?(p) or e == '.' or e == '..'
    sync_path("#{p}/style.scss", "#{p}/style.css", :compile_news)
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
  each_css { |p| sync_path(src_main(p), p) }
  if mixin_changed?
    sync_all
  else
    each_scss { |s, d| sync_path(s, d) }
  end
  concat if File.mtime(StyleDst) > File.mtime(Bundle) or assets_changed?
end

[ DbPathsMain, DbPathsEdit ].each do |p|
  Site.new(p).execute do
    sync_main
    sync_news
    Sync::Klasses.each { |k| sync_klass(k) }
  end
end
