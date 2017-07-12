#!/bin/ruby

require_relative 'utils'
require_relative 'helpers'
require 'digest'
require 'set'

include CommonHelpers

USAGE = <<USAGE
usage: bsync <command>

Commands:
  init      init repository
  status    print repository status
  commit    commit workset changes
  reset     reset work dir to last commited state

reset options:
  -f, --force     drop new content in working dir
USAGE

def usage
  puts USAGE
  exit 1
end

OBJECTS = ".bsync2/objects"
COMMITED = ".bsync2/commited"
IGNORE = GitIgnore.for('.git/info/exclude')

def init
  Dir.mkdir(".bsync2") if not Dir.exist?(".bsync2")
  Dir.mkdir(OBJECTS) if not Dir.exist?(OBJECTS)
end

def check_initialized
  return if File.exist?(OBJECTS) and File.directory?(OBJECTS)
  puts "current directory is not bsync repository"
  exit 1
end

def list_work
  l = Dir[File.join('**', '*')]
  l = l.select { |p| /\.mp3$/ =~ p }
end

def write_hashes(hashes)
  s = hashes.to_a.collect { |i| i.reverse.join(' ') }.join("\n")
  tmp = "#{COMMITED}.tmp"
  File.write(tmp, s)
  File.rename(tmp, COMMITED)
end

def read_hashes
  l = File.read(COMMITED).split("\n")
  l.collect { |l| l.split(' ').reverse }.to_h
end

def diff(hashes, work)
  w = work
  b = hashes.keys
  a = w - b
  d = b - w
  u = (b - d).select do |p|
    o = File.join(OBJECTS, hashes[p])
    File.stat(p).ino != File.stat(o).ino
  end
  [u, a, d]
end

def print_status(files, prefix)
  files.each { |p| puts "#{prefix} #{p}" }
end

def status
  check_initialized

  u, a, d = diff(read_hashes, list_work)
  print_status(u, 'U')
  print_status(a, 'A')
  print_status(d, 'D')
end

def add_object(hashes, p)
  puts "Hashing #{p}"
  File.chmod(File.stat(p).mode & 0555, p)
  h = Digest::SHA1.file(p).hexdigest
  o = File.join(OBJECTS, h)
  if File.exist?(o)
    if File.stat(o).ino != File.stat(p).ino
      t = '.bsync2/object.tmp'
      File.unlink(t) if File.exist?(t)
      File.link(o, t)
      File.rename(t, p)
    end
  else
    File.link(p, o)
  end
  hashes[p] = h
end

def prune(hashes)
  objs = Dir[File.join(OBJECTS, '*')]
  db = objs.collect { |p| File.basename(p) }
  orphans = db - hashes.values
  orphans.each { |p| File.unlink(File.join(OBJECTS, p)) }
end

def commit
  check_initialized

  hashes = read_hashes
  u, a, d = diff(hashes, list_work)
  d.each { |p| hashes.delete(p) }
  (a + u).each { |p| add_object(hashes, p) }

  write_hashes(hashes)
  prune(hashes)
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
