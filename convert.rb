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

def table_insert(resource, p)
  table = database[resource.table]
  # search dir
  dir = resource.dirs.find { |d| p.start_with?(d.dir) }
  id = dir.path_to_id(p)
  begin
    check_url_nice(p, [:digest_sha1s, :digest_uuids].include?(resource.table))
    resource.load(p, id)
  rescue ModelException => e
    puts e
    database[:errors].insert(path: p, message: e.to_s)
  end
  table.where(path: p).
    update(id: id, mtime: File.lstat(p).mtime)
end

def table_update(resource, u, a, d)
  # on move "added" can be generated for existing files
  database[resource.table].where(path: u + a + d).delete
  (a + u).each { |p| table_insert(resource, p) }
end

def data_dir(dir, ext)
  [ DirFiles.new(site_path(dir), ext, DirFiles::BOTH, name: "page") ]
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

def compile_css(assets, path)
  input = File.read(path)
  input = assets.preprocess(path, input) if assets.respond_to?(:preprocess)
  options = { style: :expanded, load_paths: [ "assets/css"] }
  begin
    res = SassC::Engine.new(input, options).render
    File.write(src_to_dst(assets, path), res)
  rescue SassC::SyntaxError => e
    msg = "Ошибка компиляции файла #{assets.shorten(path)}:\n #{e}"
    if respond_to?(:database)
      database[:errors].insert(path: path, message: msg)
    else
      Sites.each do |s|
        Site.for(s).instance_eval do
          database[:errors].insert(path: path, message: msg)
        end
      end
    end
    puts msg
  end
end

def mixin(mod)
  o = clone
  o.extend(mod)
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

def sync_lock
  f = File.open('.sync.lock', File::RDWR | File::CREAT, 0644)
  if f.flock(File::LOCK_NB | File::LOCK_EX) == false
    puts "Can not get sync lock"
    exit 1
  end
  @sync_lock = f
end

def sync(method, reset)
  # We can not clean errors in update functions based on (u, a, d) triplet.
  # Because we can not detect deleted file in case of error as there
  # is no product object.
  #
  # We also need to clean errors before compiling public assets
  if reset
    Sites.each do |s|
      Site.for(s).instance_eval do
        database[:errors].delete
      end
    end
  end
  mixin(method).handle_assets(mixin(Assets::Public))
  Dir.mkdir(".build") if not File.exists?(".build")
  Sites.each do |s|
    Site.for(s).instance_eval do
      Dir.mkdir(site_build_dir) if not File.exists?(site_build_dir)
      m = mixin(method)
      Assets::All.each { |a| m.handle_assets(mixin(a)) }
      Resources::All.each do |r|
        ro = mixin(r)
        ro.define_singleton_method(:table) do
          r.to_s.demodulize.tableize.to_sym
        end
        m.handle_resource(ro)
      end
    end
  end
end
