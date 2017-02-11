#!/bin/ruby

require 'rubygems'
require 'bundler'

require_relative 'config'
Bundler.require

require 'tilt/erubis'
require 'sinatra/capture'
require 'set'
require 'yaml'

DB = Sequel.connect('sqlite://site.db')

require_relative 'models'
require_relative 'toc'
require_relative 'timetable'
require_relative 'helpers'
require_relative 'cache'

set :show_exceptions, false
set :bind, '0.0.0.0'
if settings.development?
  set :static_cache_control, [ :public, max_age: 0 ]
end

helpers TeachingsHelper, CommonHelpers
helpers NewsHelpers, BookHelpers, CategoryHelpers
helpers TimetableHelper

I18n.default_locale = :ru
SiteData = 'data'

before do
  @menu = MenuDocument.load("data/menu.xml")
  @ya_metrika = SiteConfig::YA_METRIKA
  @extra_styles = []
  @digests = load_digests()
end

not_found do
  map = {}
  File.open("data/compat.yaml") do |file|
    map = YAML.load(file.read)
  end
  obj = request.path
  if not request.query_string.empty?
    obj += '?'
    obj += request.query_string
  end
  goto = map[obj]
  redirect to(goto) if not goto.nil?
  "not found"
end

get /.+\.(jpg|gif|swf|css)/ do
  if settings.development?
    cache_control :public, max_age: 0
  end
  send_file "data/#{request.path}"
end

get /.+\.(doc|pdf)/ do
  if settings.development?
    cache_control :public, max_age: 0
  end
  send_file "data/#{request.path}", disposition: :attachment
end

get '/archive/' do
  @teachings = Cache.archive
  @menu_active = :teachings
  erb :'archive'
end

get '/teachings/:id/' do |id|
  @teachings = TeachingsDocument.load("data/teachings/#{id}.xml")
  @teachings_slug = id
  @menu_active = :teachings
  erb :teachings
end

get '/news' do
  @params = params
  if params['top'] == 'true'
    @news = Cache::News.latest(10)
  else
    @news = Cache::News.by_year(params['year'])
  end
  @years = Cache::News.years
  @menu_active = :news
  @extra_styles = @news.map { |n| n.style }
  @extra_styles.compact!
  @context_url = '/news/'
  erb :'news-index'
end

get '/news/:id/' do |id|
  @news = Cache::News.by_url(id)
  @extra_styles = [ @news.style ]
  @extra_styles.compact!
  @slug = id
  @menu_active = :news
  erb :'news-single'
end

get '/book/:id/' do |id|
  @book = BookDocument.load("data/book/#{id}/info.xml")
  @book_slug = id
  @categories = load_categories
  @menu_active = :library
  erb :book
end

get '/book-category/:id/' do |id|
  @category = BookCategoryDocument.load("data/book-category/#{id}.xml")
  @books = {}
  @category.group.each do |group|
    group.book.each do |book|
      @books[book] = BookDocument.load("data/book/#{book}/info.xml")
    end
  end
  @categories = load_categories
  @id = id
  @menu_active = :library
  erb :'book-category'
end

get '/library/' do
  @categories = load_categories
  @books = {}
  @library = LibraryDocument.load('data/library.xml')
  @library.recent.book.each do |book_id|
    @books[book_id] = BookDocument.load("data/book/#{book_id}/info.xml")
  end
  @menu_active = :library
  erb :library
end

get '/timetable' do
  @timetable = TimetableDocument.load('data/timetable/timetable.xml')
  @menu_active = :timetable
  if params[:show] == 'week'
    erb :timetable
  elsif params[:show] == 'schedule'
    erb :classes
  end
end

get '/teachers/:teacher/' do |teacher|
  @teacher = teacher
  erb :teacher
end

get '/yoga/' do
  erb "<%= load_page('yoga/page.erb', '/yoga/') %>"
end

get /\/(about|teachers|contacts|donations)\// do
  @menu_active = :about
  erb :center
end

get '/' do
  @news = Cache::News.latest(3)
  @extra_styles = @news.map { |n| n.style }
  @extra_styles.compact!
  @timetable = TimetableDocument.load('data/timetable/timetable.xml')
  @quotes = QuotesDocument.load('data/quotes.xml')
  @records = Cache.last_records()
  erb :index
end
