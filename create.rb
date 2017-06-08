#!/bin/ruby

require 'sequel'
require_relative 'helpers'

include CommonHelpers
include SiteHelpers

def create_db(s)
  db = SiteHelpers.open(s)
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

Sites.each { |s| create_db(s) }
