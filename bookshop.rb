require 'nokogiri'
require 'sequel'
require 'open-uri'
require 'fileutils'

require_relative 'helpers'
require_relative 'convert'

module Bookshop

Book = Struct.new(:title, :authors, :href, :image)

def self.parse(doc)
  books = []
  doc.css(".item .book").each do |book|
    t = book.at_xpath("a[@class='title']/h3")
    raise RuntimeError.new 'cannot find book title' if not t
    title = t.content

    h = book.at_xpath("a[@class='title']/@href")
    raise RuntimeError.new 'cannot find book url' if not h
    href = h.content

    a = book.at_xpath("div[@class='breadcrumbs']/a/text()")
    raise RuntimeError.new 'cannot find book author' if not a
    authors = a.content

    i = book.at_xpath("a[@class='title']/img/@src")
    raise RuntimeError.new 'cannot find book image url' if not i
    image = i.content

    books << Book.new(title, authors, href, image)
  end

  raise RuntimeError.new 'cannot find new books' if books.empty?
  books
end

def self.update
  puts 'Updating buddhabook.ru new books'
  begin
    books = parse(Nokogiri::HTML(open("http://www.buddhabook.ru/catalog/novinki/")))
    books = books.slice(0, 3)

    Sites.each do |s|
      Site.for(s).instance_eval do
        database[:bookshop].delete
        dir = site_build_path('bookshop')
        Dir.mkdir(dir) if not File.exist?(dir)
        FileUtils.rm(Dir.glob("#{dir}/*"))
        books.each do |b|
          href = File.basename(b.href)
          href = href.gsub(/[^_\-a-zA-Z0-9]/, '')
          ext = File.extname(b.image)
          image = "#{href}#{ext}"
          database[:bookshop].insert(title: b.title, authors: b.authors,
                                    rel_href: b.href, image: image)
          File.open(File.join(dir, image), "w") do |file|
            url = File.join("http://www.bookshop.ru", b.image)
            file << open(URI.escape(url)).read
          end
        end
      end
    end
  rescue OpenURI::HTTPError, SocketError, RuntimeError, Errno::EHOSTUNREACH => e
    puts "Can not update bookshop.ru books: #{e}"
  end
end

end
