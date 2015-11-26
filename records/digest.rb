#!/bin/ruby

if ARGV.size < 2
  puts "Usage ./digest.rb <files dir> <hashes_dir>"
  exit 1
end

FILES_DIR = ARGV[0]
HASHES_DIR = ARGV[1]

def scan_dir(dir = '')
  Dir.entries(File.join(FILES_DIR, dir)).each do |entry|
    next if entry == '.' or entry == '..'
    local_path = File.join(dir, entry)
    file_path = File.join(FILES_DIR, local_path)
    hash_path = File.join(HASHES_DIR, local_path)
    if File.directory?(file_path) 
      if not File.exist?(hash_path)
        Dir.mkdir(hash_path) 
      end
      scan_dir(local_path)
    else
      next if /\.mp3$/.match(entry).nil?
      if File.exist?(hash_path)
        puts "-#{file_path}"
        next
      end
      puts "+#{file_path}"
      sum = `./md5sum-id3-strip "#{file_path}"`
      exit if not $?.success?
      File.open(hash_path, "w") do |file|
        file.write(sum)
      end
    end
  end
end

scan_dir()
