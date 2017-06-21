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
  attr_reader :database, :site
  include SiteHelpers

  def initialize(site, database)
    @site = site
    @database = database
  end

  def clone
    Site.new(@site, @database)
  end

  def self.for(site)
    new(site, SiteHelpers.open(site))
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
    begin
      check_url_nice(p, klass == Sync::Digest)
      klass_load(klass, p, klass.path_to_id(p))
    rescue ModelException => e
      puts e
      database[:errors].insert(path: p, message: e.to_s)
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
  attr_reader :dir

  def initialize(dir)
    @dir = "#{dir}/news"
  end

  def files
    files = dir_files(dir, sorted: true).map do |path|
      dirpath = "#{path}/page.html"
      if File.file?(path) and path =~ /\.html$/
        path
      elsif File.exists?(dirpath)
        dirpath
      else
        nil
      end
    end
    files.compact
  end

  def match(path)
    p = path_split(path)
    (p.size == 3 and p.last =~ /\.html$/) or
      (p.size == 4 and p.last == 'page.html')
  end
end

module News
  extend Document

  def load(path, id)
    size = path_split(path).size
    if size == 3 and File.exists?(site_path("news/#{id}/page.html")) or \
       size == 4 and File.exists?(site_path("news/#{id}.html"))
       raise ModelException.new \
         "Два варианта для новости #{id}. " \
         "Используйте либо директорию либо файл."
    end
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

module Assets

module Extensions
  def css(path)
    path.gsub(/\.scss$/, '.css')
  end

  def scss(path)
    path.gsub(/\.css$/, '.scss')
  end
end

module News
  include Extensions

  def dst(path)
    id = path_split(path)[2]
    site_build_path("news/#{id}.css")
  end

  def src(path)
    id = CommonHelpers::path_to_id(path)
    site_path("news/#{id}/style.scss")
  end

  def preprocess(path, input)
    id = Sync::News::path_to_id(path)
    "#news-#{id} {\n\n#{input}\n}"
  end

  def shorten(path)
    path_from_db(path)
  end
end

module Public
  include Extensions

  def dst(path)
    css(path.gsub(/^assets/, 'public'))
  end

  def src(path)
    scss(path.gsub(/^public/, 'assets'))
  end

  def shorten(path)
    path
  end
end

end

def compile(assets, path)
  input = File.read(path)
  input = assets.preprocess(path, input) if assets.respond_to?(:preprocess)
  options = { style: :expanded, load_paths: [ StyleSrc ] }
  database[:errors].where(path: path).delete
  begin
    res = SassC::Engine.new(input, options).render
    File.write(assets.dst(path), res)
  rescue SassC::SyntaxError => e
    msg = "Ошибка компиляции файла #{assets.shorten(path)}:\n #{e}"
    database[:errors].insert(path: path, message: msg)
    puts msg
  end
end

StyleSrc = 'assets/css'
StyleDst = 'public/css'
Bundle = 'public/bundle.css'
Mixins = "#{StyleSrc}/_mixins.scss"

def list_files(dir, ext, skip = [])
  Dir.entries(dir).each do |e|
    next if not /\.#{ext}$/ =~ e or skip.include?(e)
    yield "#{dir}/#{e}"
  end
end

def each_css(&block)
  list_files(StyleDst, 'css', &block)
end

def each_scss(&block)
  list_files(StyleSrc, 'scss', [ '_mixins.scss'], &block)
end

def concat
  bundle = ""
  each_css { |p| bundle += File.read(p) }
  File.write(Bundle, bundle)
end

def compile_all
  each_scss { |s| compile(Assets::Public, s) }
end
