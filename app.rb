#!/bin/ruby

require 'rubygems'
require 'bundler'

require_relative 'config'
Bundler.require

require 'tilt/erubis'
require 'sinatra/capture'
require 'set'
require 'yaml'

require_relative 'helpers'
helpers TeachingsHelper, CommonHelpers
helpers NewsHelpers, BookHelpers
helpers TimetableHelper, LibraryHelper
helpers SiteHelpers, AppSites

DB = AppSites.connect
Sequel::Model.plugin :sharding

require_relative 'models'
require_relative 'book'
require_relative 'timetable'
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


I18n.default_locale = :ru

class DbExeption < RuntimeError
end

before do
  @menu = Menu::Document.load(site_path('menu.xml'))
  @ya_metrika = SiteConfig::YA_METRIKA
  @extra_styles = []
  if not site_model(Cache::Error).all.empty? and request.path != '/logout'
    raise DbExeption.new
  end
end

not_found do
  @menu_active = nil
  map = {}
  File.open(site_path('compat.yaml')) do |file|
    map = YAML.load(file.read)
  end
  uri = local_uri(URI::unescape(request.path),
                  URI::unescape(request.query_string))
  goto = map[uri]
  redirect to(goto) if not goto.nil?
  @redirection = "#{SiteConfig::OLD_SITE}#{uri}"
  erb :'try-old-site'
end

error DbExeption do
  if session[:login] or settings.development?
    site_model(Cache::Error).all.collect { |e| e.message }.join("\n\n")
  else
    erb :error
  end
end

error ModelException do
  if session[:login] or settings.development?
    env['sinatra.error'].message
  else
    erb :error
  end
end

error do
  if settings.development?
    env['sinatra.error'].message
  else
    erb :error
  end
end

get /.+\.(jpg|gif|swf|css|ttf)/ do
  if settings.development?
    cache_control :public, max_age: 0
  end
  send_file site_path(request.path)
end

get /.+\.(doc|pdf)/ do
  if settings.development?
    cache_control :public, max_age: 0
  end
  send_file site_path(request.path), disposition: :attachment
end

get '/teachings/' do
  @teachings = site_model(Cache::Teaching).archive
  @menu_active = 'УЧЕНИЯ'
  erb :'teachings-index'
end

get '/teachings/:id/' do |id|
  @teachings = Teachings::Document.load(site_path("teachings/#{id}.xml"))
  halt 404 if @teachings.nil?
  @teachings_slug = id
  @menu_active = 'УЧЕНИЯ'
  erb :teachings
end

get '/news' do
  @params = params
  if params['top'] == 'true'
    @news = site_model(Cache::News).latest(10)
    params.delete('top')
  elsif not params['year'].nil?
    @year = params.delete('year')
    @news = site_model(Cache::News).by_year(@year)
  end
  halt 404 if @news.nil? or @news.empty? or not params.empty?
  @years = site_model(Cache::News).years
  @menu_active = 'НОВОСТИ'
  @extra_styles = news_styles(@news)
  erb :'news-index'
end

get '/news/:id/' do |id|
  @news = site_model(Cache::News).by_id(id)
  halt 404 if @news.nil?
  @extra_styles = news_styles([ @news ])
  @menu_active = 'НОВОСТИ'
  erb :'news-single'
end

get '/books/:id/' do |id|
  @book = site_model(Cache::Book).find(id)
  halt 404 if @book.nil?
  @menu_active = 'БИБЛИОТЕКА'
  erb :book
end

get '/book-categories/:id/' do |id|
  @category = site_model(Cache::Category).find(id)
  halt 404 if @category.nil?
  @menu_active = 'БИБЛИОТЕКА'
  erb :'book-category'
end

get '/library/' do
  @sections = load_sections
  @books = site_model(Cache::Book).recent(5)
  @menu_active = 'БИБЛИОТЕКА'
  erb :library
end

get '/timetable' do
  @timetable = Timetable::Document.load(site_path('timetable/timetable.xml'))
  @menu_active = 'ЗАНЯТИЯ'
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
  @menu_active = 'О ЦЕНТРЕ'
  simple_page
end

get '/yoga/' do
  @menu_active = 'ЗАНЯТИЯ'
  simple_page
end

get '/texts/' do
  @menu_active = 'БИБЛИОТЕКА'
  simple_page
end

get /about/ do
  @menu_active = 'О ЦЕНТРЕ'
  simple_page
end

get /teachers/ do
  @menu_active = 'О ЦЕНТРЕ'
  simple_page
end

get /contacts/ do
  @menu_active = 'О ЦЕНТРЕ'
  simple_page
end

get /donations/ do
  @menu_active = 'О ЦЕНТРЕ'
  simple_page
end

get '/' do
  @news = site_model(Cache::News).latest(3)
  @extra_styles = news_styles(@news)
  @timetable = Timetable::Document.load(site_path('timetable/timetable.xml'))
  @quotes = Quotes::Document.load(site_path('quotes.xml'))
  @records = site_model(Cache::Record).latest(5)
  @index = Index::Document.load(site_path('index/index.xml'))
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
  if params[:password] == SiteConfig::ADMIN_SECRET
    session[:login] = true
    redirect to('/')
  else
    redirect to('/login')
  end
end

get '/logout/?' do
  session[:login] = false
  redirect to('/')
end
