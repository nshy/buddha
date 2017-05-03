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

enable :sessions
set :session_secret, SiteConfig::SESSION_SECRET
set :sessions, :domain => SiteConfig::DOMAIN
set :sessions, :path => '/'
set :sessions, :key => 'session'

set :show_exceptions, false
set :bind, '0.0.0.0'
if settings.development?
  set :static_cache_control, [ :public, max_age: 0 ]
end

helpers TeachingsHelper, CommonHelpers
helpers NewsHelpers, BookHelpers
helpers TimetableHelper

I18n.default_locale = :ru
SiteData = 'data'

before do
  @menu = MenuDocument.load("data/menu.xml")
  @ya_metrika = SiteConfig::YA_METRIKA
  @extra_styles = []
end

not_found do
  @menu_active = nil
  map = {}
  File.open("data/compat.yaml") do |file|
    map = YAML.load(file.read)
  end
  uri = local_uri(URI::unescape(request.path),
                  URI::unescape(request.query_string))
  goto = map[uri]
  redirect to(goto) if not goto.nil?
  @redirection = "#{SiteConfig::OLD_SITE}#{uri}"
  erb :'try-old-site'
end

error do
  erb :error
end

get /.+\.(jpg|gif|swf|css|ttf)/ do
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

get '/teachings/' do
  @teachings = Cache::Teaching.archive
  @menu_active = :teachings
  erb :'teachings-index'
end

get '/teachings/:id/' do |id|
  @teachings = TeachingsDocument.load("data/teachings/#{id}.xml")
  halt 404 if @teachings.nil?
  @teachings_slug = id
  @menu_active = :teachings
  erb :teachings
end

get '/news' do
  @params = params
  if params['top'] == 'true'
    @news = Cache::News.latest(10)
    params.delete('top')
  elsif not params['year'].nil?
    @year = params.delete('year')
    @news = Cache::News.by_year(@year)
  end
  halt 404 if @news.nil? or @news.empty? or not params.empty?
  @years = Cache::News.years
  @menu_active = :news
  @extra_styles = @news.map { |n| n.style }
  @extra_styles.compact!
  @context_url = '/news/'
  erb :'news-index'
end

get '/news/:id/' do |id|
  @news = Cache::News.by_id(id)
  halt 404 if @news.nil?
  @extra_styles = [ @news.style ]
  @extra_styles.compact!
  @menu_active = :news
  erb :'news-single'
end

get '/books/:id/' do |id|
  @book = Cache::Book.find(id)
  halt 404 if @book.nil?
  @menu_active = :library
  erb :book
end

get '/book-categories/:id/' do |id|
  @category = Cache::Category.find(id)
  halt 404 if @category.nil?
  @menu_active = :library
  erb :'book-category'
end

get '/library/' do
  @sections = Cache::Section.all
  @books = Cache::Book.recent(5)
  @menu_active = :library
  erb :library
end

get '/timetable' do
  @timetable = TimetableDocument.load('data/timetable/timetable.xml')
  @menu_active = :timetable
  show = params.delete('show')
  @skip = params.delete('skip') || 0
  @skip = @skip.to_i
  halt 404 if not params.empty?
  if show == 'week'
    erb :timetable
  elsif show == 'schedule'
    erb :classes
  else
    halt 404
  end
end

get '/teachers/:teacher/' do |teacher|
  teachers = {
  'geshela' => 'Досточтимый Геше Джампа Тинлей',
  'hh-bogdo-gegen-9' => 'Его Святейшество Богдо-геген IX',
  'hh-dalai-lama-14' => 'Его Святейшество Далай-лама XIV'
  }
  @teacher = teacher
  @teacher_title = teachers[teacher]
  halt 404 if @teacher_title.nil?
  erb :teacher
end

get '/yoga/' do
  erb "<%= load_page('yoga/page.erb', '/yoga/') %>"
end

get /^\/(about|teachers|contacts|donations)\/$/ do
  @menu_active = :about
  erb :center
end

get '/' do
  @news = Cache::News.latest(3)
  @extra_styles = @news.map { |n| n.style }
  @extra_styles.compact!
  @timetable = TimetableDocument.load('data/timetable/timetable.xml')
  @quotes = QuotesDocument.load('data/quotes.xml')
  @records = Cache::Record.latest(5)
  erb :index
end

get '/not-found/*' do
  @uri = local_uri("/#{params['splat'][0]}", request.query_string)
  erb :'not-found'
end

get '/error/' do
  raise 'error'
end

get '/login/?' do
  erb :login
end

post '/login' do
  if params[:password] == SiteConfig::ADMIN_CONFIG
    session[:login] = true
    redirect to('/')
  else
    redirect to('/login')
  end
end
