require_relative 'models'
require 'sequel'
require 'preamble'
require 'pathname'

DB = Sequel.connect('sqlite://site.db')
DB.run('pragma synchronous = off')
DB.run('pragma foreign_keys = on')

def print_modification(prefix, dir, set)
  set.each { |url| puts "#{prefix} #{dir}/#{url}" }
end

def update_table(table, updated, added, deleted)
  dir = table.to_s.gsub(/_/, '-')
  print_modification('D', dir, deleted)
  print_modification('A', dir, added)
  print_modification('U', dir, updated)

  DB[table].where('url IN ?', deleted + updated).delete
  (added + updated).each { |url| yield url }
end

DB.create_table :time_clamper, temp: true do
  DateTime :time
end
DB[:time_clamper].insert(time: nil)

def clamp_time(time)
  DB[:time_clamper].update(time: time)
  DB[:time_clamper].first[:time]
end

def sync_root_table(table, file, &block)
  url = path_to_id(Pathname.new(file).each_filename.to_a[1])
  itemdb = DB[:root_docs].where(url: file)
  item = itemdb.first
  if File.exists?(file)
    mtime = clamp_time(File.mtime(file))
    if item.nil?
      # add
      puts "A #{url}"
      DB[:root_docs].insert(url: file, last_modified: mtime)
      block.call
      return
    end

    return if mtime <= item[:last_modified]
    # update
    puts "U #{url}"
    DB[table].delete
    block.call
    itemdb.update(last_modified: mtime)
  elsif not item.nil?
    puts "D #{url}"
    # delete
    itemdb.delete
    DB[table].delete
  end
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

# --------------------- books --------------------------

def load_books(url)
  path = "data/books/#{url}/info.xml"
  book = BookDocument.load(path)

  DB[:books].insert(title: book.title,
                    authors: book.author.join(', '),
                    translators: book.translator.join(', '),
                    year: book.year,
                    isbn: book.isbn,
                    publisher: book.publisher,
                    amount: book.amount,
                    annotation: book.annotation,
                    contents: book.contents,
                    outer_id: book.outer_id,
                    added: book.added,
                    url: url,
                    last_modified: File.mtime(path))
end

def load_book_categories(url)
  path = "data/book-categories/#{url}.xml"
  category = BookCategoryDocument.load(path)

  DB[:book_categories].
    insert(name: category.name,
           url: url,
           last_modified: File.mtime(path))

  category.group.each do |group|
    group.book.each do |book|
      DB[:category_books].
        insert(group: group.name,
               book_id: book,
               category_id: url)
    end
  end

  category.subcategory.each do |subcategory|
    DB[:category_subcategories].
      insert(category_id: url,
             subcategory_id: subcategory)
  end
end

def load_library()
  library = LibraryDocument.load('data/library.xml')

  library.section.each do |section|
    section.category.each do |category|
      DB[:top_categories].
        insert(section: section.name,
               category_id: category)
    end
  end
end
