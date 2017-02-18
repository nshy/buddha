#!/bin/ruby

require_relative 'helpers'
require_relative 'convert'

include CommonHelpers

DB.create_table :disk_state, temp: true do
  primary_key :id
  String :url, null: false, unique: true
  DateTime :last_modified , null: false
end

def result_values(set)
  set.to_a.map { |v| v[:url] }
end

def sync_table(klass)
  klass.files.each do |path|
    DB[:disk_state].insert(url: klass.path_to_id(path),
                           last_modified: File.mtime(path))
  end
  table = klass.table
  updated = DB[:disk_state].join_table(:left, table, url: :url).
              where{ Sequel[table][:last_modified] <
                     Sequel[:disk_state][:last_modified] }.
                select(Sequel[table][:url])

  deleted = DB[table].join_table(:left, :disk_state, url: :url).
              where(Sequel[:disk_state][:url] => nil).
                select(Sequel[table][:url])

  added = DB[:disk_state].join_table(:left, table, url: :url).
            where(Sequel[table][:url] => nil).select(Sequel[:disk_state][:url])

  update_table(klass,
               result_values(updated),
               result_values(added),
               result_values(deleted))
  DB[:disk_state].delete
end

sync_table(Cache::Teaching)
sync_table(Cache::News)
sync_table(Cache::Book)
sync_table(Cache::BookCategory)

sync_root_table(:top_categories, 'data/library.xml') { Cache.load_library() }

sync_table(Cache::Digest)
