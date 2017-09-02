#!/bin/ruby

require_relative 'utils'
require 'securerandom'
require 'fileutils'

USAGE = <<USAGE
usage: bsym <command>

Commands:
  status    print not yet symlinked files
  convert   convert binary files to symlinks
  clone     clone repo

clone <from> <to>:
  from      repository to clone from
  to        repository to clone to

USAGE

BSYM_DIR = '.bsym'
OBJECTS_DIR = File.join(BSYM_DIR, 'objects')
BSYM_PATTERN = File.join(BSYM_DIR, 'pattern')

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

def clone
  from = ARGV.shift
  to = ARGV.shift
  usage if not from or not to

  if not File.directory?(File.join(from, BSYM_DIR))
    fatal "#{from} is not a bsym repository"
  end

  if not File.exist?(to)
    Dir.mkdir(to)
  elsif not File.directory?(to)
    fatal "destination path #{to} already exists "\
          "and is not an empty directory"
  end

  if File.exist?(File.join(to, BSYM_DIR))
    fatal "destination path #{to} already exists and is not an empty directory"
  end
  Dir.mkdir(File.join(to, BSYM_DIR))
  Dir.mkdir(File.join(to, OBJECTS_DIR))
  FileUtils.copy_file(File.join(from, BSYM_PATTERN),
                      File.join(to, BSYM_PATTERN))
  l = Dir[File.join(from, OBJECTS_DIR, '*')]
  l.each { |l| File.link(l, File.join(to, OBJECTS_DIR, File.basename(l))) }
end

cmd = ARGV.shift
case cmd
  when 'status'
    status
  when 'convert'
    unlinked.each { |p| convert(p) }
  when 'clone'
    clone
  when 'check'
    check
  else
    usage
end
