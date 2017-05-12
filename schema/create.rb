#!/bin/ruby

require 'sequel'

db = Sequel.connect('sqlite://../site.db')
db.run('pragma synchronous = off')

file = ARGV[0]
if file
  require_relative file
  db.instance_eval { create }
else
  Dir.entries('.').each do |file|
    next if file == 'create.rb' or (not /\.rb$/ =~ file) or /^\./ =~ file
    require_relative file
    db.instance_eval { create }
  end
end
