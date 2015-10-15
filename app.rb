#!/bin/ruby

require 'rubygems'
require 'bundler'

require_relative 'config'
require_relative 'models'
require_relative 'toc'

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

  def load_last_news(years)
    news = []
    years.each do |year|
      news += load_news(year)
      break if news.size > 10
    end
    news.take(10)
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

  def render_news(news)
    attr = {
      'icons' => 'true',
      'iconsdir' => '/icons',
      'imagesdir' => '/.'
    }
    Asciidoctor.render(news, attributes: attr)
  end
end

module BookHelpers
  def variable_row(name, value)
    return if value.nil? or value.empty?
    erb :'partials/variable_row', locals: { name: name, value: value }
  end

  def comma_present(values)
    values.join(', ')
  end

  def parse_annotation(text)
    return [] if text.nil?
    text.split "\n\n"
  end

  def parse_toc(text)
    TOC::Heading::parse(text.nil? ? '' : text)
  end

  def headings_div(heading)
    return if heading.children.empty?
    erb :'partials/headings', locals: { headings: heading.children }
  end

  def each_book
    Dir.entries('data/books').each do |book|
      next if not File.exist?("data/books/#{book}/info.xml")
      yield book
    end
  end

  def book_cover_url(id, size)
    "/book/#{id}/cover-#{size}.jpg"
  end
end

helpers TeachingsHelpers, ThemeHelpers, CommonHelpers
helpers NewsHelpers, BookHelpers
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
  @news = year.nil? ? load_last_news(@years) : load_news(year)
  @year = year
  erb :news
end

get '/book/:id' do |id|
  File.open("data/books/#{id}/info.xml") do |file|
    @book = BookDocument.new(Nokogiri::XML(file)).book
  end
  @book_slug = id
  erb :book
end

get '/book/:id/:file.jpg' do |id, file|
  puts 'hi'
  send_file "data/books/#{id}/#{file}.jpg"
end

get '/book-category/:id' do |id|
  File.open("data/book-category/#{id}.xml") do |file|
    @category = BookCategoryDocument.new(Nokogiri::XML(file)).category
  end
  @books = {}
  @category.group.each do |group|
    group.book.each do |book|
      File.open("data/books/#{book}/info.xml") do |file|
        @books[book] = BookDocument.new(Nokogiri::XML(file)).book
      end
    end
  end
  erb :'book-category'
end
