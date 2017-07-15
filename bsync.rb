#!/bin/ruby

require_relative 'utils'
require_relative 'helpers'
require 'digest'
require 'set'
require 'open3'
require 'securerandom'
require 'uri'

include CommonHelpers

USAGE = <<USAGE
usage: bsync <command>

Commands:
  init      init repository
  status    print repository status
  commit    commit workset changes
  reset     reset work dir to last commited state
  sync      sync with given remote

reset options:
  -f, --force     drop new content in working dir

sync <remote>
USAGE

def fatal(msg)
  puts msg
  exit 1
end

def usage
  fatal USAGE
end

def read_config(path)
  return {} if not File.exists?(path)
  out, err, code = Open3.capture3("git config --file=#{path} --get-regexp '.*'")
  if not code.success?
    fatal err
  end
  out.split("\n").collect { |l| l.split(' ') }.to_h
end

def save(path, data, options = {})
  default = { readonly: false }
  options = default.merge(options)

  File.write(TMPFILE, data)
  File.chmod(File.stat(TMPFILE).mode & 0555, TMPFILE) if options[:readonly]
  File.rename(TMPFILE, path)
end

def init
  Dir.mkdir(BSYNC_DIR) if not Dir.exist?(BSYNC_DIR)
  Dir.mkdir(OBJECTS) if not Dir.exist?(OBJECTS)
  save(UUIDFILE, SecureRandom.uuid, readonly: true) if not File.exists?(UUIDFILE)
end

def path(p)
  File.join(BSYNC_DIR, p)
end

BSYNC_DIR_DEFAULT = '.bsync'
GIT_DIR = ENV['GIT_DIR'] || '.git'
BSYNC_DIR = ENV['BSYNC_DIR'] || BSYNC_DIR_DEFAULT

OBJECTS = path('objects')
COMMITED = path('commited')
UUIDFILE = path('uuid')
SNAPSHOTS = path('snapshots')
REMOTES = path('remotes')
CONFLICTS = path('conflicts')
MERGEREMOTE = path('mergeremote')
IGNOREFILE = File.join(GIT_DIR, '/info/exclude')
TMPFILE = path('.tmp')
THEIR = path('their')

CONFIG = read_config(path('config'))

usage if ARGV.size < 1
if ARGV[0] == 'init'
    init
    exit
end

if not File.exist?(OBJECTS) or not File.directory?(OBJECTS)
  fatal "Not a bsync repository, bsync dir is '#{BSYNC_DIR}'"
end

UUID = File.read(UUIDFILE)
LOCK = File.open(BSYNC_DIR)
LOCK.flock(File::LOCK_EX)

def list_work
  l = Dir[File.join('**', '*')]
  l = l.select { |p| /\.mp3$/ =~ p }
end

def write_hashes(hashes)
  s = hashes.to_a.collect { |i| i.reverse.join(' ') }.join("\n")
  save(COMMITED, s)
end

def read_hashes(path)
  return {} if not File.exist?(path)
  l = File.read(path).split("\n")
  l.collect { |l| l.split(' ').reverse }.to_h
end

def commited
  read_hashes(COMMITED)
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

def print_diff(diff)
  [ 'U', 'A', 'D' ].zip(diff).each do |i|
    i[1].each { |p| puts "#{i[0]} #{p}" }
  end
end

def status
  print_diff(diff(commited, list_work))
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

def prune
  objs = Dir[File.join(OBJECTS, '*')]
  db = objs.collect { |p| File.basename(p) }

  lists = Dir[File.join(SNAPSHOTS, '*')] + [ COMMITED ]
  used = lists.collect { |l| read_hashes(l).values }.reduce([], :|)

  (db - used).each { |h| File.unlink(File.join(OBJECTS, h)) }
end

def inodes
  objs = Dir[File.join(OBJECTS, '*')]
  inodes = objs.collect { |p| [ File.stat(p).ino, File.basename(p) ] }.to_h
