require_relative 'models'
require_relative 'timetable'
require_relative 'book'
require_relative 'helpers'
require 'sequel'
require 'preamble'
require 'pathname'
require 'digest'
require 'sassc'
require 'active_support/core_ext/string/inflections'

include CommonHelpers

class Site
  attr_reader :database, :site_dir

  def initialize(address)
    db = db_open(address)
    @database = db[:db]
    @site_dir = db[:dir]
  end

  def execute(&b)
    instance_eval &b
  end

  def site_path(path)
    "#{@site_dir}/#{path}"
  end
end

def insert_object(table, object, values = {})
  cols = table.columns - [:id, :last_modified]
  cols = cols.select { |c| object.respond_to?(c) }
  v = cols.collect { |c| [ c, object.send(c) ] }.to_h
  values = v.merge(values)
  table.insert(values)
end

def print_modification(prefix, set)
  set.each { |p| puts "#{prefix} #{p}" }
end

def klass_execute(klass, name, *args)
  klass.instance_method(name).bind(self).call(*args)
end

def klass_dirs(klass)
  klass_execute(klass, :dirs)
end

def klass_load(klass, path, id)
  klass_execute(klass, :load, path, id)
end

def update_table(klass, updated, added, deleted)
  print_modification('b D', deleted)
  print_modification('b A', added)
  print_modification('b U', updated)

  table = database[klass.table]
  ids = (deleted + updated + added).map { |p| klass.path_to_id(p) }
  table.where(id: ids).delete
  (added + updated).each do |p|
    x = path_from_db(p)
    database[:errors].where(path: x).delete
    begin
      klass_load(klass, p, klass.path_to_id(p))
    rescue ModelException => e
      puts e
      database[:errors].insert(path: x, message: e.to_s)
    end
    table.where(id: klass.path_to_id(p)).
      update(path: p, last_modified: File.mtime(p))
  end
end

module Sync

module Document
  def table
    to_s.demodulize.tableize.to_sym
  end

  def path_to_id(path)
    CommonHelpers::path_to_id(Pathname.new(path).each_filename.to_a[2])
  end
end

class DirFiles
  attr_reader :dir

  def initialize(dir)
    @dir = dir
  end

  def files
    dir_files(dir, sorted: true)
  end

  def match(path)
    p = path_split(path)
    p.size == 3 and p.last =~ /.xml$/
  end
end

# --------------------- teachings --------------------------

module Teaching
  extend Document

  def load(path, id)
    teachings = ::Teachings::Document.load(path)

    insert_object(database[:teachings], teachings, id: id)
    teachings.theme.each do |theme|
      theme_id = insert_object(database[:themes], theme, teaching_id: id)
      theme.record.each do |record|
        insert_object(database[:records], record, theme_id: theme_id)
      end
    end
  end

  def dirs
    [ DirFiles.new(site_path("teachings")) ]
  end
end

# --------------------- news --------------------------

class NewsDir
  Ext = [:html, :erb]
  attr_reader :dir

  def initialize(dir)
    @dir = "#{dir}/news"
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
    p = path_split(path)
    (p.size == 3 and p.last =~ /\.(erb|html)$/) or
      (p.size == 4 and p.last =~ /^page\.(erb|html)$/)
  end
end

module News
  extend Document

  def load(path, id)
    news = NewsDocument.new(path)
    insert_object(database[:news], news, id: id)
  end

  def dirs
    [ NewsDir.new(site_dir) ]
  end
end

# --------------------- books --------------------------

class BookDir
  attr_reader :dir

  def initialize(dir)
    @dir = "#{dir}/books"
  end

  def files
    dir_files(dir, sorted: true).map do |path|
      "#{path}/info.xml"
    end
  end

  def match(path)
    p = path_split(path)
    p.size == 4 and p.last =~ /^info\.xml$/
  end
end

module Book
  extend Document

  def load(path, id)
    book = ::Book::Document.load(path)
    insert_object(database[:books], book, id: id)
  end

  def dirs
    [ BookDir.new(site_dir) ]
  end
end

module BookCategory
  extend Document

  def load(path, id)
    category = ::BookCategory::Document.load(path)

    insert_object(database[:book_categories], category, id: id)
    category.group.each do |group|
      group.book.each do |book|
        database[:category_books].
          insert(group: group.name,
                 book_id: book,
                 category_id: id)
      end
    end

    category.subcategory.each do |subcategory|
      database[:category_subcategories].
        insert(category_id: id,
               subcategory_id: subcategory)
    end
  end

  def dirs
    [ DirFiles.new(site_path("book-categories")) ]
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

module Digest
  extend Document

  def self.path_to_id(path)
    a = path_split(path)
    a[0] = nil
    a.join('/')
  end

  def load(path, id)
    database[:digests].insert(id: id, digest: ::Digest::SHA1.file(path).hexdigest)
  end

  def dirs
    [ DigestDir.new(site_dir, match: /\.(jpg|gif|swf|css|doc|pdf)$/),
      DigestDir.new('public',
        match: /\.(mp3|css|js|ico|png|svg|jpg)$/,
        excludes: [ '3d-party', 'logs', 'css', 'fonts' ] ) ]
  end
end

Klasses = [ Teaching, News, Book, BookCategory, Digest ]

end


def compile_str(src)
  options = { style: :expanded, load_paths: [ 'assets/css/' ] }
  dst = SassC::Engine.new(src, options).render
end

def compile_news(spath, dpath)
  id = Sync::News::path_to_id(spath)
  src = File.read(spath)
  src = "#news-#{id} {\n\n#{src}\n}"
  begin
    dst = compile_str(src)
    File.write(dpath, dst)
  rescue SassC::SyntaxError => e
    p = path_from_db(spath)
    msg = "Ошибка компиляции файла #{p}: #{e}"
    database[:errors].insert(path: spath, message: msg)
    puts msg
  end
end

def compile(spath, dpath)
  src = File.read(spath)
  dst = compile_str(src)
  File.write(dpath, dst)
end


StyleSrc = 'assets/css'
StyleDst = 'public/css'
Bundle = 'public/bundle.css'
Mixins = "#{StyleSrc}/_mixins.scss"

def each_css(&block)
  Dir.entries(StyleDst).each do |e|
    next if not /\.css$/ =~ e
    yield "#{StyleDst}/#{e}"
  end
end

def each_scss(&block)
  Dir.entries(StyleSrc).each do |e|
    next if e == '_mixins.scss' or (not /\.scss$/ =~ e)
    n = e.gsub(/\.scss$/, '')
    yield "#{StyleSrc}/#{n}.scss", "#{StyleDst}/#{n}.css"
  end
end

def concat
  bundle = ""
  each_css { |p| bundle += File.read(p) }
  File.write(Bundle, bundle)
end

def dest_news(path)
  path.gsub(/\.scss$/, '.css')
end

def dest_man(path)
  path.gsub(/\.scss$/, '.css').gsub(/^assets/, 'public')
end

def src_main(path)
  path.gsub(/\.css$/, '.scss').gsub(/^public/, 'assets')
end

def sync_all
  puts "a U #{Mixins}"
  each_scss { |s, d| compile(s, d) }
end
