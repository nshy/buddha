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
  cols = table.columns - [:id, :mtime]
  cols = cols.select { |c| object.respond_to?(c) }
  v = cols.collect { |c| [ c, object.send(c) ] }.to_h
  values = v.merge(values)
  table.insert(values)
end

def table_insert(klass, p)
  table = database[klass.table]
  # search dir
  dir = klass.dirs.find { |d| p.start_with?(d.dir) }
  id = dir.path_to_id(p)
  begin
    check_url_nice(p, [:digest_sha1s, :digest_uuids].include?(klass.table))
    klass.load(p, id)
  rescue ModelException => e
    puts e
    database[:errors].insert(path: p, message: e.to_s)
  end
  table.where(path: p).
    update(id: id, mtime: File.lstat(p).mtime)
end

def table_update(klass, u, a, d)
  Cache.diffmsg(u, a, d, 'b')
  # on move "added" can be generated for existing files
  database[klass.table].where(path: u + a + d).delete
  (a + u).each { |p| table_insert(klass, p) }
end

def data_dir(dir, ext)
  [ DirFiles.new(site_path(dir), ext, DirFiles::BOTH, name: "page") ]
end

def site_class(klass)
  k = clone
  k.extend(klass)
  k.define_singleton_method(:table) do
    klass.to_s.demodulize.tableize.to_sym
  end
  k
end

class DirFiles
  attr_reader :dir, :ext, :dir

  PLAIN = 1
  IN_DIR = 2
  BOTH = 3

  def initialize(dir, ext, mode, options = {})
    @dir = dir
    @ext = ".#{ext}"
    @options = options
    @size = path_split(dir).size
    @mode = mode
    if (@mode & IN_DIR) != 0 and not @options[:name]
      raise "If directory mode is requested then name option must be set"
    end
  end

  def name
    @options[:name]
  end

  def exclude
    @options[:exclude]
  end

  def full_name
    "#{name}#{ext}"
  end

  def path_to_id(path)
    name = path_split(path)[@size]
    File.basename(name, '.*')
  end

  def id_to_path(id)
    case @mode
    when IN_DIR
      File.join(dir, id, full_name)
    when PLAIN
      File.join(dir, "#{id}#{ext}")
    else
      raise "This operation is not defined for this mode"
    end
  end

  def files
    files = dir_files(dir, sorted: true).map do |path|
      dirpath = File.join(path, full_name)
      if (@mode & PLAIN) and File.file?(path) and File.extname(path) == ext
        path
      elsif (@mode & IN_DIR) and File.exists?(dirpath)
        dirpath
      else
        nil
      end
    end
    files.compact!
    files -= exclude if exclude
    files
  end

  def match(path)
    p = path_split(path)
    d = p.size - @size
    ((@mode & PLAIN) and d == 1 and File.extname(p.last) == ext) or
      ((@mode & IN_DIR) and d == 2 and p.last == full_name)
  end
end

module Sync

# --------------------- teachings --------------------------

module Teaching
  def load(path, id)
    teachings = ::Teachings::Document.load(path)

    insert_object(database[:teachings], teachings, path: path, id: id)
    teachings.theme.each do |theme|
      theme_id = insert_object(database[:themes], theme,
                               teaching_id: id, teaching_path: path)
      theme.record.each do |record|
        insert_object(database[:records], record, theme_id: theme_id)
      end
    end
  end

  def dirs
    data_dir("teachings", "xml")
  end
end

# --------------------- news --------------------------

module News
  def load(path, id)
    news = NewsDocument.new(path)
    insert_object(database[:news], news, path: path)
  end

  def dirs
    data_dir("news", "html")
  end
end

# --------------------- books --------------------------

module Book
  def load(path, id)
    book = ::Book::Document.load(path)
    insert_object(database[:books], book, path: path)
  end

  def dirs
    data_dir("books", "xml")
  end
end

module BookCategory
  def load(path, id)
    category = ::BookCategory::Document.load(path)

    insert_object(database[:book_categories],category,
                  path: path, id: id)
    category.group.each do |group|
      group.book.each do |book|
        database[:category_books].
          insert(group: group.name,
                 book_id: book,
                 category_path: path,
                 category_id: id)
      end
    end

    category.subcategory.each do |subcategory|
      database[:category_subcategories].
        insert(category_path: path,
               category_id: id,
               subcategory_id: subcategory)
    end
  end

  def dirs
    data_dir("book-categories", "xml")
  end
end

# --------------------- digests --------------------------

