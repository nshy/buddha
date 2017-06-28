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

def print_modification(prefix, p)
  puts "#{prefix} #{p}"
end

def table_insert(klass, dir, p)
  table = database[klass.table]
  id = dir.path_to_id(p)
  begin
    check_url_nice(p, klass.table == :digests)
    dir.check(p) if dir.respond_to?(:check)
    klass.load(p, id)
  rescue ModelException => e
    puts e
    database[:errors].insert(path: p, message: e.to_s)
  end
  table.where(id: id).
    update(path: p, last_modified: File.mtime(p))
end

def table_add(klass, dir, paths)
  table = database[klass.table]
  paths.each do |p|
    print_modification('b A', p)
    table_insert(klass, dir, p)
  end
end

def table_update(klass, dir, paths)
  table = database[klass.table]
  table.where(path: paths).delete
  paths.each do |p|
    print_modification('b U', p)
    table_insert(klass, dir, p)
  end
end

def table_delete(klass, paths)
  table = database[klass.table]
  table.where(path: paths).delete
  paths.each do |p|
    print_modification('b D', p)
  end
end

def site_class(klass)
  k = clone
  k.extend(klass)
  k.define_singleton_method(:table) do
    klass.to_s.demodulize.tableize.to_sym
  end
  k
end

module Sync

class DirFiles
  attr_reader :dir

  def initialize(dir, ext)
    @dir = dir
    @ext = ext
    @size = path_split(dir).size
  end

  def path_to_id(path)
    name = path_split(path)[@size]
    CommonHelpers::path_to_id(name)
  end

  def check(path)
    id = path_to_id(path)
    short = "#{dir}/#{id}/page.#{@ext}"
    long = "#{dir}/#{id}.#{@ext}"
    if File.exists?(short) and File.exists?(long)
       raise ModelException.new \
         "Присутствуют оба варианта #{path_from_db(long)} и #{path_from_db(short)} " \
         "Используйте либо вариант с директорией и файлом внутри " \
         "либо только файл."
    end
  end

  def files
    files = dir_files(dir, sorted: true).map do |path|
      dirpath = "#{path}/page.#{@ext}"
      if File.file?(path) and path =~ /\.#{@ext}$/
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
    d = p.size - @size
    (d == 1 and p.last =~ /\.#{@ext}$/) or
      (d == 2 and p.last == "page.#{@ext}")
  end
end

# --------------------- teachings --------------------------

module Teaching
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
    [ DirFiles.new(site_path("teachings"), "xml") ]
  end
end

# --------------------- news --------------------------

module News
  def load(path, id)
    news = NewsDocument.new(path)
    insert_object(database[:news], news, id: id)
  end

  def dirs
    [ DirFiles.new(site_path("news"), "html") ]
  end
end

# --------------------- books --------------------------

module Book
  def load(path, id)
    book = ::Book::Document.load(path)
    insert_object(database[:books], book, id: id)
  end

  def dirs
    [ DirFiles.new(site_path("books"), "xml") ]
  end
end

module BookCategory
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
    [ DirFiles.new(site_path("book-categories"), "xml") ]
  end
end

# --------------------- digests --------------------------

class DigestDir
  attr_reader :dir

  def initialize(dir, options)
    @dir = dir
    @dir_sz = path_split(dir).size
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

  def path_to_id(path)
    a = path_split(path).slice((@dir_sz - 1)..-1)
    a[0] = nil
    a.join('/')
  end
end

module Digest

  def load(path, id)
    database[:digests].insert(id: id, digest: ::Digest::SHA1.file(path).hexdigest)
  end

  def dirs
    [ DigestDir.new(site_dir, match: /\.(jpg|gif|swf|doc|pdf)$/),
      DigestDir.new(build_dir, match: /\.(css)$/),
      DigestDir.new('public',
        match: /\.(css|js|ico|png|svg|jpg)$/,
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
    id = path_split(path)[2]
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
