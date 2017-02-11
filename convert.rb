require_relative 'models'
require 'sequel'
require 'preamble'

DB = Sequel.connect('sqlite://site.db')
DB.run('pragma synchronous = off')

def print_modification(type, set)
  return if set.empty?
  puts type
  set.each { |url| puts "  #{url}" }
end

def update_table(table, updated, added, deleted)
  b = Time.new

  print_modification('DELETED', deleted)
  print_modification('ADDED', added)
  print_modification('UPDATED', updated)

  DB[table].where('url IN ?', deleted + updated).delete
  (added + updated).each { |url| yield url }

  e = Time.new
  puts "sync time is #{((e - b) * 1000).to_i}ms"
end

# --------------------- teachings --------------------------

def load_teachings(url)
  path = "data/teachings/#{url}.xml"
  teachings = TeachingsDocument.load(path)

  id = DB[:teachings].insert(title: teachings.title,
                             url: url,
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

# --------------------- news --------------------------

NewsExt = [:adoc, :html, :erb]

def find_file(dir, name)
  paths = NewsExt.map { |ext| "#{dir}/#{name}.#{ext}" }
  paths.find { |path| File.exists?(path) }
end

def load_news(url)
  is_dir = false
  path = find_file('data/news', url)
  if path.nil?
    is_dir = true
    path = find_file("data/news/#{url}", 'page')
  end

  html_cutter = /<!--[\t ]*page-cut[\t ]*-->.*/m
  cutters = {
    adoc: /^<<<$.*/m,
    html: html_cutter,
    erb: html_cutter
  }

  ext = path_to_ext(path)
  doc = Preamble.load(path)
  body = doc.content
  cut = body.gsub(cutters[ext.to_sym], '')
  cut = nil if cut == body

  DB[:news].insert(date: Date.parse(doc.metadata['publish_date']),
                   title: doc.metadata['title'],
                   url: url,
                   cut: cut,
                   body: body,
                   ext: ext,
                   is_dir: is_dir,
                   buddha_node: doc.metadata['buddha_node'],
                   last_modified: File.mtime(path))
end
