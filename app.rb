#!/usr/bin/ruby

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
helpers SiteHelpers, AppSites, AdminHelpers

DB = AppSites.connect
Sequel::Model.plugin :sharding

require_relative 'models'
require_relative 'book'
require_relative 'timetable'
require_relative 'cache'
require_relative 'diff'
require_relative 'gesheru'
require_relative 'himalai'

def whitelist_address
  port = ":#{SiteConfig::PORT}" if SiteConfig::PORT != 80
  "http://#{SiteConfig::DOMAIN}#{port}"
end

enable :sessions
set :protection, origin_whitelist: [ whitelist_address ],
                 except: :remote_token
set :session_secret, SiteConfig::SESSION_SECRET
set :sessions, :domain => SiteConfig::DOMAIN
set :sessions, :path => '/'
set :sessions, :key => 'session'

set :cookie_options, :domain => SiteConfig::DOMAIN
set :cookie_options, :path => '/'

set :show_exceptions, false
set :bind, '0.0.0.0'
if settings.development?
  set :static_cache_control, [ :public, max_age: 0 ]
end


I18n.default_locale = :ru

class DbExeption < RuntimeError
end

LastSeen = '.lastseen'

before do
  # break session if user has not been seen more than 1 hour
  if session[:login] and
     File.exist?(LastSeen) and
     File.stat(LastSeen).mtime + 3600 < Time.now
    session[:login] = false
    cookies[:nocache] = 0
  end

  FileUtils.touch(LastSeen) if session[:login]

  @menu = Menu::Document.load('menu.xml')
  @extra_styles = []
  @extra_scripts = []
  if not site_errors.empty? \
     and request.path != '/admin/' \
     and request.path != '/commit' \
     and request.path != '/reset' \
     and request.path != '/conflicts' \
     and request.path != '/logout' \
     and request.path != '/login' \
     and request.path != '/bundle.css' \
     and not request.path.start_with?('/css/')

    raise DbExeption.new
  end
  cache_control :private if session[:login]
end

not_found do
  dirs = [build_dir, site_build_dir, site_dir]
  paths = dirs.collect { |d| File.join(d, request.path) }
  p = paths.find { |p| File.file?(p) }
  return send_app_file(p) if p

  begin
    p = find_simple_page
    if p
      status 200
      check_url_nice(p)
      return simple_page(p)
    end
  rescue ModelException => e
    status 500
    return show_error(e.message)
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

get '/teachings/' do
  @teachings = site_model(Cache::Teaching).archive
  @menu_active = 'УЧЕНИЯ'
  erb :'teachings-index'
end

get '/teachings/:id/' do |id|
  @teachings = Teachings::Document.load(find_page("teachings/#{id}", 'xml'))
  halt 404 if @teachings.nil?
  @teachings_slug = id
  @menu_active = 'УЧЕНИЯ'
  erb :teachings
end

get '/news' do
  @index = Index::Document.load(site_path('index.xml'))
  @params = params
  if params['top'] == 'true'
    @news = site_model(Cache::News).latest(10)
    params.delete('top')
  elsif not params['year'].nil?
    @year = params.delete('year')
    @news = site_model(Cache::News).by_year(@year)
  end
  @geshe_news = site_model(Cache::Gesheru).recent(@index.geshe_news.num)
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
  @extra_scripts += @news.scripts
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
  @books = site_model(Cache::Book).recent(3)
  @himalai = site_model(Cache::HimalaiBook).all
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
  @index = Index::Document.load(site_path('index.xml'))
  @news = site_model(Cache::News).latest(@index.news.num)
  @extra_styles = news_styles(@news)
  @timetable = Timetable::Document.load(site_path('timetable/timetable.xml'))
  @quotes = load_quotes(site_path('quotes'))
  @records = site_model(Cache::Record).latest(@index.records.num)
  @geshe_news = site_model(Cache::Gesheru).recent(@index.geshe_news.num)
  @banner = nil
  b = site_path('banner.html')
  if File.exists?(b)
    @banner = File.read(b).strip
  end
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
  if true
  # if params[:password] == SiteConfig::ADMIN_SECRET
    session[:login] = true
    cookies[:nocache] = 1
    FileUtils.touch(LastSeen)
    execute("./gitop.sh rebase 1>&2")
    l = execute("./gitop.sh log")
    if l.split("\n").empty?
      redirect to('/')
    else
      erb :conflicts
    end
  else
    redirect to('/login')
  end
end

get '/reset' do
  if not session[:login]
    redirect to('/login')
    return
  end
  execute("./gitop.sh reset")
  # hack, give some time for watch process to update cache
  sleep(3)
  redirect to('/')
end

post '/logout' do
  session[:login] = false
  cookies[:nocache] = 0
  redirect to('/')
end

get '/admin/' do
  if not session[:login]
    redirect to('/login')
    return
  end
  @diff = parse_diff(execute("./gitop.sh diff"))
  @binary = @diff.select { |f| f.mode == :binary }
  @text = @diff.select { |f| f.mode == :text }
  erb :admin
end

post '/commit' do
  if not session[:login]
    redirect to('/login')
    return
  end
  session[:result] = false
  if params[:message].empty?
    session[:notice] = 'Описание изменения не должно быть пустым'
    redirect to('/admin/#notice')
    return
  end
  diff = execute("./gitop.sh diff")
  if diff.empty?
    session[:notice] = <<-END
      Нет изменений для публикации. Вероятно, вы не обновили страницу
      управления перед публикацией.
    END
    redirect to('/admin/#notice')
    return
  end
  if not site_errors.empty?
    session[:notice] = <<-END
      Во внесенных изменениях есть ошибки, поэтому результат не может
      быть опубликован. Вероятно, вы не обновили страницу
      управления перед публикацией.
    END
    redirect to('/admin/#notice')
    return
  end
  execute("./gitop.sh rebase 1>&2")
  if not execute("./gitop.sh log").split("\n").empty?
    session[:notice] = <<-END
     Вами и администратором одновременно внесены изменения в одни и
     те же места сайта. Ввиду этой неоднозначности для проведения публикации
     обратитесь к администратору сайта.
    END
    redirect to('/admin/#notice')
    return
  end

  execute("./gitop.sh publish '#{params[:message]}' 1>&2")
  FileUtils.rm_rf(Dir[File.join('.cache', '*')])
  session[:result] = true
  session[:notice] = 'Изменения успешно опубликованы'
  redirect to('/admin/#notice')
end
