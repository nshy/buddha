#!/bin/ruby

require_relative 'utils'
require_relative 'helpers'

include CommonHelpers

USAGE = <<USAGE
usage: bsync <command>

Commands:
  init      init repository
  status    print repository status
  commit    commit workset changes
USAGE

def usage
  puts USAGE
  exit 1
end

COMMITED = ".bsync/commited"
IGNORE = GitIgnore.for('.git/info/exclude')

class Site
  attr_reader :dir

  def initialize(dir)
    @dir = dir
  end

  def path(p)
    File.join(@dir, p)
  end

  def inode(p)
    File.stat(path(p)).ino
  end

  def list
    l = Utils.list_recursively(@dir)
    l = l.select { |p| IGNORE.match(p) }
    # remove first dir in path sequence
    sz = path_split(@dir).size
    l.map { |p| path_split(p).slice(sz..-1).join('/') }
  end
end

BASE = Site.new(COMMITED)
WORK = Site.new('.')

def init
  Dir.mkdir(".bsync")
  Dir.mkdir(COMMITED)
end

def check_initialized
  return if File.exist?(COMMITED) and File.directory?(COMMITED)
  puts "current directory is not bsync repository"
  exit 1
end

def sync_diff
  b = BASE.list
  w = WORK.list
  w, b, r = extract_rename(w, b)
  a = w - b
  d =  b - w
  u = (b - d).select { |p| BASE.inode(p) != WORK.inode(p) }
  [ r, u, a, d ]
end

def extract_rename(work, base)
  map = base.map { |p| [ BASE.inode(p), p ] }.to_h
  rename = work.map do |w|
    b = map[WORK.inode(w)]
    b and b != w ? [b, w] : nil
  end
  rename = rename.compact
  if rename.empty?
    dw = db = []
  else
    db, dw = rename.transpose
  end
  [ work - dw, base - db, rename ]
end

def print_status(files, prefix)
  files.each { |p| puts "#{prefix} #{p}" }
end

def status
  check_initialized
  r, u, a, d = sync_diff
  print_status(u, 'U')
  print_status(a, 'A')
  print_status(d, 'D')
  r.each { |i| puts "R #{i[0]} -> #{i[1]}" }
end

def path_steps(path)
  s = path_split(path)
  (1..s.size).to_a.map { |l| s.slice(0, l).join('/') }
end

def dirs_trace(files)
  dirs = files.map { |p| File.dirname(p) }.uniq
  # make sure we have all parent dirs too
  dirs = dirs.map { |p| path_steps(p) }.flatten.uniq.sort
end

def prepare_dirs(files)
  dirs_trace(files).each do |d|
    Dir.mkdir(d) if not File.exists?(d)
  end
end

def prepend_path(files, site)
  files.map { |p| site.path(p) }
end

def dir_empty(path)
  (Dir.entries(path) - [ '.', '..' ]).empty?
end

def cleanup_dirs(files)
  dirs_trace(files).reverse.each do |d|
    Dir.unlink(d) if Dir.exist?(d) and dir_empty(d)
  end
end

def commit
  check_initialized
  rename, update, add, delete = sync_diff

  update.each do |p|
    File.unlink(BASE.path(p))
    File.link(WORK.path(p), BASE.path(p))
  end

  prepare_dirs(prepend_path(add, BASE))
  add.each do |p|
    w = WORK.path(p)
    File.chmod(File.stat(w).mode & 0555, w)
    File.link(w, BASE.path(p))
  end

  delete.each { |p| File.unlink(BASE.path(p)) }
  cleanup_dirs(prepend_path(delete, BASE))
end

usage if ARGV.size < 1
cmd = ARGV.shift
case cmd
  when 'init'
    init
  when 'status'
    status
  when 'commit'
    commit
  else
    usage
end
