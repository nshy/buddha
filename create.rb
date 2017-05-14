#!/bin/ruby

require 'sequel'
require_relative 'helpers'

include CommonHelpers

def create_db(paths)
  db = db_open(paths)[:db]
  file = ARGV[0]
  if file
    load file
    db.instance_eval { create }
  else
    Dir.entries('schema').each do |file|
      next if file == 'schema/create.rb' or (not /\.rb$/ =~ file) or /^\./ =~ file
      load "schema/#{file}"
      db.instance_eval { create }
    end
  end
end

create_db(DbPathsMain)
create_db(DbPathsEdit)
