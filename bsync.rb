#!/bin/ruby

require_relative 'utils'
require_relative 'helpers'
require 'digest'
require 'set'
require 'open3'
require 'securerandom'

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

def read_config(path)
  return {} if not File.exists?(path)
  out, err, code = Open3.capture3("git config --file=#{path} --get-regexp '.*'")
  if not code.success?
    puts err
    exit
  end
  out.split("\n").collect { |l| l.split(' ') }.to_h
end

def init
  Dir.mkdir(BSYNC_DIR) if not Dir.exist?(BSYNC_DIR)
  Dir.mkdir(OBJECTS) if not Dir.exist?(OBJECTS)
  if not File.exists?(UUIDFILE)
    File.write(UUIDFILE, SecureRandom.uuid)
    File.chmod(File.stat(UUIDFILE).mode & 0555, UUIDFILE)
  end
end

def path(p)
  File.join(BSYNC_DIR, p)
end

GIT_DIR = ENV['GIT_DIR'] || '.git'
BSYNC_DIR = ENV['BSYNC_DIR'] || '.bsync'

OBJECTS = path('objects')
COMMITED = path('commited')
UUIDFILE = path('uuid')
SNAPSHOTS = path('snapshots')
IGNOREFILE = File.join(GIT_DIR, '/info/exclude')

CONFIG = read_config(path('config'))

usage if ARGV.size < 1
if ARGV[0] == 'init'
    init
    exit
end

if not File.exist?(OBJECTS) or not File.directory?(OBJECTS)
  puts "current directory is not bsync repository"
  exit 1
end

UUID = File.read(UUIDFILE)

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
  u, a, d = diff(read_hashes, list_work)
  print_status(u, 'U')
  print_status(a, 'A')
  print_status(d, 'D')
end

def force_link(src, dst)
  t = path('object.tmp')
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

def dir_empty(path)
  (Dir.entries(path) - [ '.', '..' ]).empty?
end

def cleanup_dirs(files)
  dirs_trace(files).reverse.each do |d|
    Dir.unlink(d) if Dir.exist?(d) and dir_empty(d)
  end
end

def reset
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

  prepare_dirs(delete)

  delete.each { |p| File.link(db_object(hashes, p), p) }
  update.each { |p| force_link(db_object(hashes, p), p) }
  add.each { |p| File.unlink(p) }

  cleanup_dirs(add)
end

def snapshot
  usage if ARGV.empty?
  peer = ARGV.shift
  Dir.mkdir(SNAPSHOTS) if not File.exist?(SNAPSHOTS)
  s = File.read(COMMITED)
  File.write(File.join(SNAPSHOTS, peer), s)
end

cmd = ARGV.shift
case cmd
  when 'status'
    status
  when 'commit'
    commit
  when 'reset'
    reset
# these are internal commands
  when 'snapshot'
    snapshot
  else
    usage
end
