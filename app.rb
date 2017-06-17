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
require_relative 'diff'

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
  @menu = Menu::Document.load('menu.xml')
  @ya_metrika = SiteConfig::YA_METRIKA
  @extra_styles = []
  if not site_errors.empty? and request.path != '/admin/'
    raise DbExeption.new
  end
end

not_found do
  p = find_page
  if p
    begin
      check_url_nice(p)
    rescue ModelException => e
      return show_error(e.message)
    end
    status 200
    return simple_page(p)
  end

  @menu_active = nil
  map = {}
  File.open(site_path('compat.yaml')) do |file|
    map = YAML.load(file.read)
  end
  uri = local_uri(URI::unescape(request.path),
                  URI::unescape(request.query_string))
  goto = map[uri]
  if goto
    redirect to(goto)
    return
  end
  @redirection = "#{SiteConfig::OLD_SITE}#{uri}"
  erb :'try-old-site'
end

error DbExeption do
  if session[:login] or settings.development?
    @errors = site_errors
    erb :'error-editor'
  else
    erb :error
  end
end

def show_error(msg)
  if session[:login] or settings.development?
    @errors = [ msg ]
    erb :'error-editor'
  else
    erb :error
  end
end

error ModelException do
  show_error(env['sinatra.error'].message)
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
  params.delete('captures')
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
  params.delete('captures')
  halt 404 if not params.empty?
  if show == 'week'
    erb :timetable
  elsif show == 'schedule'
    erb :classes
  else
    halt 404
  end
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

get '/admin/' do
  @diff = `cd edit; git add .; git diff --staged --no-renames`
  erb :admin
end

post '/commit' do
  session[:result] = false
  if params[:message].empty?
    session[:notice] = 'Описание изменения не должно быть пустым'
    redirect to('/admin/#notice')
    return
  end
  diff = `cd edit; git add .; git diff --staged --no-renames`
  if diff.empty?
    session[:notice] = <<-END
      Нет изменений для публикации. Вероятно, вы не обновили страницу
      управления перед публикацией.
    END
    redirect to('/admin/#notice')
    return
  end
  logger.info `
    set -xe
    cd edit
    git add
    git commit -m '#{params[:message]}'
    cd ../main
    git pull --ff-only edit master || (cd ../edit; git reset HEAD~1; false)
  `
  if $? != 0
    session[:notice] = <<-END
      Невозможно опубликовать изменения из за непредвиденной ошибки.
      Обратитесь к администратору сайта.
    END
    redirect to('/admin/#notice')
    return
  end
  session[:result] = true
  session[:notice] = 'Изменения успешно опубликованы'
  redirect to('/admin/#notice')
end
