#!/bin/ruby

require_relative 'utils'
require 'securerandom'

USAGE = <<USAGE
usage: bsym <command>

Commands:
  status    print not yet symlinked files

USAGE

BSYM_DIR = '.bsym'
BINARY = GitIgnore.for(File.join(BSYM_DIR, 'pattern'))

def fatal(msg)
  puts msg
  exit 1
end

def usage
  fatal USAGE
end

def unlinked
  l = Dir[File.join('**', '*')]
  l = l.select { |p| File.file?(p) and BINARY.match(p) }
  l.select { |p| not File.symlink?(p) }
end

def status
  unlinked.each { |p| puts "A #{p}" }
end

def convert(path)
  u = SecureRandom.uuid
  n = File.join(BSYM_DIR, u)
  puts "#{u} <- #{path}"
  File.rename(path, n)
  File.symlink(n, path)
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
    if BINARY.match(n) and (m & 020000) == 0
      puts "File '#{n}' is binary and should be converted to symlink via bsym"
      exit 1
    end

    # skip until next file or diff end
    l = lines.shift
    l = lines.shift while (l and not l.start_with?('diff'))
  end
end

cmd = ARGV.shift
case cmd
  when 'status'
    status
  when 'convert'
    unlinked.each { |p| convert(p) }
  when 'check'
    check
  else
    usage
end
