#!/bin/ruby

require_relative 'helpers'
require_relative 'utils'

include CommonHelpers

def path_steps(path)
  s = path_split(path)
  (1..s.size).to_a.map { |l| s.slice(0, l).join('/') }
end

def prepend_path(files, site)
  files.map { |p| site.path(p) }
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

def dir_empty(path)
  (Dir.entries(path) - [ '.', '..' ]).empty?
end

def cleanup_dirs(files)
  dirs_trace(files).reverse.each do |d|
    Dir.unlink(d) if Dir.exist?(d) and dir_empty(d)
  end
end

def sync_diff
  d = dst.list
  s = src.list
  add = s - d
  delete =  d - s
  update = (d - delete).select { |p| src.inode(p) != dst.inode(p) }
  [ update, add, delete ]
end

def copy
  update, add, delete = sync_diff

  update.each do |p|
    File.unlink(dst.path(p))
    File.link(src.path(p), dst.path(p))
  end

  prepare_dirs(prepend_path(add, dst))
  add.each { |p| File.link(src.path(p), dst.path(p)) }

  delete.each { |p| File.unlink(dst.path(p)) }
  cleanup_dirs(prepend_path(delete, dst))
end

def print_status(files, prefix)
  files.each { |p| puts "#{prefix} #{p}" }
end

def extract_rename(add, delete)
  map = delete.map { |p| [ dst.inode(p), p ] }.to_h
  rename = add.map do |a|
    d = map[src.inode(a)]
    d ? [d, a] : nil
  end
  rename = rename.compact
  if rename.empty?
    dd = da = []
  else
    dd, da = rename.transpose
  end
  add = add - da
  delete = delete - dd
  [ add, delete, rename ]
end

def status
  update, add, delete = sync_diff
  add, delete, rename = extract_rename(add, delete)
  print_status(update, 'U')
  print_status(add, 'A')
  print_status(delete, 'D')
  rename.each { |r| puts "R #{r[0]} #{r[1]}" }
end

CONFLICT = <<END
Peer repo has changes. Either reset them or merge changes into
source repo manually.
END

def check
  update, add, delete = sync_diff
  if not (update.empty? and add.empty? and delete.empty?)
    puts CONFLICT
    exit
  end
end

USAGE = <<USAGE
usage: binsync <command>

Commands:

  status    show repo difference
  pull      copy diff from edit to main
  push      copy diff from main to edit

Per command syntax:

  status <repo>
    show difference between given and base repo
USAGE

def usage
  puts USAGE
  exit
end

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
    l = l.select { |p| BinaryFile.match(p) }
    # remove first dir in path sequence
    l.map { |p| path_split(p).slice(1..-1).join('/') }
  end
end

class Direction
  attr_reader :src, :dst

  def initialize(src, dst)
    @src = src
    @dst = dst
  end

  def reverse
    Direction.new(dst, src)
  end
end

Edit = Site.new('edit')
Main = Site.new('main')
Base = Site.new('.binbase')

def parse_repo
  usage if ARGV.size < 1
  repo = ARGV.shift
  usage if repo != Main.dir and repo != Edit.dir
  repo
end

def sync_copy(src, dst)
  Direction.new(src, dst).instance_eval { copy }
end

def sync_check(src, dst)
  Direction.new(src, dst).instance_eval { check }
end

def sync_status(src, dst)
  Direction.new(src, dst).instance_eval { status }
end

usage if ARGV.size < 1
cmd = ARGV.shift
case cmd
  when 'status'
    sync_status(Site.new(parse_repo), Base)
  when 'reset'
    sync_copy(Base, Site.new(parse_repo))
  when 'pull'
    sync_check(Main, Base)
    sync_copy(Edit, Main)
    sync_copy(Edit, Base)
  when 'push'
    sync_check(Edit, Base)
    sync_copy(Main, Edit)
    sync_copy(Main, Base)
  else
    usage
end
