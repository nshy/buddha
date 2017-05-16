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

def self.sync(db)
  Klasses.each { |klass| sync_table(db, klass) }
end

end

Sync.sync(db_open(DbPathsMain))
Sync.sync(db_open(DbPathsEdit))
