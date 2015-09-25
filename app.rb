#!/bin/ruby

require 'rubygems'
require 'bundler'

require_relative 'config'

Bundler.require(:default, Config::ENV)

require 'tilt/erubis'

module TeachingsHelpers

  def archive_group_by_year(doc)
    doc.xpath('/archive/teachings').group_by do |teaching|
      teaching.at_xpath('year').content
    end
  end

  def theme_link(theme)
      page = theme.at_xpath('page').content.strip
      file = "data/themes/#{page}.xml"
      href = File.exist?(file) ? "themes/#{page}" : ""
      "<a href=\"#{href}\"> #{theme.at_xpath('title').content.strip} </a>"
  end
end

helpers TeachingsHelpers

get '/teachings' do
  File.open('data/teachings.xml') do |file|
    @doc = Nokogiri::XML(file)
  end
  erb :teachings
end
