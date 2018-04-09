require 'nokogiri'
require 'sequel'
require 'date'
require 'open-uri'

require_relative 'helpers'

module Gesheru

Article = Struct.new(:title, :date, :href)

class SyncException < RuntimeError
end

def self.parse(doc)
  articles = []
  doc.css(".art-Post .art-Post").each do |article|
    a = article.at_css(".art-PostHeader a")
    if not a
      raise SyncException.new 'cannot find article header'
    end

    h = a.attribute('href')
    if not h
      raise SyncException.new 'cannot find article href'
    end
    href = h.text
    title = a.text

    h = article.at_css(".art-PostMetadataHeader")
    if not h
      raise SyncException.new 'cannot find article metadata'
    end
    date = DateTime.parse(h.text)

    articles << Article.new(title, date, href)
  end
  if articles.empty?
    raise SyncException.new 'cannot find articles'
  end
  articles
end

def self.update
  puts 'Updating geshe.ru news'
  begin
    articles = parse(Nokogiri::HTML(open("http://geshe.ru/archive")))

    Sites.each do |s|
      db = SiteHelpers.open(s)
      db[:gesheru].delete
      articles.each do |a|
        db[:gesheru].insert(title: a.title, date: a.date, href: a.href)
      end
    end
  rescue OpenURI::HTTPError, SocketError, RuntimeError, Errno::EHOSTUNREACH => e
    puts "Can not update gesheru news: #{e}"
  end
end

end #module Gesheru
