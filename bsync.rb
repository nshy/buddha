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

OBJECTS = ".bsync/objects"
COMMITED = ".bsync/commited"
IGNORE = GitIgnore.for('.git/info/exclude')

def init
  Dir.mkdir(".bsync") if not Dir.exist?(".bsync")
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
  return {} if not File.exist?(COMMITED)
  l = File.read(COMMITED).split("\n")
  l.collect { |l| l.split(' ').reverse }.to_h
end

def db_object(hashes, p)
  File.join(OBJECTS, hashes[p])
end

def diff(hashes, work)
  w = work
  b = hashes.keys
  a = w - b
  d = b - w
  u = (b - d).select do |p|
    File.stat(p).ino != File.stat(db_object(hashes, p)).ino
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

def force_link(src, dst)
  t = '.bsync/object.tmp'
  File.unlink(t) if File.exist?(t)
  File.link(src, t)
  File.rename(t, dst)
end

def add_object(p)
  puts "Hashing #{p}"
  File.chmod(File.stat(p).mode & 0555, p)
  h = Digest::SHA1.file(p).hexdigest
  o = File.join(OBJECTS, h)
  if not File.exist?(o)
    File.link(p, o)
  elsif File.stat(o).ino != File.stat(p).ino
    force_link(o, p)
  end
  h
end

def add_path(inodes, p)
  inodes[File.stat(p).ino] || add_object(p)
end

def prune(hashes)
  objs = Dir[File.join(OBJECTS, '*')]
  db = objs.collect { |p| File.basename(p) }
  orphans = db - hashes.values
  orphans.each { |h| File.unlink(File.join(OBJECTS, h)) }
end

def commit
  check_initialized

  hashes = read_hashes
  objs = Dir[File.join(OBJECTS, '*')]
  inodes = objs.collect { |p| [ File.stat(p).ino, File.basename(p) ] }.to_h

  u, a, d = diff(hashes, list_work)
  d.each { |p| hashes.delete(p) }
  (a + u).each { |p| hashes[p] = add_path(inodes, p) }

  write_hashes(hashes)
  prune(hashes)
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

def reset
  check_initialized

  force = false
  while not ARGV.empty?
    case ARGV.shift
      when '-f', '--force' then force = true
      else usage
    end
  end

  hashes = read_hashes
  update, add, delete = diff(hashes, list_work)

  if (not add.empty? or not update.empty?) and not force
    puts 'Work dir has new content, to force reset use --force flag'
    exit 1
  end

  prepare_dirs(hashes.keys)

  delete.each { |p| File.link(db_object(hashes, p), p) }
  update.each { |p| force_link(db_object(hashes, p), p) }
  add.each { |p| File.unlink(p) }
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
  when 'reset'
    reset
  else
    usage
end
