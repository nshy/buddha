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
end

class TimetableDocument < XDSL::Element

  class ClassesSingleTime
    include Comparable

    attr_reader :hour, :minute

    def initialize(hour, minute)
      @hour = hour
      @minute = minute
    end

    def to_s
      "#{@hour}:#{@minute}"
    end

    def self.parse(value)
      d = DateTime.parse(value)
      new(d.hour, d.minute)
    end

    def <=>(time)
      to_minutes <=> time.to_minutes
    end

    def to_minutes
      @hour * 24 + @minute
    end
  end

  class ClassesTime
    REGEXP = /\d{2}:\d{2}/

    attr_reader :begin, :end, :temp

    def initialize(b, e, temp)
      @begin = b
      @end = e
      @temp = temp
    end

    def self.parse(value)
      # parse *
      value.strip!
      temp = value.end_with?('*')
      value.chop! if temp

      a = value.strip.split('-')
      bs = a.shift
      return nil if not REGEXP.match(bs)
      b = ClassesSingleTime.parse(bs)
      es = a.shift
      if es
        return nil if not REGEXP.match(es)
        e = ClassesSingleTime.parse(es)
      else
        e = ClassesSingleTime.new((b.hour + 2) % 24, b.minute)
      end
      new(b, e, temp)
    end

    def to_s
      "#{@begin}-#{@end}"
    end
  end

  module DayParser
    def parse_day(value, clazz)
      a = value.split(',')
      date = Date.parse(a.shift.strip)

      # parse times
      times = []
      last = a.shift
      raise "Time must be specified in '#{value}'" if last.nil?
      begin
        time = ClassesTime.parse(last.strip)
        break if time.nil?
        times << time
        last = a.shift
      end while last

      last.strip! if last
      place = last || 'Спартаковская'
      raise "day value '#{value}' has unparsed tail" if not a.empty?
      if not ['Спартаковская', 'Мытная'].include?(place)
        raise "address must be Спартаковская either or Мытная in '#{value}'"
      end

      clazz.new(date, times, place)
    end
  end

  class ClassesDay
    extend DayParser

    attr_reader :day, :place

    def initialize(day, times, place)
      @day = day.cwday
      @times = times
      @place = place
    end

    def self.parse(value)
      parse_day(value, self)
    end

    def dates(b, e)
      wb = Week.new(b)
      we = Week.new(e)
      dates = (wb..we).collect do |w|
        ClassesDate.new(w.day(@day), @times, @place)
      end
      dates.select { |d| d.date >= b and d.date <= e }
    end
  end

  class ClassesDate
    extend DayParser

    attr_reader :date, :times, :place

    def initialize(date, times, place)
      @date = date
      @times = times
      @place = place
    end

    def self.parse(value)
      parse_day(value, self)
    end

    def to_event
      @times.collect do |t|
        d = @date
        d += 1 if t.end < t.begin
        {
          begin: date_time(@date, t.begin),
          end: date_time(d, t.end),
          place: @place,
          date: @date,
          temp: t.temp,
        }
      end
    end

  private
    def date_time(date, t)
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
    elements :cancel, Date
    elements :date, ClassesDate
    elements :changes do
      element :announce
      element :begin, Date
      element :end, Date
      elements :day, ClassesDay
    end
  end

  module DayDates
    def day_dates(b, e)
      cb = self.begin || b
      ce = self.end || e
      cb = b > cb ? b : cb
      ce = e < ce ? e : ce
      day.collect { |d| d.dates(cb, ce) }.flatten
    end
  end

  class DateInterval
    attr_reader :begin, :end

    def initialize(b, e)
      @begin = b
      @end = e
    end
  end

  class IntervalBuilder
    attr_reader :intervals

    def initialize(b, e)
      @intervals = [ DateInterval.new(b, e) ]
    end

    def delete(b, e)
      @intervals = @intervals.collect do |i|
        if i.begin >= b and i.end <= e
          []
        elsif i.begin < b and i.end > e
          [ DateInterval.new(i.begin, b - 1),
            DateInterval.new(e + 1, i.end) ]
        elsif i.begin > e or i.end < b
          i
        elsif i.begin < b
          DateInterval.new(i.begin, b - 1)
        else
          DateInterval.new(e + 1, i.end)
        end
      end
      @intervals.flatten!
    end
  end

  class Classes
    include DayDates

    class Changes
      include DayDates

      def actual?
        (Week.new.next >= Week.new(self.begin)) and
          Week.new <= Week.new(self.end)
      end
    end

    def begin_full
      return self.begin if not self.begin.nil?

      b = date.map { |d| d.date }.min
      return b if not b.nil?

      Date.new(1900)
    end

    def end_full
      return self.end if not self.end.nil?

      e = date.map { |d| d.date }.max
      return e if not e.nil?

      Date.new(2100)
    end

    def future?
      Week.new < Week.new(self.begin_full)
    end

    def actual?
      c = Week.new
      Week.new(self.begin_full) <= c and c <= Week.new(self.end_full)
    end

    def events(b, e)
      dates = date.select { |d| d.date >= b and d.date <= e }

      dates += changes.collect { |c| c.day_dates(b, e) }.flatten

      i = IntervalBuilder.new(b, e)
      changes.each { |c| i.delete(c.begin, c.end) }
      dates += i.intervals.collect { |i| day_dates(i.begin, i.end) }.flatten

      events = dates.collect { |d| d.to_event }.flatten

      events.each do |e|
        e[:title] = title
        e[:cancel] = cancel.include?(e[:date])
      end
    end

    def announces
      changes.select { |c| c.actual? }.collect { |c| c.announce }.join(' ')
    end
  end

  class Banner
    def active?
      today = Date.today
      (self.begin.nil? or self.begin <= today - 1) and
      (self.end.nil? or today <= self.end)
    end
  end

  def events(b, e)
    events = classes.collect { |c| c.events(b, e) }.flatten
    events.sort { |a, b| a[:begin] <=> b[:begin] }
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
  elements :begin, Date
  elements :quote

  def current_quotes
    num = 5
    w = Week.new
    b = self.begin.select { |b| b <= w.monday }.last

    wb = Week.new(b)
    wb += 1 if not b.monday?
    (quote + quote.slice(0, num)).slice((w - wb) % quote.length, num)
  end
end
