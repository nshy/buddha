#!/bin/ruby

require 'rubygems'
require 'bundler'

require_relative 'config'
require_relative 'models'

Bundler.require(:default, Config::ENV)

require 'tilt/erubis'

module TeachingsHelpers

  def archive_group_by_year(archive)
    archive.teachings.group_by do |teachings|
      teachings.year.strip
    end
  end

  def theme_link(theme)
    page = theme.page.strip
    file = "data/themes/#{page}.xml"
    href = File.exist?(file) ? "theme/#{page}" : ""
    "<a href=\"#{href}\"> #{theme.title.strip} </a>"
  end
end

module ThemeHelpers
  def format_date(record)
    Date.parse(record.record_date).strftime('%d/%m/%y')
  end

  def youtube_link(record)
    "https://www.youtube.com/embed/#{record.youtube_id}"
  end

  def download_link(record, media)
    url = record.send("#{media}_url".to_sym)
    return nil if url.nil? or url.empty?
    title = { audio: 'аудио', video: 'видео' }[media]
    r = DB[:media_size].where(url: url).first
    size = (not r.nil?) ? r[:size] >> 20 : 0
    "<a href=#{url} class=\"btn btn-primary btn-xs record-download\""\
      " download>#{title}, #{size} M6</a>"
  end
end

helpers TeachingsHelpers, ThemeHelpers
DB = Sequel.connect('sqlite://buddha.db')

get '/teachings' do
  File.open('data/teachings.xml') do |file|
    @archive = ArchiveDocument.new(Nokogiri::XML(file)).archive
    puts @archive
  end
  erb :teachings
end

get '/theme/:id' do |id|
  File.open("data/themes/#{id}.xml") do |file|
    @theme = ThemeDocument.new(Nokogiri::XML(file)).theme
  end
  erb :theme
end
