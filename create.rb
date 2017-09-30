#!/usr/bin/ruby

require 'sequel'
require_relative 'helpers'
require_relative 'utils'

include CommonHelpers
include SiteHelpers

class DbFile
  def initialize(db, path)
    @db = db
    @path = path
    @db[:schema_files].insert(path: path, mtime: File.mtime(path))
  end

  def create_table(name, &b)
    @db[:file_tables].insert(name: name.to_s, path: @path)
    @db.create_table(name, &b)
  end
end


def sync_schema(s)
  db = SiteHelpers.open(s)

  db.create_table?(:schema_files) do
    String :path, primary_key: true
    DateTime :mtime, null: false
  end

  db.create_table?(:file_tables) do
    primary_key :id
    String :name, null: false
    foreign_key :path, :schema_files, key: :path,
      type: String, on_delete: :cascade
  end

  files = dir_files('schema').select { |f| File.extname(f) == '.rb' }

  u, a, d = Cache.diff(db, :schema_files, files)
  Cache.diffmsg(u, a, d)

  (d + u).each do |p|
    e = db[:file_tables].where(path: p)
    names = e.map { |i| i[:name].to_sym }
    names.each { |n| db.drop_table(n) }
    db[:schema_files].where(path: p).delete
  end

  (u + a).each do |p|
    load p
    DbFile.new(db, p).instance_eval { create }
  end
end

Sites.each { |s| sync_schema(s) }
