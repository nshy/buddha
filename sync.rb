#!/bin/ruby

require_relative 'helpers'
require_relative 'convert'

include CommonHelpers

DB.create_table :disk_teachings, temp: true do
  primary_key :id
  String :url, null: false, unique: true
  DateTime :last_modified , null: false
end

on_disk = DB[:disk_teachings]
each_file('data/teachings', sorted: true) do |path|
  on_disk.insert(url: path_to_id(path), last_modified: File.mtime(path))
end

updated = on_disk.join_table(:left, :teachings, url: :url).
            where{teachings__last_modified < disk_teachings__last_modified}.
              select(:teachings__url)

deleted = DB[:teachings].join_table(:left, :disk_teachings, url: :url).
            where(disk_teachings__url: nil).select(:teachings__url)

added = on_disk.join_table(:left, :teachings, url: :url).
          where(teachings__url: nil).select(:disk_teachings__url)

def result_values(set)
  set.to_a.map { |v| v[:url] }
end

update_teachings(result_values(updated),
                 result_values(added),
                 result_values(deleted))
