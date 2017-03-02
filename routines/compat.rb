#!/bin/ruby

require 'sequel'

DB = Sequel.connect('sqlite://../site.db')

require_relative '../cache'

# Generates compatibility links, so that old site links
# are mapped to new site links like:
# /content/?q=node/395 -> /news/2016-09-04/


def print_list(model, dir)
  list = []
  model.select(:buddha_node, :id).each do |n|
    next if n[:buddha_node].nil?
    list << { node: n[:buddha_node].to_i, id: n[:id] }
  end
  list.sort! { |a, b| a[:node] <=> b[:node] }
  list.each { |e| puts "/content/?q=node/#{e[:node]}: /#{dir}/#{e[:id]}/" }
end

print_list(DB[:news], 'news')
print_list(DB[:themes], 'teachings')
