#!/bin/ruby

require_relative 'helpers'

include CommonHelpers

def full_path(dir, name)
  "#{dir}/#{name}"
end

def list_dir(dir)
  files = Dir.entries(dir).select do |e|
    not e =~ /^\./ \
      and File.file?(full_path(dir, e)) \
      and e =~ /\.(jpg|gif|pdf|doc|swf)$/
  end
  dirs = Dir.entries(dir).select do |e|
    not e =~ /^\./ and File.directory?(full_path(dir, e))
  end
  files = files.map { |e| full_path(dir, e) }
  dirs = dirs.map { |e| list_dir(full_path(dir, e)) }.flatten
  files + dirs
end

def list_dir_local(dir)
  strip_path(list_dir(dir))
end

def path_steps(path)
  s = path_split(path)
  (1..s.size).to_a.map { |l| s.slice(0, l).join('/') }
end

def path_conversion(path)
  n = path.sub(/^main/, 'edit')
end

def strip_path(files)
  files.map { |p| path_split(p).slice(1..-1).join('/') }
end

def prepend_path(files, prefix)
  files.map { |p| path_add(p, prefix) }
end

def path_add(path, prefix)
  "#{prefix}/#{path}"
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

def sync_init
  files = list_dir_local('main')
  prepare_dirs(prepend_path(files, 'edit'))
  files.each { |p| File.link(path_add(p, 'main'), path_add(p, 'edit')) }
end

def find_update(files)
  files.select do |p|
    e = File.stat(path_add(p, 'edit')).ino
    m = File.stat(path_add(p, 'main')).ino
    m != e
  end
end

def sync_diff
  main = list_dir_local('main')
  edit = list_dir_local('edit')
  add = edit - main
  delete =  main - edit
  update = find_update(main - delete)
  [ update, add, delete ]
end

def sync_update
  update, add, delete = sync_diff

  update.each do |p|
    File.unlink(path_add(p, 'main'))
    File.link(path_add(p, 'edit'), path_add(p, 'main'))
  end

  prepare_dirs(prepend_path(add, 'main'))
  add.each { |p| File.link(path_add(p, 'edit'), path_add(p, 'main')) }

  delete.each { |p| File.unlink(path_add(p, 'main')) }
  cleanup_dirs(prepend_path(delete, 'main'))
end

def print_status(files, prefix)
  files.each { |p| puts "#{prefix} #{p}" }
end

def extract_rename(add, delete)
  map = delete.map { |p| [ File.stat(path_add(p, 'main')).ino, p ] }.to_h
  rename = add.map do |a|
    d = map[File.stat(path_add(a, 'edit')).ino]
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

def sync_status
  update, add, delete = sync_diff
  add, delete, rename = extract_rename(add, delete)
  print_status(update, 'U')
  print_status(add, 'A')
  print_status(delete, 'D')
  rename.each { |r| puts "R #{r[0]} #{r[1]}" }
end

USAGE = <<USAGE
usage: binsync <command>

Commands:
  status    show main and edit diff
  update    copy diff from edit to main
USAGE

def usage
  puts USAGE
  exit
end

usage if ARGV.size < 1
cmd = ARGV.shift
case cmd
  when 'status'
    sync_status
  when 'update'
    sync_update
  else
    usage
end
