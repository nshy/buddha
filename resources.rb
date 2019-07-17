module Resources

# --------------------- teachings --------------------------

module Teaching
  def load(path, id)
    teachings = ::Teachings::Document.load(path)

    insert_object(database[:teachings], teachings, path: path, id: id)
    teachings.theme.each do |theme|
      theme_id = insert_object(database[:themes], theme,
                               teaching_id: id, teaching_path: path)
      theme.record.each_with_index do |record, i|
        insert_object(database[:records], record,
                      theme_id: theme_id,
                      order: i)
      end
    end
  end

  def dirs
    data_dir("teachings", "xml")
  end
end

# --------------------- news --------------------------

module News
  def load(path, id)
    news = NewsDocument.new(path)
    insert_object(database[:news], news, path: path)
  end

  def dirs
    data_dir("news", "html")
  end
end

# --------------------- books --------------------------

module Book
  def load(path, id)
    book = ::Book::Document.load(path)
    insert_object(database[:books], book, path: path)
  end

  def dirs
    data_dir("books", "xml")
  end
end

module BookCategory
  def load(path, id)
    category = ::BookCategory::Document.load(path)

    insert_object(database[:book_categories],category,
                  path: path, id: id)
    category.group.each do |group|
      group.book.each do |book|
        database[:category_books].
          insert(group: group.name,
                 book_id: book,
                 category_path: path,
                 category_id: id)
      end
    end

    category.subcategory.each do |subcategory|
      database[:category_subcategories].
        insert(category_path: path,
               category_id: id,
               subcategory_id: subcategory)
    end
  end

  def dirs
    data_dir("book-categories", "xml")
  end
end

# --------------------- digests --------------------------

class DigestDir
  attr_reader :dir

  def initialize(dir, options = {})
    @dir = dir
    @dir_sz = path_split(dir).size
    @match = options[:match]
    @exclude = options[:exclude]
  end

  def files
    Dir[File.join(dir, '**', '*')].select { |p| File.file?(p) and match(p) }
  end

  def match(path)
    # slice is for the first directory that can contain '.' like '.build'
    return false if path_split(path).slice(1..-1).any? { |e| /^\./ =~ e }
    return false if @exclude and @exclude.call(dir, path)
    return false if @match and not @match.call(path)
    true
  end

  def path_to_id(path)
    a = path_split(path).slice((@dir_sz - 1)..-1)
    a[0] = nil
    a.join('/')
  end
end

module Digest_SHA1

  def load(path, id)
    database[:digest_sha1s].insert(path: path,
                                   sha1: ::Digest::SHA1.file(path).hexdigest)
  end

  def dirs
    # order is significant because of dir search approach in table_insert
    [ DigestDir.new(site_build_dir),
      DigestDir.new(build_dir, exclude: Digest_SHA1.method(:build_exclude)),
      DigestDir.new('public', exclude: Digest_SHA1.method(:public_exclude)) ]
  end

  def self.public_exclude(dir, path)
    ex = [ '3d-party', 'fonts' ]
    ex.any? { |e| path.start_with?("#{dir}/#{e}") }
  end

  def self.build_exclude(dir, path)
    ex = Sites + ['css']
    ex.any? { |e| path.start_with?("#{dir}/#{e}") }
  end
end

module Digest_UUID

  def load(path, id)
    p = path
    while File.symlink?(p)
      p = File.join(File.dirname(p), File.readlink(p))
    end
    uuid = p != path ? File.basename(p) : nil
    database[:digest_uuids].insert(path: path, uuid: uuid)
  end

  def dirs
    [ DigestDir.new(site_dir, match: GitIgnore.for('bin-pattern').method(:match)) ]
  end
end

All = [ Teaching, News, Book, BookCategory, Digest_SHA1, Digest_UUID ]

end # module Resources
