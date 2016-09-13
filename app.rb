#!/bin/ruby

require 'rubygems'
require 'bundler'

require_relative 'config'
Bundler.require(:default, Config::ENV)

require 'tilt/erubis'
require 'sinatra/reloader' if Config::ENV == :development
require 'sinatra/capture'
require 'set'

require_relative 'models'
require_relative 'toc'
require_relative 'timetable'
require_relative 'mail'
require_relative 'helpers'
require_relative 'asciiext'

DB = Sequel.connect('sqlite://site.db')

set :show_exceptions, false
set :bind, '0.0.0.0'

helpers TeachingsHelper, CommonHelpers
helpers NewsHelpers, BookHelpers, CategoryHelpers
helpers TimetableHelper

before do
  File.open("data/menu.xml") do |file|
    @menu = MenuDocument.new(Nokogiri::XML(file)).menu
  end
end

get '/archive/' do
  File.open("data/archive.xml") do |file|
    @archive = ArchiveDocument.new(Nokogiri::XML(file)).archive
  end
  @teachings = load_teachings
  @menu_active = :teachings
  erb :'archive'
end

get '/teachings/:id/' do |id|
  File.open("data/teachings/#{id}.xml") do |file|
    @teachings = TeachingsDocument.new(Nokogiri::XML(file)).teachings
  end
  @teachings_slug = id
  @menu_active = :teachings
  erb :teachings
end

get '/news' do
  @params = params
  @news = load_news
  @menu_active = :news
  erb :'news-index'
end

get '/news/:id/' do |id|
  @news = NewsDocument.new(body_path("data/news/#{id}"))
  @slug = id
  @menu_active = :news
  erb :news
end

get '/book/:id/' do |id|
  File.open("data/books/#{id}/info.xml") do |file|
    @book = BookDocument.new(Nokogiri::XML(file)).book
  end
  @book_slug = id
  @categories = load_categories
  @menu_active = :library
  erb :book
end

get '/book/:id/:file.jpg' do |id, file|
  send_file "data/books/#{id}/#{file}.jpg"
end

get '/book-category/:id/' do |id|
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
  @menu_active = :library
  erb :'book-category'
end

get '/library/' do
  @categories = load_categories
  @books = {}
  File.open('data/library.xml') do |file|
    @library = LibraryDocument.new(Nokogiri::XML(file)).library
  end
  @library.recent.book.each do |book_id|
    File.open("data/books/#{book_id}/info.xml") do |file|
      @books[book_id] = BookDocument.new(Nokogiri::XML(file)).book
    end
  end
  @menu_active = :library
  erb :library
end

get '/news/:news_id/:file' do |news_id, file|
  send_file_media "data/news/#{news_id}/#{file}"
end

get '/timetable' do
  File.open('data/timetable.xml') do |file|
    @timetable = TimetableDocument.new(Nokogiri::XML(file)).timetable
  end
  @menu_active = :timetable
  erb :timetable
end

get '/teachers/' do
  File.open('data/teachers/page.xml') do |file|
    @teachers = TeachersDocument.new(Nokogiri::XML(file)).teachers
  end
  erb :teachers
end

get '/teachers/:file.jpg' do |file|
  send_file "data/teachers/#{file}.jpg"
end

get '/text/:id/' do |id|
  @file = Preamble.load("data/text/#{id}/page.adoc")
  erb :text
end

get '/text/:id/:file' do |id, file|
  send_file_media "data/text/#{id}/#{file}"
end

get '/classes/' do
  File.open('data/classes/page.xml') do |file|
    @classes = ClassesDocument.new(Nokogiri::XML(file)).classes
  end
  erb :classes
end

get '/classes/:file.jpg' do |file|
  send_file "data/classes/#{file}.jpg"
end

get '/donations/' do
  erb :donations
end

get '/links/' do
  render_text('links')
end

get '/about/' do
  @menu_active = :about
  render_text('about')
end

get '/contacts/' do
  render_text('contacts')
end

get '/activities/' do
  render_text('activities')
end

get '/' do
  erb :index
end

error Subscription::Exception do
  @message = env['sinatra.error']
  erb :message
end

post '/subscribe' do
  Subscription::subscribe(params[:email])
  @message = 'Вам отправлено письмо со ссылкой для активации подписки.'
  erb :message
end

get '/subscription/activate' do
  @subscription = Subscription::activate(params[:key])
  @message = <<-END
    Подписка успешна активирована.
    Уточните параметры подписки, если желаете.
  END
  erb :subscription
end

get '/subscription/manage' do
  @subscription = Subscription::check(params[:key])
  @message = 'Параметры подписки'
  erb :subscription
end

post '/subscription/update' do
  @subscription = Subscription::manage(params)
  @message = 'Параметры подписки изменены'
  erb :subscription
end

get '/unsubscribe' do
  Subscription::unsubscribe(params[:key])
  @message = 'Ваша подписка полностью прекращена.'
  erb :message
end
