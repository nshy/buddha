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
    File.basename(name, '.*')
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
    [ DirFiles.new(site_path("teachings"), "xml") ]
  end
end

# --------------------- news --------------------------

module News
  def load(path, id)
    news = NewsDocument.new(path)
    insert_object(database[:news], news, path: path)
  end

  def dirs
    [ DirFiles.new(site_path("news"), "html") ]
  end
end

# --------------------- books --------------------------

module Book
  def load(path, id)
    book = ::Book::Document.load(path)
    insert_object(database[:books], book, path: path)
  end

  def dirs
    [ DirFiles.new(site_path("books"), "xml") ]
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
    [ DirFiles.new(site_path("book-categories"), "xml") ]
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
  def dst(path)
    id = path_split(path)[2]
    site_build_path("news/#{id}.css")
  end

  def dst_files
    dir_files(site_build_path("news"))
  end

  def src(path)
    id = File.basename(path, '.*')
    site_path("news/#{id}/style.scss")
  end

  def src_files
    files = dir_files(site_path("news")).collect do |e|
      f = "#{e}/style.scss"
      File.exist?(f) ? f : nil
    end
    files.compact
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
  Mixins = "assets/css/_mixins.scss"
  Bundle = '.build/bundle.css'
  SrcDir = 'assets/css'

  def dst(path)
    id = File.basename(path, '.*')
    ".build/css/#{id}.css"
  end

  def dst_files
    dir_files('.build/css')
  end

  def src(path)
    id = File.basename(path, '.*')
    "assets/css/#{id}.scss"
  end

  def src_files
    files = dir_files('assets/css')
    files.delete(Mixins)
    files
  end

  def shorten(path)
    path
  end
end

end

def compile(assets, path)
  input = File.read(path)
  input = assets.preprocess(path, input) if assets.respond_to?(:preprocess)
  options = { style: :expanded, load_paths: [ Assets::Public::SrcDir ] }
  begin
    res = SassC::Engine.new(input, options).render
    File.write(assets.dst(path), res)
  rescue SassC::SyntaxError => e
    msg = "Ошибка компиляции файла #{assets.shorten(path)}:\n #{e}"
    database[:errors].insert(path: path, message: msg)
    puts msg
  end
end

def concat
  bundle = ""
  mixin(Assets::Public).dst_files.each { |p| bundle += File.read(p) }
  File.write(Assets::Public::Bundle, bundle)
end

def mixin(assets)
  a = clone
  a.extend(assets)
end

def update_assets(updated, deleted, assets)
  a = mixin(assets)
  deleted.each do |p|
    css = a.dst(p)
    File.delete(css) if File.exists?(css)
  end
  updated.each { |p| compile(a, p) }
end

def update_assets_main(u, a, d, mixin_changed)
  c = mixin_changed ? mixin(Assets::Public).src_files : u + a
  return if c.empty? and d.empty?
  update_assets(c, d, Assets::Public)
  concat
end

def clean_errors(u, a, d)
  database[:errors].where(path: u + a + d).delete
end
