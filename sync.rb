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

def add_disk_state(url, mtime)
  DB[:disk_state].insert(url: url, last_modified: mtime)
end

def find_modifications(table)
  updated = DB[:disk_state].join_table(:left, table, url: :url).
              where{ Sequel[table][:last_modified] <
                     Sequel[:disk_state][:last_modified] }.
                select(Sequel[table][:url])

  deleted = DB[table].join_table(:left, :disk_state, url: :url).
              where(Sequel[:disk_state][:url] => nil).
                select(Sequel[table][:url])

  added = DB[:disk_state].join_table(:left, table, url: :url).
            where(Sequel[table][:url] => nil).select(Sequel[:disk_state][:url])

  yield(result_values(updated),
        result_values(added),
        result_values(deleted))
end

# --------------------- teachings --------------------------

each_file('data/teachings', sorted: true) do |path|
  add_disk_state(path_to_id(path), File.mtime(path))
end

find_modifications(:teachings) do |updated, added, deleted|
  update_teachings(updated, added, deleted)
end
