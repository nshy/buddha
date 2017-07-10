#!/bin/ruby

require_relative 'utils'
require_relative 'helpers'

include CommonHelpers

USAGE = <<USAGE
usage: bsync <command>

Commands:
  init      init repository
  status    print repository status
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
  a = w - b
  d =  b - w
  u = (b - d).select { |p| BASE.inode(p) != WORK.inode(p) }
  [ u, a, d ]
end

def extract_rename(add, delete)
  map = delete.map { |p| [ BASE.inode(p), p ] }.to_h
  rename = add.map do |a|
    d = map[WORK.inode(a)]
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

def print_status(files, prefix)
  files.each { |p| puts "#{prefix} #{p}" }
end

def status
  check_initialized
  u, a, d = sync_diff
  a, d, r = extract_rename(a, d)
  print_status(u, 'U')
  print_status(a, 'A')
  print_status(d, 'D')
  r.each { |i| puts "R #{i[0]} -> #{i[1]}" }
end

usage if ARGV.size < 1
cmd = ARGV.shift
case cmd
  when 'init'
    init
  when 'status'
    status
  else
    usage
end
