#!/bin/ruby

require 'open-uri'
require 'nokogiri'
require 'preamble'
require_relative '../models'
require_relative '../helpers'

include CommonHelpers
include NewsHelpers
include TeachingsHelper

# Generates compatibility links, so that old site links
# are mapped to new site links like:
# /content/?q=node/395 -> /news/2016-09-04/

SiteData = '../data'

# news map
list = []
News.new("#{SiteData}/news").load.each do |p|
  node = p[:news].buddha_node
  next if node.nil?
  list << { node: node.to_i, id: p[:slug] }
end
list.sort! { |a, b| a[:node] <=> b[:node] }
list.each { |e| puts "/content/?q=node/#{e[:node]}: /news/#{e[:id]}/" }

# teachings map
list = []
load_teachings().each do |p|
  p[:document].theme.each do |theme|
    list << { node: theme.buddha_node.to_i, id: p[:id] }
  end
end
list.sort! { |a, b| a[:node] <=> b[:node] }
list.each { |e| puts "/content/?q=node/#{e[:node]}: /teachings/#{e[:id]}/" }
