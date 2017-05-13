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

class FileSet
  attr_reader :dir, :only, :excludes

  def initialize(dir, only, excludes = [])
    @dir = dir
    @only = only
    @excludes = excludes.map { |e| Regexp.new(Regexp.escape("#{@dir}/#{e}")) }
  end

  def match(path)
    return false if /\.un~$/ =~ path
    return false if not @only.nil? and not @only =~ path
    if @excludes
      @excludes.each { |e| return false if e =~ path }
    end
    true
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

  def self.filesets
    [ FileSet.new('data/teachings', /.xml$/) ]
  end

  def self.files
    dir_files('data/teachings', sorted: true)
  end
end

# --------------------- news --------------------------

class News
  extend Cacheable

  Ext = [:html, :erb]

  def self.find_file(dir, name)
    paths = Ext.map { |ext| "#{dir}/#{name}.#{ext}" }
    paths.find { |path| File.exists?(path) }
  end

  def self.load(path)
    news = NewsDocument.new(path)
    insert_object(DB[:news], news, id: path_to_id(path))
  end

  def self.filesets
    [ FileSet.new('data/news', /.(erb|html)$/) ]
  end

  def self.files
    files = dir_files('data/news', sorted: true).map do |path|
      if File.directory?(path)
        Cache::News::find_file(path, 'page')
      elsif Cache::News::Ext.include?(path_to_ext(path).to_sym)
        path
      end
    end
    files.compact
  end
end

# --------------------- books --------------------------

class Book
  extend Cacheable

  def self.load(path)
    book = BookDocument.load(path)
    insert_object(DB[:books], book, { id: path_to_id(path) })
  end

  def self.filesets
    [ FileSet.new('data/books', /info.xml$/) ]
  end

  def self.files
    dir_files('data/books', sorted: true).map do |path|
      "#{path}/info.xml"
    end
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

  def self.filesets
    [ FileSet.new('data/book-categories', /.xml$/) ]
  end

  def self.files
    dir_files('data/book-categories', sorted: true)
  end
end

# --------------------- digests --------------------------

class Digest
  extend Cacheable

  def self.path_to_id(path)
    path.gsub(/^(data|public)/, '')
  end

  def self.load(path)
    DB[:digests].insert(id: path_to_id(path),
                        digest: ::Digest::SHA1.file(path).hexdigest)
  end

  def self.filesets
    [ FileSet.new('public', nil,
                   [
                     '3d-party',
                     'logs',
                     'css',
                     'fonts'
                   ]),
      FileSet.new('data', /\.(jpg|gif|swf|css|doc|pdf)$/)
    ]
  end

  def self.files
    files = filesets.map do |fileset|
      `find #{fileset.dir} -type f`.split.select { |path| fileset.match(path) }
    end
    files.flatten
  end
end

end
