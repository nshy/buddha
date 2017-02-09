require_relative 'models'
require 'sequel'

DB = Sequel.connect('sqlite://site.db')
DB.run('pragma synchronous = off')

def load_teachings(path)
  teachings = TeachingsDocument.load(path)

  id = DB[:teachings].insert(title: teachings.title,
                             url: path_to_id(path),
                             last_modified: File.mtime(path))

  teachings.theme.each do |theme|
    theme_id = DB[:themes].insert(title: theme.title,
                                  begin_date: theme.begin_date,
                                  teaching_id: id)

    theme.record.each do |record|
      DB[:records].insert(record_date: record.record_date,
                          description: record.description,
                          audio_url: record.audio_url,
                          audio_size: record.audio_size.to_i,
                          youtube_id: record.youtube_id,
                          theme_id: theme_id)
    end
  end
end

def print_modification(type, set)
  return if set.empty?
  puts type
  set.each { |url| puts "  #{url}" }
end

def load_teachings_set(urls)
  urls.each { |url| load_teachings("data/teachings/#{url}.xml") }
end

def update_teachings(updated, added, deleted)
  b = Time.new

  print_modification('DELETED', deleted)
  DB[:teachings].where('url IN ?', deleted).delete

  print_modification('ADDED', added)
  load_teachings_set(added)

  print_modification('UPDATED', updated)
  DB[:teachings].where('url IN ?', updated).delete
  load_teachings_set(updated)

  e = Time.new
  puts "sync time is #{((e - b) * 1000).to_i}ms"
end