end

def commit_work
  hashes = commited

  u, a, d = diff(hashes, list_work)
  i = inodes

  d.each { |p| hashes.delete(p) }
  (a + u).each { |p| hashes[p] = add_path(i, p) }

  write_hashes(hashes)
end

def bad_patch(l, msg)
  fatal "Error in #{CONFLICTS}:#{l} : #{msg}."
end

def read_patch
  c = conflicts(MERGEREMOTE)
  cm, ct, cc = c.collect { |l| Set.new(l) }

  u = Set.new; a = Set.new; k = Set.new;
  i = 0
  lines = File.read(CONFLICTS).split("\n")
  lines.each do |l|
    i += 1
    next if l.start_with?('#')
    next if l.strip.empty?
    if l[1] != ' '
      bad_patch i, "second symbol must be space"
    end
    p = l.slice(1..-1).strip
    case l[0]
      when " "
        if cc.include?(p)
          bad_patch i, "path present on both sides, use either 't' or 'm'"
        end
        if ct.include?(p)
          a << p
        elsif cm.include?(p)
          k << p
        else
          bad_patch i, "path '#{p}' don't need to be resolved"
        end

      when "t"
        if not cc.include?(p)
          bad_patch i, "'t' mark has only meaining in conflicts"
        end
        u << p
        k << p

      when "m"
        if not cc.include?(p)
          bad_patch i, "'m' mark has only meaining in conflicts"
        end
        k << p

      when "C", "<", ">"
        bad_patch i, "unresolved conflict"

      else
        bad_patch i, "unexpected first letter"
    end
  end
  d = (cm - k) + (cc - k)

  [ u, a, d ].collect { |l| l.to_a }
end

def invert_patch(p)
  u, a, d = p
  [ u, d, a ]
end

def commit_merge
  u, a, d = patch = read_patch
  puts "Applying #{CONFLICTS}"
  print_diff(patch)
  hashes = commited
  remote = read_hashes(MERGEREMOTE)

  d.each { |p| hashes.delete(p) }
  (a + u).each do |p|
    h = remote[p]
    hashes[p] = h
    r = File.join(THEIR, p)
    o = File.join(OBJECTS, h)
    File.rename(r, o) if File.exist?(r) and not File.exist?(o)
  end

  Dir[File.join(THEIR, '*')].each { |p| File.unlink(p) }
  Dir.rmdir(THEIR)

  File.unlink(MERGEREMOTE)
  File.unlink(CONFLICTS)
  write_hashes(hashes)
  apply(hashes, invert_patch(patch))
end

def commit
  if File.exist?(CONFLICTS)
    commit_merge
  else
    commit_work
  end
  prune
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

def apply(hashes, patch)
  u, a, d = patch
  prepare_dirs(d)

  d.each { |p| File.link(db_object(hashes, p), p) }
  u.each { |p| force_link(db_object(hashes, p), p) }
  a.each { |p| File.unlink(p) }

  cleanup_dirs(a)
end

def reset
  force = false
  while not ARGV.empty?
    case ARGV.shift
      when '-f', '--force' then force = true
      else usage
    end
  end

  hashes = commited
  u, a, d = patch = diff(hashes, list_work)

  if (not a.empty? or not u.empty?) and not force
    fatal 'Work dir has new content, to force reset use --force flag'
  end

  apply(hashes, patch)
end

def copy(src, dst)
  s = File.read(src)
  save(dst, s)
end

def snapshot
  usage if ARGV.empty?
  peer = ARGV.shift
  Dir.mkdir(SNAPSHOTS) if not File.exist?(SNAPSHOTS)
  s = File.join(SNAPSHOTS, peer)
  copy(COMMITED, s) if not File.exist?(s)
end

def delete_snapshot
  usage if ARGV.empty?
  peer = ARGV.shift
  s = File.join(SNAPSHOTS, peer)
  File.unlink(s) if File.exist?(s)
  Dir.rmdir(SNAPSHOTS) if dir_empty(SNAPSHOTS)
  prune
