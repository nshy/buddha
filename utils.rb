class Week
  include Comparable

  def initialize(date = Date.today)
    @monday = date - (date.cwday - 1)
  end

  def monday
    @monday
  end

  def sunday
    @monday + 6
  end

  def day(cwday)
    @monday + (cwday - 1)
  end

  def self.cwdays
    1..7
  end

  def dates
    monday..sunday
  end

  def prev
    Week.new(@monday - 7)
  end

  def next
    Week.new(@monday + 7)
  end

  def succ
    self.next
  end

  def <=>(week)
    self.monday <=> week.monday
  end

  def -(week)
    (@monday - week.monday).numerator / 7
  end

  def +(num)
    Week.new(@monday + 7 * num)
  end

  def to_s
    "start at #{@monday}"
  end
end

class ModelException < RuntimeError
end

def path_from_db(path)
  path.split('/')[1..-1].join('/')
end

def format_file_error(path, msg)
  ModelException.new("Нарушение формата в файле #{path_from_db(path)}:\n#{msg}")
end

def load_preamble(path, required)
  begin
    doc = Preamble.load(path)
  rescue StandardError
    raise format_file_error(path, "Ошибочное форматирование заголовка страницы")
  end

  if required
    if not doc.metadata
      raise format_file_error(path, "Отсутствует заголовок страницы")
    end
    required.each do |r|
      if not doc.metadata.has_key?(r)
        raise format_file_error(path, "Отсутствует обязательное поле заголовка #{r}")
      end
    end
  end

  [ doc.content, doc.metadata ]
end

module Utils
  def self.list_recursively(dir)
    files = Dir.entries(dir).select do |e|
      not e =~ /^\./ \
        and File.file?(File.join(dir, e)) \
    end
    dirs = Dir.entries(dir).select do |e|
      not e =~ /^\./ and File.directory?(File.join(dir, e))
    end
    files = files.map { |e| File.join(dir, e) }
    dirs = dirs.map { |e| Utils.list_recursively(File.join(dir, e)) }.flatten
    files + dirs
  end
end

class GitIgnore
  Message = <<-END
Неправильный формат файла #{GitIgnore}. Пример правильного файла:

*
!*/
!*.xml
!*.html
!*.scss
!*.yaml
  END

  def initialize(excludes)
    @excludes = excludes
  end

  def self.for(path)
    # skip first line which is ignore all
    ignore = File.read(path).split
    raise Message if ignore.shift != '*'
    raise Message if ignore.shift != '!*/'
    ignore.each { |i| error if not i.start_with?('!*.') }
    e = ignore.map { |i| i.sub('!*', '').strip }
    new(e)
  end

  def match(path)
    not @excludes.include?(File.extname(path))
  end
end

module Cache
  def self.diff(db, table, files)
    db.create_table :disk_state, temp: true do
      String :path, primary_key: true
      DateTime :mtime , null: false
    end

    files.each { |p| db[:disk_state].insert(path: p, mtime: File.lstat(p).mtime) }

    d = db[table].join_table(:left, :disk_state, path: :path).
          where(Sequel[:disk_state][:path] => nil).
            select(Sequel[table][:path])

    u = db[:disk_state].join_table(:left, table, path: :path).
          where{ Sequel[table][:mtime] < Sequel[:disk_state][:mtime] }.
            select(Sequel[:disk_state][:path])

    a = db[:disk_state].join_table(:left, table, path: :path).
          where(Sequel[table][:path] => nil).
            select(Sequel[:disk_state][:path])

    r = [ convert(u), convert(a), convert(d) ]
    db.drop_table(:disk_state)
    r
  end

  def self.convert(set)
    set.to_a.map { |v| v[:path] }
  end

  def self.diffmsg(u, a, d, prefix = nil)
    d = [ [ u, 'U' ], [ a, 'A'], [d, 'D'] ]
    d.each do |s|
      s[0].each do |p|
        m = "#{s[1]} #{p}"
        m = "#{prefix} #{m}" if prefix
        puts m
      end
    end
  end
end
