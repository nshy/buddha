#!/bin/ruby

require 'open-uri'
require 'nokogiri'
require 'preamble'
require_relative '../models'
require_relative '../helpers'

include CommonHelpers
include NewsHelpers

# Generates compatibility links, so that old site links
# are mapped to new site links like:
# /content/?q=node/395 -> /news/2016-09-04/

# news map
data_dir = "../data"
list = []
each_file("#{data_dir}/news") do |file|
  id = File.basename(file).gsub(/.adoc$/, '')
  news = NewsDocument.new(body_path("#{data_dir}/news/#{id}"))
  list << { node: news.buddha_node.to_i, id: id }
end
list.sort! { |a, b| a[:node] <=> b[:node] }
list.each { |e| puts "content/?q=node/#{e[:node]}: news/#{e[:id]}" }

# teachings map
list = []
each_file("#{data_dir}/teachings") do |file|
  File.open(file) do |file|
    teachings = TeachingsDocument.new(Nokogiri::XML(file)).teachings
    teachings.theme.each do |theme|
      list << { node: theme.buddha_node.to_i, id: path_to_id(file) }
    end
  end
end
list.sort! { |a, b| a[:node] <=> b[:node] }
list.each { |e| puts "content/?q=node/#{e[:node]}: teachings/#{e[:id]}" }
