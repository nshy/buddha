#!/bin/ruby

require 'rubygems'
require 'bundler'

require_relative 'config'

Bundler.require(:default, Config::ENV)

require 'sinatra'
require 'nokogiri'

module TeachingsHelpers
  def teaching_check(teaching)
    return false if teaching.at_xpath('year').nil?
    return false if teaching.at_xpath('title').nil?
    true
  end

  def theme_link(theme)
      href = ""
      page = theme.at_xpath('page')
      if not page.nil?
        file = "data/themes/#{page.content.strip}.xml"
        href = File.exist?(file) ? "themes/#{page.content.strip}" : ""
      end
      "<a href=\"#{href}\"> #{theme.at_xpath('title').content.strip} </a>"
  end
end

helpers TeachingsHelpers

get '/teachings' do
  File.open('data/teachings.xml') do |file|
    @doc = Nokogiri::XML(file)
  end
  erb :teachings
end
