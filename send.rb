#!/bin/ruby

require 'premailer'
require 'restclient'
require 'tilt'
require 'nokogiri'
require 'asciidoctor'
require 'sequel'
require 'set'

require_relative 'mail.rb'
require_relative 'helpers.rb'
require_relative 'models.rb'
require_relative 'resource.rb'
require_relative 'config'

include CommonHelpers

TYPES = [ News, Books, TimeUpdates ]

def type_dir(type)
  Class.new.extend(type).options[:dir]
end

def find_type(dir)
  index = TYPES.index do |type|
    type_dir(type) == dir
  end
  index.nil? ? nil : TYPES[index]
end

def usage()
  puts <<-END
Usage: #{$0} <resource>
  where resource is in #{TYPES.collect { |t| type_dir(t) }}.
  END
  exit
end

usage if ARGV[0].nil?
type = find_type(ARGV[0])
usage if type.nil?

include type

DB = Sequel.connect('sqlite://site.db')

class Context
  include CommonHelpers
  include options[:helpers]
end

delivered = DB[:delivery].select(:rid).where(type: options[:type]).
              map(:rid).to_a

all = Set.new
each_file("data/#{options[:dir]}") do |path|
  all << path_to_id(path)
end
undelivered = all - delivered

if undelivered.empty?
  puts 'everything is already delivered'
  exit
else
  puts 'deliver ids:'
  undelivered.each { |r| puts r }
end

items = {}
undelivered.each do |slug|
  items[slug] = load_item(slug)
end

layout = Tilt::ERBTemplate.new('views/email.erb')
html = layout.render do
  template = Tilt::ERBTemplate.new("views/#{options[:template]}")
  template.render(Context.new, render_options(items))
end

premailer = Premailer.new(html,
  warn_level: Premailer::Warnings::SAFE,
  base_url: "http://#{Config::DOMAIN}",
  with_html_string: true,
  css: [ "public/css/#{options[:css]}", "public/css/email.css" ]
)

if Dir.exist?('dump/feed')
  File.open("dump/feed/#{options[:dir]}.html", 'w') do |file|
    file.write premailer.to_inline_css
  end
end

send = options[:send]
Subscription::send_html("#{send[:email]}@#{Config::DOMAIN}",
                        send[:subject],
                        premailer.to_inline_css)

DB.transaction do
  undelivered.each do |slug|
    DB[:delivery].insert(type: options[:type], rid: slug)
  end
end
