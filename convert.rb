require_relative 'models'
require_relative 'helpers'
require 'sequel'
require 'preamble'
require 'pathname'
require 'digest'
require 'sassc'
require 'active_support/core_ext/string/inflections'

include CommonHelpers

module Sync

def self.print_modification(prefix, set)
  set.each { |p| puts "#{prefix} #{p}" }
end

def self.update_table(db, klass, updated, added, deleted)
  print_modification('b D', deleted)
  print_modification('b A', added)
  print_modification('b U', updated)

  table = db[klass.table]
  ids = (deleted + updated).map { |p| klass.path_to_id(p) }
  table.where(id: ids).delete
  (added + updated).each do |p|
    klass.load(db, p)
    table.where(id: klass.path_to_id(p)).
      update(path: p, last_modified: File.mtime(p))
  end
end

module Document
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

class Teaching
  extend Document

  def self.load(db, path)
    teachings = TeachingsDocument.load(path)

    id = path_to_id(path)
    insert_object(db[:teachings], teachings, id: id)
    teachings.theme.each do |theme|
      theme_id = insert_object(db[:themes], theme, teaching_id: id)
      theme.record.each do |record|
        insert_object(db[:records], record, theme_id: theme_id)
      end
    end
  end

  def self.dirs(dir)
    [ DirFiles.new("#{dir}/teachings") ]
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

class News
  extend Document

  def self.load(db, path)
    news = NewsDocument.new(path)
    insert_object(db[:news], news, id: path_to_id(path))
  end

  def self.dirs(dir)
    [ NewsDir.new(dir) ]
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

class Book
  extend Document

  def self.load(db, path)
    book = BookDocument.load(path)
    insert_object(db[:books], book, { id: path_to_id(path) })
  end

  def self.dirs(dir)
    [ BookDir.new(dir) ]
  end
end

class BookCategory
  extend Document

  def self.load(db, path)
    category = BookCategoryDocument.load(path)

    id = path_to_id(path)
    insert_object(db[:book_categories], category, id: id)
    category.group.each do |group|
      group.book.each do |book|
        db[:category_books].
          insert(group: group.name,
                 book_id: book,
                 category_id: id)
      end
    end

    category.subcategory.each do |subcategory|
      db[:category_subcategories].
        insert(category_id: id,
               subcategory_id: subcategory)
    end
  end

  def self.dirs(dir)
    [ DirFiles.new("#{dir}/book-categories") ]
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
  extend Document

  def self.path_to_id(path)
    a = path_split(path)
    a[0] = nil
    a.join('/')
  end

  def self.load(db, path)
    db[:digests].insert(id: path_to_id(path),
                        digest: ::Digest::SHA1.file(path).hexdigest)
  end

  def self.dirs(dir)
    [ DigestDir.new(dir, match: /\.(jpg|gif|swf|css|doc|pdf)$/),
      DigestDir.new('public',
        match: /\.(mp3|css|js|ico|png|svg|jpg)$/,
        excludes: [ '3d-party', 'logs', 'css', 'fonts' ] ) ]
  end
end

Klasses = [ Teaching, News, Book, BookCategory, Digest ]

def self.compile(spath, dpath)
  src = File.read(spath)
  options = { style: :expanded, load_paths: [ 'assets/css/' ] }
  dst = SassC::Engine.new(src, options).render
  File.write(dpath, dst)
end


StyleSrc = 'assets/css'
StyleDst = 'public/css'
Bundle = 'public/bundle.css'
Mixins = "#{StyleSrc}/_mixins.scss"

def self.each_style(sel, &block)
  opts = { scss: { dir: StyleSrc, ext: 'scss' },
           css: { dir: StyleDst, ext: 'css' } }[sel]
  dir = opts[:dir]
  ext = opts[:ext]
  Dir.entries(dir).each do |e|
    next if sel == :scss and e == '_mixins.scss'
    next if not /\.#{ext}$/ =~ e
    n = e.gsub(/\.#{ext}$/, '')
    yield "#{StyleSrc}/#{n}.scss", "#{StyleDst}/#{n}.css"
  end
end

def self.concat
  bundle = ""
  each_style(:css) { |s, d| bundle += File.read(d) }
  File.write(Bundle, bundle)
end

def self.dest_news(path)
  path.gsub(/\.scss$/, '.css')
end

def self.dest_man(path)
  path.gsub(/\.scss$/, '.css').gsub(/^assets/, 'public')
end

def self.sync_all
  puts "a U #{Mixins}"
  each_style(:scss) { |s, d| compile(s, d) }
end

end
