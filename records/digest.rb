#!/usr/bin/ruby

=begin

Calc recursively md5sum digest in <files dir>. Result is placed in <hashes_dir>
and directory structure of <files dir> is saved. Digest is placed in the file
with the same name as original file. Digesting program is not original md5sum
but modified version that strip all id3 metadata before digesting.

=end

def is_good_mode(mode)
  ["md5", "meta", "chromaprint"].index(mode).nil?
end


if ARGV.size < 3 or is_good_mode(ARGV[0])
  puts "Usage #{$0} <mode> <files dir> <hashes_dir>"
  puts "  where mode is md5 | chromaprint | meta"
  exit 1
end

def process_dir(files_dir, hashes_dir, dir = '', &block)
  Dir.entries(File.join(files_dir, dir)).each do |entry|
    next if entry == '.' or entry == '..'
    local_path = File.join(dir, entry)
    file_path = File.join(files_dir, local_path)
    hash_path = File.join(hashes_dir, local_path)
    if File.directory?(file_path) 
      if not File.exist?(hash_path)
        Dir.mkdir(hash_path) 
      end
      process_dir(files_dir, hashes_dir, local_path) do |path|
        block.call(path)
      end
    else
      next if /\.mp3$/.match(entry).nil?
      if File.exist?(hash_path)
        puts "-#{file_path}"
        next
      end
      puts "+#{file_path}"
      sum = block.call(file_path)
      exit(1) if not $?.success?
      File.open(hash_path, "w") do |file|
        file.write(sum)
      end
    end
  end
end

mode = ARGV[0]
process_dir(ARGV[1], ARGV[2]) do |path|
  if mode == 'md5'
    `./md5sum-id3-strip "#{path}"`
  elsif mode == 'chromaprint'
    `fpcalc -raw "#{path}"`
  else
    duration = `mp3info -p '%S\n' "#{path}"`
    "duration: #{duration}"
  end
end
