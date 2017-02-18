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

def sync_table(klass)
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

# --------------------- teachings --------------------------

each_file('data/teachings', sorted: true) do |path|
  add_disk_state(path_to_id(path), File.mtime(path))
end

sync_table(Cache::Teaching)

# --------------------- news --------------------------

each_file('data/news', sorted: true) do |path|
  if File.directory?(path)
    page = Cache::News::find_file(path, 'page')
    next if page.nil?
  else
    next if not Cache::News::Ext.include?(path_to_ext(path).to_sym)
    page = path
  end
  add_disk_state(path_to_id(path), File.mtime(page))
end

sync_table(Cache::News)

# --------------------- books --------------------------

each_file('data/books', sorted: true) do |path|
  add_disk_state(path_to_id(path), File.mtime("#{path}/info.xml"))
end

sync_table(Cache::Book)

each_file('data/book-categories', sorted: true) do |path|
  add_disk_state(path_to_id(path), File.mtime(path))
end

sync_table(Cache::BookCategory)

sync_root_table(:top_categories, 'data/library.xml') { Cache.load_library() }

# --------------------- digests --------------------------

pub = `find public -type f`.split.select do |path|
  not path.start_with?('public/3d-party/') and not /\.un~$/ =~ path
end

data = `find data -type f`.split.select do |path|
  /\.(jpg|gif|swf|css|doc|pdf)$/ =~ path
end

(pub + data).each do |path|
  add_disk_state(Cache::Digest.path_to_id(path), File.mtime(path))
end

sync_table(Cache::Digest)
