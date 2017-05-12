#!/bin/ruby

require_relative 'helpers'
require_relative 'convert'

include CommonHelpers

DB.create_table :disk_state, temp: true do
  String :id, primary_key: true
  DateTime :last_modified , null: false
end

def result_values(set)
  set.to_a.map { |v| v[:id] }
end

def sync_table(klass)
  klass.files.each do |path|
    DB[:disk_state].insert(id: klass.path_to_id(path),
                           last_modified: File.mtime(path))
  end
  table = klass.table
  updated = DB[:disk_state].join_table(:left, table, id: :id).
              where{ Sequel[table][:last_modified] <
                     Sequel[:disk_state][:last_modified] }.
                select(Sequel[table][:id])

  deleted = DB[table].join_table(:left, :disk_state, id: :id).
              where(Sequel[:disk_state][:id] => nil).
                select(Sequel[table][:id])

  added = DB[:disk_state].join_table(:left, table, id: :id).
            where(Sequel[table][:id] => nil).select(Sequel[:disk_state][:id])

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
sync_table(Cache::Digest)