class DigestDir
  attr_reader :dir

  def initialize(dir, options = {})
    @dir = dir
    @dir_sz = path_split(dir).size
    @match = options[:match]
    @exclude = options[:exclude]
  end

  def files
    Dir[File.join(dir, '**', '*')].select { |p| File.file?(p) and match(p) }
  end

  def match(path)
    # slice is for the first directory that can contain '.' like '.build'
    return false if path_split(path).slice(1..-1).any? { |e| /^\./ =~ e }
    return false if @exclude and @exclude.call(dir, path)
    return false if @match and not @match.call(path)
    true
  end

  def path_to_id(path)
    a = path_split(path).slice((@dir_sz - 1)..-1)
    a[0] = nil
    a.join('/')
  end
end

module Digest_SHA1

  def load(path, id)
    database[:digest_sha1s].insert(path: path,
                                   sha1: ::Digest::SHA1.file(path).hexdigest)
  end

  def dirs
    # order is significant because of dir search approach in table_insert
    [ DigestDir.new(site_build_dir),
      DigestDir.new(build_dir, exclude: Digest_SHA1.method(:build_exclude)),
      DigestDir.new('public', exclude: Digest_SHA1.method(:public_exclude)) ]
  end

  def self.public_exclude(dir, path)
    ex = [ '3d-party', 'fonts' ]
    ex.any? { |e| path.start_with?("#{dir}/#{e}") }
  end

  def self.build_exclude(dir, path)
    ex = Sites + ['css']
    ex.any? { |e| path.start_with?("#{dir}/#{e}") }
  end
end

module Digest_UUID

  def load(path, id)
    uuid = File.symlink?(path) ? File.basename(File.readlink(path)) : nil
    database[:digest_uuids].insert(path: path, uuid: uuid)
  end

  def dirs
    [ DigestDir.new(site_dir, match: GitIgnore.for('bin-pattern').method(:match)) ]
  end
end


Klasses = [ Teaching, News, Book, BookCategory, Digest_SHA1, Digest_UUID ]

end

module Assets

module News

  def src
    DirFiles.new(site_path("news"), "scss", DirFiles::IN_DIR, name: "style")
  end

  def dst
    DirFiles.new(site_build_path("news"), "css", DirFiles::PLAIN)
  end

  def preprocess(path, input)
    id = path_split(path)[2]
    "#news-#{id} {\n\n#{input}\n}"
  end

  def shorten(path)
    path_from_db(path)
  end

  def compile(path)
    compile_css(self, path)
  end
end

module Public
  def src
    DirFiles.new("assets/css", "scss", DirFiles::PLAIN)
  end

  def dst
    DirFiles.new(".build/css", "css", DirFiles::PLAIN)
  end

  def mixins
    "assets/css/_mixins.scss"
  end

  def shorten(path)
    path
  end

  def compile(path)
    compile_css(self, path)
  end

  # create bundle
  def postupdate
    bundle = ""
    dst.files.each { |p| bundle += File.read(p) }
    File.write('.build/bundle.css', bundle)
  end
end

end

def compile_css(assets, path)
  input = File.read(path)
  input = assets.preprocess(path, input) if assets.respond_to?(:preprocess)
  options = { style: :expanded, load_paths: [ "assets/css"] }
  begin
    res = SassC::Engine.new(input, options).render
    File.write(src_to_dst(assets, path), res)
  rescue SassC::SyntaxError => e
    msg = "Ошибка компиляции файла #{assets.shorten(path)}:\n #{e}"
    database[:errors].insert(path: path, message: msg)
    puts msg
  end
end

def mixin(assets)
  a = clone
  a.extend(assets)
end

def update_assets(assets, u, a, d, mixin_changed)
  if mixin_changed
    r = assets.src.files
    r.delete(assets.mixins)
  else
    r = u + a
  end
  return if r.empty? and d.empty?
  d.each do |p|
    f = src_to_dst(assets, p)
    File.delete(f) if File.exists?(f)
  end
  r.each { |p| assets.compile(p) }
  assets.postupdate if assets.respond_to?(:postupdate)
end

def clean_errors(u, a, d)
  database[:errors].where(path: u + a + d).delete
end

def map_path(path, src, dst)
  id = src.path_to_id(path)
  dst.id_to_path(id)
end

def dst_to_src(assets, path)
  map_path(path, assets.dst, assets.src)
end

def src_to_dst(assets, path)
  map_path(path, assets.src, assets.dst)
end
