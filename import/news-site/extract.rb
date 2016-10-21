#!/bin/ruby

require 'nokogiri'
require 'date'

def each_file(dir)
  Dir.entries(dir).each do |p|
    # skip any dot files
    next if not /^\./.match(p).nil?
    yield dir + '/' +  p
  end
end

def parse_html(path)
  f = File.open(path)
  yield Nokogiri::HTML(f, nil, 'utf-8')
  f.close
end

each_file 'tmp/html' do |path|
  parse_html path do |html|
    node = File.basename(path).gsub(/\.html$/, '')
    title = html.at_xpath('//div[@id="main"]//h1').text
    body = html.at_xpath('//div[@id="main"]//div[@class="content"]').children.to_s

    date_text = html.at_xpath('//div[@id="main"]//span[@class="submitted"]').text
    date = nil
    if not date_text.empty?
      date = Date.parse(date_text).strftime('%Y-%m-%d')
      name = date
      i = 1;
      while File.exists?("tmp/news/#{name}.html")
        name = "#{date}-#{i}"
        i += 1
      end
    else
      name = node
    end
    File.open("tmp/news/#{name}.html", "w") do |file|
      file.puts '---'
      file.puts "title: \"#{title}\""
      if not date.nil?
        file.puts "publish_date: \"#{date}\""
      else
        file.puts "publish_date:"
      end
      file.puts "buddha_node: \"#{node}\""
      file.puts '---'
      file.puts ''
      file << body
    end
  end
end
