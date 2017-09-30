#!/usr/bin/ruby

require 'fileutils'
require_relative 'routines'
require_relative 'tmp/pages'

FileUtils.rm_rf('tmp/html')
Dir.mkdir('tmp/html')

PAGES.each do |node, filename|
  url = "http://lib.geshe.ru/node/#{node}"
  puts "downloading #{url}"
  File.open("tmp/html/#{filename}.html", "w") do |file|
    file << open(url).read
  end
end
