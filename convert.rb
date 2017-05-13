require_relative 'models'
require_relative 'helpers'
require 'sequel'
require 'preamble'
require 'pathname'
require 'digest'
require 'active_support/core_ext/string/inflections'

include CommonHelpers

DB = Sequel.connect('sqlite://site.db')
DB.run('pragma synchronous = off')
DB.run('pragma foreign_keys = on')

def print_modification(prefix, set)
  set.each { |p| puts "#{prefix} #{p}" }
end

def update_table(klass, updated, added, deleted)
  print_modification('D', deleted)
  print_modification('A', added)
  print_modification('U', updated)

  table = DB[klass.table]
  ids = (deleted + updated).map { |p| klass.path_to_id(p) }
  table.where(id: ids).delete
  (added + updated).each do |p|
    klass.load(p)
    table.select(id: path_to_id(p)).update(last_modified: File.mtime(p))
  end
end

module Cache

module Cacheable
  def table
    to_s.demodulize.tableize.to_sym
  end

  def path_to_id(path)
    CommonHelpers::path_to_id(Pathname.new(path).each_filename.to_a[2])
  end

  def insert_object(table, object, values = {})
    cols = table.columns - [:id, :last_modified]
    cols = cols.select { |c| object.respond_to?(c) }
    v = cols.collect { |c| [ c, object.send(c) ] }.to_h
    values = v.merge(values)
    table.insert(values)
  end

end

module CacheDir
  def split(path)
    path.split('/')
  end
end

class DirFiles
  include CacheDir
  attr_reader :dir

  def initialize(dir)
    @dir = dir
  end

  def files
    dir_files(dir, sorted: true)
  end

  def match(path)
    p = split(path)
    p.size == 3 and p.last =~ /.xml$/
  end
end

# --------------------- teachings --------------------------

class Teaching
  extend Cacheable

  def self.load(path)
    teachings = TeachingsDocument.load(path)

    id = path_to_id(path)
    insert_object(DB[:teachings], teachings, id: id)
    teachings.theme.each do |theme|
      theme_id = insert_object(DB[:themes], theme, teaching_id: id)
      theme.record.each do |record|
        insert_object(DB[:records], record, theme_id: theme_id)
      end
    end
  end

  def self.dirs
    [ DirFiles.new('data/teachings') ]
  end
end

# --------------------- news --------------------------

class NewsDir
  include CacheDir
  Ext = [:html, :erb]

  def dir
    'data/news'
  end

  def files
    files = dir_files(dir, sorted: true).map do |path|
      if File.directory?(path)
        paths = Ext.map { |ext| "#{path}/page.#{ext}" }
        paths.find { |path| File.exists?(path) }
      elsif Ext.include?(path_to_ext(path).to_sym)
        path
      end
    end
    files.compact
  end

  def match(path)
    p = split(path)
    (p.size == 3 and p.last =~ /\.(erb|html)$/) or
      (p.size == 4 and p.last =~ /^page\.(erb|html)$/)
  end
end

class News
  extend Cacheable

  def self.load(path)
    news = NewsDocument.new(path)
    insert_object(DB[:news], news, id: path_to_id(path))
  end

  def self.dirs
    [ NewsDir.new ]
  end
end

# --------------------- books --------------------------

class BookDir
  include CacheDir
  def dir
    'data/books'
  end

  def files
    dir_files(dir, sorted: true).map do |path|
      "#{path}/info.xml"
    end
  end

  def match(path)
    p = split(path)
    p.size == 4 and p.last =~ /^info\.xml$/
  end
end

class Book
  extend Cacheable

  def self.load(path)
    book = BookDocument.load(path)
    insert_object(DB[:books], book, { id: path_to_id(path) })
  end

  def self.dirs
    [ BookDir.new ]
  end
end

class BookCategory
  extend Cacheable

  def self.load(path)
    category = BookCategoryDocument.load(path)

    id = path_to_id(path)
    insert_object(DB[:book_categories], category, id: id)
    category.group.each do |group|
      group.book.each do |book|
        DB[:category_books].
          insert(group: group.name,
                 book_id: book,
                 category_id: id)
      end
    end

    category.subcategory.each do |subcategory|
      DB[:category_subcategories].
        insert(category_id: id,
               subcategory_id: subcategory)
    end
  end

  def self.dirs
    [ DirFiles.new('data/book-categories') ]
  end
end

# --------------------- digests --------------------------

class DigestDir
  attr_reader :dir

  def initialize(dir, options)
    @dir = dir
    @match = options[:match]
    @excludes = options[:excludes]
  end

  def files
    `find #{dir} -type f`.split.select { |path| match(path) }
  end

  def match(path)
    if @excludes
      if @excludes.any? { |e| path.start_with?("#{dir}/#{e}") }
        return false
      end
    end
    return @match =~ path
  end
end

class Digest
  extend Cacheable

  def self.path_to_id(path)
    path.gsub(/^(data|public)/, '')
  end

  def self.load(path)
    DB[:digests].insert(id: path_to_id(path),
                        digest: ::Digest::SHA1.file(path).hexdigest)
  end

  def self.dirs
    [ DigestDir.new('data', match: /\.(jpg|gif|swf|css|doc|pdf)$/),
      DigestDir.new('public',
        match: /\.(mp3|css|js|ico|png|svg|jpg)$/,
        excludes: [ '3d-party', 'logs', 'css', 'fonts' ] ) ]
  end
end

end
