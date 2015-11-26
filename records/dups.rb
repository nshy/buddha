#!/bin/ruby

if ARGV.size < 1
  puts "Usage ./dups.rb <hashes_dir>"
  exit 1
end

hashes_dir = ARGV[0]

def scan_dir(root_dir, dir = '')
  files = []
  Dir.entries(File.join(root_dir, dir)).each do |entry|
    next if entry == '.' or entry == '..'
    local_path = File.join(dir, entry)
    file_path = File.join(root_dir, local_path)
    if File.directory?(file_path)
      files += scan_dir(root_dir, local_path)
    else
      File.open(file_path, "r") do |file|
        files << { digest: file.read, path: file_path }
      end
    end
  end
  files
end

files = scan_dir(hashes_dir)
grouped = files.group_by { |file| file[:digest] }
dups = grouped.select { |k, v| v.size > 1 }

dups.each_value do |files|
  puts files.pop[:path]
  files.each do |file|
    puts "  #{file[:path]}"
  end
end
