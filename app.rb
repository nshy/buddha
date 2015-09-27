#!/bin/ruby

require 'rubygems'
require 'bundler'

require_relative 'config'
require_relative 'models'

Bundler.require(:default, Config::ENV)

require 'tilt/erubis'

module TeachingsHelpers

  def archive_group_by_year(archive)
    archive.teachings.group_by do |teaching|
      teaching.year.strip
    end
  end

  def theme_link(theme)
      page = theme.page.strip
      file = "data/themes/#{page}.xml"
      href = File.exist?(file) ? "themes/#{page}" : ""
      "<a href=\"#{href}\"> #{theme.title.strip} </a>"
  end
end

helpers TeachingsHelpers

get '/teachings' do
  File.open('data/teachings.xml') do |file|
    @archive = ArchiveDocument.new(Nokogiri::XML(file)).archive
    puts @archive
  end
  erb :teachings
end
