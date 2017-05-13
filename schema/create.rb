#!/bin/ruby

require 'sequel'

def create_db(url)
  db = Sequel.connect(url)
  db.run('pragma synchronous = off')

  file = ARGV[0]
  if file
    load "./#{file}"
    db.instance_eval { create }
  else
    Dir.entries('.').each do |file|
      next if file == 'create.rb' or (not /\.rb$/ =~ file) or /^\./ =~ file
      load "./#{file}"
      db.instance_eval { create }
    end
  end
end

create_db('sqlite://../site.db')
create_db('sqlite://../site-edit.db')
