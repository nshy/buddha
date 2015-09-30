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

module CommonHelpers
  def each_file(dir)
    Dir.entries(dir).each do |p|
      next if p == '.' or p == '..'
      next if (/.un~$/ =~ p) != nil
      yield dir + '/' +  p
    end
  end

  def format_date(date)
    Date.parse(date).strftime('%d/%m/%y')
  end

  def link_if(show, link, title)
    if show
      "<a href=#{link}>#{title}</a>"
    else
      title
    end
  end

end

module NewsHelpers
  def load_news(year)
    news = []
    dir = "data/news/#{year}"
    each_file(dir) do |path|
      File.open(path) do |file|
        news.push(NewsDocument.new(Nokogiri::XML(file)).news)
      end
    end
    news.sort do |a, b|
      da = Date.parse(a.publish_date)
      db = Date.parse(b.publish_date)
      db <=> da
    end
  end

  def load_years
    years = []
    Dir.entries("data/news").each do |p|
      next if p == '.' or p == '..'
      next if (/.un~$/ =~ p) != nil
      years.push(p)
    end
    years.sort { |a, b| b <=> a }
  end

  def current_year(years)
    cur = years[0]
    prev = years[1]
    "#{cur}/#{prev}"
  end

  def render_news(news)
    attr = {
      'icons' => 'true',
      'iconsdir' => '/icons',
      'imagesdir' => '/.'
    }
    Asciidoctor.render(news, attributes: attr)
  end
end

helpers TeachingsHelpers, ThemeHelpers, CommonHelpers
helpers NewsHelpers
DB = Sequel.connect('sqlite://buddha.db')

get '/teachings' do
  File.open('data/teachings.xml') do |file|
    @archive = ArchiveDocument.new(Nokogiri::XML(file)).archive
  end
  erb :teachings
end

get '/theme/:id' do |id|
  File.open("data/themes/#{id}.xml") do |file|
    @theme = ThemeDocument.new(Nokogiri::XML(file)).theme
  end
  erb :theme
end

get '/news/?:year?' do |year|
  @years = load_years
  @year_news = {}
  if year.nil?
    @year_news[@years[0]] = load_news(@years[0])
    @year_news[@years[1]] = load_news(@years[1])
    @year = nil
  else
    @year_news[year] = load_news(year)
    @year = year
  end
  erb :news
end
