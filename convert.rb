require_relative 'models'
require 'sequel'
require 'preamble'
require 'pathname'
require 'digest'
require 'active_support/core_ext/string/inflections'

DB = Sequel.connect('sqlite://site.db')
DB.run('pragma synchronous = off')
DB.run('pragma foreign_keys = on')

def print_modification(prefix, set, klass)
  set.each { |id| puts "#{prefix} #{klass.id_to_url(id)}" }
end

def update_table(klass, updated, added, deleted)
  print_modification('D', deleted, klass)
  print_modification('A', added, klass)
  print_modification('U', updated, klass)

  DB[klass.table].where('id IN ?', deleted + updated).delete
  (added + updated).each { |id| klass.load(id) }
end

module Cache

module Cacheable
  def table
    to_s.demodulize.tableize.to_sym
  end

  def id_to_url(id)
    "/#{table.to_s.dasherize}/#{id}/"
  end

  def path_to_id(path)
    CommonHelpers::path_to_id(Pathname.new(path).each_filename.to_a[2])
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

  def self.load(id)
    path = "data/teachings/#{id}.xml"
    teachings = TeachingsDocument.load(path)

    DB[:teachings].insert(title: teachings.title,
                          id: id,
                          last_modified: File.mtime(path))

    teachings.theme.each do |theme|
      theme_id = DB[:themes].insert(title: theme.title,
                                    begin_date: theme.begin_date,
                                    buddha_node: theme.buddha_node,
                                    teaching_id: id)

      theme.record.each do |record|
        DB[:records].insert(record_date: record.record_date,
                            description: record.description,
                            audio_url: record.audio_url,
                            audio_size: record.audio_size,
                            youtube_id: record.youtube_id,
                            theme_id: theme_id)
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

  def self.load(id)
    is_dir = false
    path = find_file('data/news', id)
    if path.nil?
      is_dir = true
      path = find_file("data/news/#{id}", 'page')
    end

    cutter = /<!--[\t ]*page-cut[\t ]*-->.*/m

    ext = path_to_ext(path)
    doc = Preamble.load(path)
    body = doc.content
    cut = body.gsub(cutter, '')
    cut = nil if cut == body

    DB[:news].insert(date: Date.parse(doc.metadata['publish_date']),
                     title: doc.metadata['title'],
                     id: id,
                     cut: cut,
                     body: body,
                     ext: ext,
                     is_dir: is_dir,
                     buddha_node: doc.metadata['buddha_node'],
                     last_modified: File.mtime(path))
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

  def self.load(id)
    path = "data/books/#{id}/info.xml"
    book = BookDocument.load(path)

    DB[:books].insert(title: book.title,
                      authors: book.authors,
                      translators: book.translators,
                      year: book.year,
                      isbn: book.isbn,
                      publisher: book.publisher,
                      amount: book.amount,
                      annotation: book.annotation,
                      contents: book.contents,
                      outer_id: book.outer_id,
                      added: book.added,
                      id: id,
                      last_modified: File.mtime(path))
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

  def self.load(id)
    path = "data/book-categories/#{id}.xml"
    category = BookCategoryDocument.load(path)

    DB[:book_categories].
      insert(name: category.name,
             id: id,
             last_modified: File.mtime(path))

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

  def self.id_to_url(id)
    return id
  end

  def self.path_to_id(path)
    path.gsub(/^(data|public)/, '')
  end

  def self.load(id)
    path = "data#{id}"
    path = "public#{id}" if not File.exists?(path)
    DB[:digests].insert(id: id,
                        digest: ::Digest::SHA1.file(path).hexdigest,
                        last_modified: File.mtime(path))
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
