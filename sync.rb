#!/bin/ruby

require_relative 'helpers'
require_relative 'convert'

include CommonHelpers

def result_values(set)
  set.to_a.map { |v| v[:path] }
end

$stdout.sync = true

class Database
  def sync_table(klass)
    @db.create_table :disk_state, temp: true do
      String :id, primary_key: true
      String :path, null: false, unique: true
      DateTime :last_modified , null: false
    end

    files = klass.dirs(@dir).map { |d| d.files }.flatten
    files.each do |path|
      @db[:disk_state].insert(id: klass.path_to_id(path),
                             path: path,
                             last_modified: File.mtime(path))
    end

    table = klass.table
    updated = @db[:disk_state].join_table(:left, table, id: :id).
                where{ Sequel[table][:last_modified] <
                       Sequel[:disk_state][:last_modified] }.
                  select(Sequel[:disk_state][:path])

    deleted = @db[table].join_table(:left, :disk_state, id: :id).
                where(Sequel[:disk_state][:id] => nil).
                  select(Sequel[:disk_state][:path])

    added = @db[:disk_state].join_table(:left, table, id: :id).
              where(Sequel[table][:id] => nil).
                select(Sequel[:disk_state][:path])

    update_table(klass,
                 result_values(updated),
                 result_values(added),
                 result_values(deleted))

    @db.drop_table :disk_state
  end

  def sync
    sync_table(Cache::Teaching)
    sync_table(Cache::News)
    sync_table(Cache::Book)
    sync_table(Cache::BookCategory)
    sync_table(Cache::Digest)
  end
end

databases_run(:sync)
