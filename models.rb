require_relative 'xmldsl'
require 'date'

class TeachingsDocument < XDSL::Element
  element :title
  element :year
  elements :theme do
    element :title
    element :buddha_node
    elements :record do
      element :description
      element :record_date, Date
      element :audio_url
      element :audio_size
      element :video_url
      element :video_size
      element :youtube_id
    end
  end

  def begin_date
    t = theme.min { |a, b| a.begin_date <=> b.begin_date }
    t.begin_date
  end

  class Theme
    def begin_date
      r = record.min { |a, b| a.record_date <=> b.record_date }
      r.record_date
    end
  end
end

class BookDocument < XDSL::Element
  element :title
  elements :author
  elements :translator
  element :year
  element :isbn
  element :publisher
  element :amount
  element :annotation
  element :contents
  element :added
  element :outer_id
end

class BookCategoryDocument < XDSL::Element
  element :name
  elements :subcategory
  elements :group do
    element :name
    elements :book
  end
end

class LibraryDocument < XDSL::Element
  elements :section do
    element :name
    elements :category
  end
  element :recent do
    elements :book
  end
end

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

  def next
    Week.new(@monday + 7)
  end

  def <=>(week)
    self.monday <=> week.monday
  end
end

class TimetableDocument < XDSL::Element

  class ClassesDay
    REGEXP = /([[:alpha:]]+)\s*,\s*(\d{2}:\d{2})-(\d{2}:\d{2})/

    attr_reader :day

    def initialize(day, b, e)
      @day = Date.parse(day).cwday
      @begin = b
      @end = e
    end

    def self.parse(value)
      r = REGEXP.match(value)
      new(r[1], r[2], r[3])
    end

    def begin(week)
      time(week, @begin)
    end

    def end(week)
      time(week, @end)
    end

  private
    def time(week, t)
      strdate = week.day(@day).strftime('%Y-%m-%d')
      DateTime.parse("#{strdate} #{t}")
    end
  end

  class ClassesDate
    REGEXP = /([[:alpha:]]+)\s*,\s*(\d{2}:\d{2})-(\d{2}:\d{2})/

    attr_reader :date, :times

    def initialize(date, times)
      @date = date
      @times = times
    end

    def self.parse(value)
      a = value.split(',')
      date = Date.parse(a.shift.strip)
      times = a.collect do |i|
        r = /(\d{2}:\d{2})-(\d{2}:\d{2})/.match(i)
        { begin: time(date, r[1]), end: time(date, r[2]) }
      end
      new(date, times)
    end

  private
    def self.time(date, t)
      strdate = date.strftime('%Y-%m-%d')
      DateTime.parse("#{strdate} #{t}")
    end
  end


  element :banner do
    element :begin, Date
    element :end, Date
    element :message
  end
  element :annual
  elements :classes do
    element :image
    element :title
    element :info
    element :timeshort
    elements :day, ClassesDay
    element :begin, Date
    element :end, Date
    elements :cancel
    elements :date, ClassesDate
  end

  class Classes
    alias_method :begin_plain, :begin
    alias_method :end_plain, :end

    def begin
      b = begin_plain
      return b if not b.nil?

      b = date.map { |d| d.date }.min
      return b if not b.nil?

      Date.new(1900)
    end

    def end
      e = end_plain
      return e if not e.nil?

      e = date.map { |d| d.date }.max
      return e if not e.nil?

      Date.new(2100)
    end

    def future?
      Week.new < Week.new(self.begin)
    end

    def actual?
      c = Week.new
      Week.new(self.begin) <= c and c <= Week.new(self.end)
    end
  end

  class Banner
    def active?
      today = Date.today
      (self.begin.nil? or self.begin <= today - 1) and
      (self.end.nil? or today <= self.end)
    end
  end
end

class MenuDocument < XDSL::Element
  elements :item do
    element :name
    element :title
    element :link
    elements :subitem do
      element :title
      element :link
    end
  end

  def about
    item.select { |i| i.name == 'about' }.first
  end

  def others
    item.select { |i| i.name != 'about' }
  end
end

class QuotesDocument < XDSL::Element
  elements :quote
end