end

def check_clean
  u, a, d = diff(commited, list_work)
  return if u.empty? and a.empty? and d.empty?
  fatal "Working dir has changes. Reset them or commit before sync."
end

SYNC_NOTICE = "\
Local and remotes trees are not identical. You need to choose what result \
tree would look like. Edit #{(CONFLICTS)} file to make your choice. \
Instructions are inside this file."

CONFLICTS_HEADER = <<END
# Legenda:
#  < - their (file is present in remote and not present locally)
#  > - mine  (reverse of above)
#  C - conflict (present on both sides and differ)
#
# Edit:
#  Deleted line to delete file from result. Replace < or > with just space
#  to include file into result. Replace C with 't' or 'm' to choose on of
#  the version.
#
# Data:
#  Their versions of files are available at ./their directory.
END

def conflicts(their)
  m = commited
  t = read_hashes(their)

  cm = m.keys - t.keys
  ct = t.keys - m.keys
  cc = (t.keys & m.keys).select { |p| m[p] != t[p] }
  [ cm, ct, cc ]
end

def write_conflicts(c)
  m, t, c = c
  dm = m.collect { |p| "> #{p}" }
  dt = t.collect { |p| "< #{p}" }
  dc = c.collect { |p| "C #{p}" }
  ds = (dm + dt + dc).join("\n")
  s = [CONFLICTS_HEADER, ds].join("\n")
  save(CONFLICTS, s)
  puts SYNC_NOTICE
end

def copy_theirs(url, c)
  cm, ct, cc = c
  Dir.mkdir(THEIR) if not File.exist?(THEIR)
  (ct + cc).each do |p|
    t = File.join(THEIR, p)
    File.link(File.join(url, p), t) if not File.exist?(t)
  end
end

def remote_bsync(url, cmd)
  env = { 'BSYNC_DIR' => nil }
  out, code = Open3.capture2(env, "bsync.rb #{cmd}", chdir: url)
  if not code.success?
    fatal "Error executing command '#{cmd}' for remote '#{url}': #{out}"
  end
end

def sync
  usage if ARGV.empty?
  remote = ARGV.shift
  url = CONFIG["remote.#{remote}.url"]
  check_clean
  if not url
    fatal "Unknown remote '#{remote}'. Check your config."
  end
  if URI(url).absolute?
    fatal "Inter host sync is not supported yet."
  end
  if not File.directory?(url)
    fatal "Remote url '#{url}' does not point to directory."
  end
  r = File.join(REMOTES, remote)
  rt = ".#{remote}.tmp"
  if File.exist?(r)
    if File.exist?(CONFLICTS)
      puts "Sync is already done, but there are conflicts. " \
           "Resolve them in #{CONFLICTS} file and then commit."
    else
      puts "Sync is already done."
    end
    exit
  end
  if File.symlink?(MERGEREMOTE)
    curremote = File.basename(File.readlink(MERGEREMOTE))
    if curremote != remote
      fatal "There is unfinished sync for remote '#{curremote}'. " \
            "Finish that sync first."
    end
  else
    File.symlink(r, MERGEREMOTE)
  end
  remote_bsync(url, "snapshot #{UUID}")
  Dir.mkdir(REMOTES) if not File.exist?(REMOTES)
  copy(File.join(url, BSYNC_DIR_DEFAULT, 'snapshots', UUID), rt)
  c = conflicts(rt)
  copy_theirs(url, c)
  write_conflicts(c)
  remote_bsync(url, "snapshot-delete #{UUID}")
  File.rename(rt, r)
end

cmd = ARGV.shift
case cmd
  when 'status'
    status
  when 'commit'
    commit
  when 'reset'
    reset
  when 'sync'
    sync
# these are internal commands
  when 'snapshot'
    snapshot
  when 'snapshot-delete'
    delete_snapshot
  else
    usage
end
