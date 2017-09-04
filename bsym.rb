#!/bin/ruby

require_relative 'utils'
require 'securerandom'
require 'fileutils'

USAGE = <<USAGE
usage: bsym <command>

Commands:
  status    print not yet symlinked files
  convert   convert binary files to symlinks
  revert    turn symlinks back to files
  prune     prune stale objects

USAGE

GIT_DIR = ENV['GIT_DIR'] || '.git'
BSYM_DIR = '/bsym/ru.buddha'
OBJECTS_DIR = File.join(BSYM_DIR, 'objects')
BSYM_PATTERN = File.join(BSYM_DIR, 'pattern')
REFS = File.join(BSYM_DIR, 'refs')

def fatal(msg)
  puts msg
  exit 1
end

def usage
  fatal USAGE
end

def unlinked
  binary = GitIgnore.for(BSYM_PATTERN)
  l = Dir[File.join('**', '*')]
  l = l.select { |p| File.file?(p) and binary.match(p) }
  l.select { |p| not File.symlink?(p) }
end

def status
  unlinked.each { |p| puts "A #{p}" }
end

def convert(path)
  u = SecureRandom.uuid
  n = File.join(OBJECTS_DIR, u)
  File.rename(path, n)
  File.symlink(n, path)
  File.chmod(File.stat(n).mode & 0555, n)
end

def check
  # check we don't have whitespaces in filenames. We need this assumntin in
  # code below that parse full diff output
  names = `git diff -z --name-only --cached --diff-filter=A HEAD`.split("\0")
  names = names.select { |n| n.include?(" ") }
  if not names.empty?
    puts 'Files with whitespaces in name are prohibited:'
    names.each { |n| puts "  #{n}"}
    exit 1
  end

  binary = GitIgnore.for(BSYM_PATTERN)

  # check that binary files are added as symlinks
  out = `git diff --cached --diff-filter=A HEAD`
  lines = out.split("\n")
  l = lines.shift
  while l
    # added file name
    n = l.split(' ')[2].sub(/^a\//, '')
    # added file mode
    m = lines.shift.sub(/^new file mode /, '').to_i(8)

    # check that file mode is 120000 which means it's symlink
    if binary.match(n) and (m & 020000) == 0
      puts "File '#{n}' is binary and should be converted to symlink via bsym"
      exit 1
    end

    # skip until next file or diff end
    l = lines.shift
    l = lines.shift while (l and not l.start_with?('diff'))
  end
end

def revert
  binary = GitIgnore.for(BSYM_PATTERN)
  l = Dir[File.join('**', '*')]
  l = l.select { |p| File.symlink?(p) and binary.match(p) }
  l.each do |p|
    o = File.readlink(p)
    File.unlink(p)
    File.link(o, p)
  end
end

def objects(path)
  if not path.start_with?('/')
    fatal "Paths in refs file must be absolute. #{path} is relative."
  end
  Dir[File.join(path, '**', '*')].collect do |f|
    next nil if not File.symlink?(f)
    l = File.readlink(f)
    next nil if not l.start_with?(OBJECTS_DIR)
    l
  end.compact
end

def prune
  refs = File.read(REFS).split("\n").select { |l| not l.start_with?('#') }
  l = refs.collect { |p| objects(p) }
  l = l.inject([]) { |res, a| res | a }
  r = Dir[File.join(OBJECTS_DIR, '*')]
  o = r - l
  o.each { |p| File.unlink(p) }
  puts "#{o.size} files pruned"
end

cmd = ARGV.shift
case cmd
  when 'status'
    status
  when 'convert'
    unlinked.each { |p| convert(p) }
  when 'revert'
    revert
  when 'prune'
    prune
  when 'check'
    check
  else
    usage
end
