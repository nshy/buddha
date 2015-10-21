#!/bin/ruby

require 'rubygems'
require 'bundler'

require_relative 'config'
require_relative 'models'
require_relative 'toc'

Bundler.require(:default, Config::ENV)

require 'tilt/erubis'
require 'set'

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
    size = { audio: record.audio_size, video: record.video_size }[media]
    size = 0 if size.nil?
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

  def path_to_id(path)
    File.basename(path).gsub(/.xml$/, '')
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

  def book_categories(categories, id)
    r = categories.select do |cid, c|
      c.group.any? do |g|
        g.book.include?(id)
      end
    end
    r.keys
  end
end

module CategoryHelpers
  def category_categories(categories, id)
    r = categories.select { |cid, c| c.subcategory.include?(id) }
    r.keys
  end

  def load_categories
    categories = {}
    each_file('data/book-category') do |path|
      File.open(path) do |file|
        categories[path_to_id(path)] =
          BookCategoryDocument.new(Nokogiri::XML(file)).category
      end
    end
    categories
  end

  def count_category(categories, cid, subcategories = nil, books = nil)
    books = Set.new if books.nil?
    subcategories = Set.new if subcategories.nil?
    categories[cid].group.each do |g|
      g.book.each do |bid|
        books.add(bid)
      end
    end
    categories[cid].subcategory.each do |sid|
      next if subcategories.include?(sid)
      count_category(categories, sid, subcategories, books)
    end
    books.size
  end

  def category_link(categories, category)
    locals = { categories: categories, category: category }
    erb :'partials/category_link', locals: locals
  end
end

helpers TeachingsHelpers, ThemeHelpers, CommonHelpers
helpers NewsHelpers, BookHelpers, CategoryHelpers

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
  @categories = load_categories
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
  @categories = load_categories
  @id = id
  erb :'book-category'
end

get '/library' do
  @categories = load_categories
  File.open('data/library.xml') do |file|
    @library = LibraryDocument.new(Nokogiri::XML(file)).library
  end
  erb :library
end
