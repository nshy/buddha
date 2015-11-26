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

def group_paths(files)
  grouped_files = files.group_by { |file| file[:digest] }
  grouped_paths = grouped_files.values.collect do |files|
    files.collect { |file| file[:path]}
  end
  grouped_paths
end
