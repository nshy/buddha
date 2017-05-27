#!/bin/ruby

require_relative 'helpers'
require_relative 'convert'

include CommonHelpers

$stdout.sync = true

module Sync

def self.convert(set)
  set.to_a.map { |v| v[:path] }
end

def self.sync_table(sitedb, klass)
  db = sitedb[:db]
  db.create_table :disk_state, temp: true do
    String :id, primary_key: true
    String :path, null: false, unique: true
    DateTime :last_modified , null: false
  end

  files = klass.dirs(sitedb[:dir]).map { |d| d.files }.flatten
  files.each do |path|
    db[:disk_state].insert(id: klass.path_to_id(path),
                           path: path,
                           last_modified: File.mtime(path))
  end

  table = klass.table
  updated = db[:disk_state].join_table(:left, table, id: :id).
              where{ Sequel[table][:last_modified] <
                     Sequel[:disk_state][:last_modified] }.
                select(Sequel[:disk_state][:path])

  deleted = db[table].join_table(:left, :disk_state, id: :id).
              where(Sequel[:disk_state][:id] => nil).
                select(Sequel[table][:path])

  added = db[:disk_state].join_table(:left, table, id: :id).
            where(Sequel[table][:id] => nil).
              select(Sequel[:disk_state][:path])

  update_table(db, klass,
               convert(updated),
               convert(added),
               convert(deleted))

  db.drop_table :disk_state
end

def self.sync_db(db)
  Klasses.each { |klass| sync_table(db, klass) }
end

def self.sync_path(s, d, db = nil)
  db[:errors].where(path: path_from_db(s)).delete if db
  if File.exists?(s)
    if not File.exists?(d)
      puts "a A #{s}"
      compile(s, d, db)
    elsif File.mtime(s) > File.mtime(d)
      puts "a U #{s}"
      compile(s, d, db)
    end
  elsif File.exists?(d)
    puts "a D #{s}"
    File.delete(d)
  end
end

def self.sync_news(db)
  dir = "#{db[:dir]}/news"
  Dir.entries(dir).each do |e|
    p = "#{dir}/#{e}"
    next if not File.directory?(p) or e == '.' or e == '..'
    sync_path("#{p}/style.scss", "#{p}/style.css", db[:db])
  end
end

def self.assets_changed?
  buntime = File.mtime(Bundle)
  each_css { |p| return true if File.mtime(p) > buntime }
  false
end

def self.mixin_changed?
  mixtime = File.mtime(Mixins)
  each_css { |p| return true if File.mtime(p) < mixtime }
  false
end

def self.sync_main
  each_css { |p| sync_path(src_main(p), p) }
  if mixin_changed?
    sync_all
  else
    each_scss { |s, d| sync_path(s, d) }
  end
  concat if File.mtime(StyleDst) > File.mtime(Bundle) or assets_changed?
end

end

Sync.sync_main
[ DbPathsMain, DbPathsEdit ].each do |p|
  db = db_open(p)
  Sync.sync_news(db)
  Sync.sync_db(db)
end
