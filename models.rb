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

class OpenRange
  attr_reader :begin, :end

  def initialize(b, e)
    @begin = b
    @end = e
  end

  def cover?(x)
    not (left?(x) or right?(x))
  end

  def left?(x)
    b = self.begin
    b and x < b
  end

  def right?(x)
    e = self.end
    e and x > e
  end

  def to_s
    "#{@begin} - #{@end}"
  end
end

class Event
  attr_accessor :title, :date, :time, :place

  attr_writer :conflict, :cancelled, :temporary

  def conflict?
    @conflict
  end

  def cancelled?
    @cancelled
  end

  def temporary?
    @temporary
  end

  def date
    time.begin.to_date
  end

  def ==(other)
    @title == other.title and
    @time == other.time and
    @place == other.place
  end

  def to_s
    "#{@time} #{@title} #{@place}"
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
      "%02d:%02d" % [ @hour, @minute ]
    end

    def self.parse(value)
      d = DateTime.parse(value)
      new(d.hour, d.minute)
    end

    def self.from_datetime(t)
      new(t.hour, t.minute)
    end

    def <=>(time)
      to_minutes <=> time.to_minutes
    end

    def to_minutes
      @hour * 24 + @minute
    end
  end

  class EventTime
    attr_reader :begin, :end

    def initialize(b, e)
      @begin = b
      @end = e
    end

    def cross(t)
      not (t.begin > @end or t.end < @begin)
    end

    def classes_time
      ClassesTime.new(ClassesSingleTime.from_datetime(@begin),
                      ClassesSingleTime.from_datetime(@end))
    end

    def ==(other)
      @begin == other.begin and @end == other.end
    end

    def to_s
      "#{@begin} - #{@end}"
    end
  end

  class ClassesTime
    REGEXP = /\d{2}:\d{2}/
    DayBegin = ClassesSingleTime.new(0, 0)
    DayEnd = ClassesSingleTime.new(0, 0)

    attr_reader :begin, :end, :temp

    def initialize(b, e, temp = false)
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
      "#{@begin} - #{@end}"
    end

    def event_time(date)
      d = date
      d = date + 1 if @end <= @begin
      b = DateTime.new(date.year, date.month, date.day,
                       @begin.hour, @begin.minute)
      e = DateTime.new(d.year, d.month, d.day,
                       @end.hour, @end.minute)
      EventTime.new(b, e)
    end

    def event(date, place)
      e = ::Event.new
      e.time = event_time(date)
      e.place = place
      e.temporary = temp
      e
    end

    WholeDay = new(DayBegin, DayEnd)
  end

  module ParseHelper
    def parse_times(a)
      times = []
      while a.first
        time = ClassesTime.parse(a.first)
        break if time.nil?
        times << time
        a.shift
      end
      times
    end

    def parse_place(a)
      place = a.shift || 'Спартаковская'
      if not ['Спартаковская', 'Мытная'].include?(place)
        raise "address must be Спартаковская either or Мытная"
      end
      place
    end

    def parse_check_tail(a)
      raise "unparsed tail" if not a.empty?
    end
  end

  class ClassesDay
    extend ParseHelper

    attr_reader :day, :place

    def initialize(day, times, place)
      @day = day
      @times = times
      @place = place
    end

    def self.parse(value)
      a = value.split(',')

      day = Date.parse(a.shift.strip).cwday

      times = parse_times(a)
      # for luck
      raise "Time must be specified" if times.empty?

      place = parse_place(a)
      parse_check_tail(a)

      new(day, times, place)
    end

    def events(r)
      b = Week.new(r.begin)
      e = Week.new(r.end)
      events = (b..e).collect do |w|
        @times.collect { |t| t.event(w.day(@day), @place) }
      end
      events.flatten.select { |e| r.cover?(e.date) }
    end
  end

  class ClassesDate
    extend ParseHelper

    attr_reader :date, :times, :place

    def initialize(date, times, place)
      @date = date
      @times = times
      @place = place
    end

    def self.parse(value)
      a = value.split(',')

      date = Date.parse(a.shift.strip)

      times = parse_times(a)
      place = parse_place(a)
      parse_check_tail(a)

      new(date, times, place)
    end

    def events(r)
      events = @times.collect { |t| t.event(@date, @place) }
      events.select { |e| r.cover?(e.date) }
    end
  end

  class Cancel
    extend ParseHelper

    attr_reader :date, :times

    def initialize(date, times)
      @times = times.collect { |t| t.event_time(date) }
      @times << ClassesTime::WholeDay.event_time(date) if @times.empty?
    end

    def self.parse(value)
      a = value.split(',')

      date = Date.parse(a.shift.strip)
      times = parse_times(a)
      parse_check_tail(a)

      new(date, times)
    end

    def affect?(e)
      @times.any? { |t| t.cross(e) }
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

    elements :schedule do
      element :timeshort
      element :announce
      elements :day, ClassesDay
      element :begin, Date
      element :end, Date
      elements :date, ClassesDate
    end

    elements :cancel, Cancel

    elements :changes do
      element :announce
      element :begin, Date
      element :end, Date
      elements :day, ClassesDay
      elements :date, ClassesDate
    end
  end

  elements :event do
    element :title
    element :date, ClassesDate
    elements :cancel, Cancel
  end

  module WeekBorders
    def week_range
      r = range
      wb = r.begin ? Week.new(r.begin) : nil
      we = r.end ? Week.new(r.end) : nil
      OpenRange.new(wb, we)
    end
  end

  module TimePosition
    def future?
      week_range.left?(Week.new)
    end

    def actual?
      week_range.cover?(Week.new)
    end
  end

  module DayDates
  private
    def begin_full
      day.empty? ?  date.map { |d| d.date }.min : self.begin
    end

    def end_full
      day.empty? ? date.map { |d| d.date }.max : self.end
    end

  public
    def range
      OpenRange.new(begin_full, end_full)
    end

    def day_events(r)
      r = days_range(r)
      return [] if r.nil?
      day.collect { |d| d.events(r) }.flatten
    end

    def date_events(r)
      date.collect { |d| d.events(r) }.flatten
    end

    def days_range(r)
      cb = self.begin
      ce = self.end
      b = r.begin
      e = r.end
      b = cb if cb and cb > b
      e = ce if ce and ce < e
      return nil if b > e
      b..e
    end

    def include_date?(d)
      date.any? { |cd| cd.date == d }
    end
  end

  module Cancelable
    def mark_cancels(events)
      events.each do |e|
        e.cancelled = cancel.any? { |c| c.affect?(e.time) }
      end
    end
  end

  class Classes
    include WeekBorders
    include TimePosition
    include Cancelable

    class Schedule
      include WeekBorders
      include TimePosition
      include DayDates

      def events(r)
        date_events(r) + day_events(r)
      end
    end

    class Changes
      include DayDates
      include WeekBorders
      include TimePosition

      def apply(events, r)
        events = apply_change(events, days_filter(events, r), day_events(r))
        apply_change(events, date_filter(events), date_events(r))
      end

    private
      def mark_changes(changes, filtered)
        changes.each { |c| c.temporary = !filtered.include?(c) }
      end

      def apply_change(events, filtered, changes)
        mark_changes(changes, filtered)
        events - filtered + changes
      end

      def days_filter(events, r)
        return [] if day.empty?
        dr = days_range(r)
        return [] if dr.nil?
        events.select { |e| dr.cover?(e.date) }
      end

      def date_filter(events)
        events.select { |e| include_date?(e.date) }
      end
    end

    def range
      OpenRange.new(schedule.first.range.begin, schedule.last.range.end)
    end

    def events(r)
      events = schedule.collect { |s| s.events(r) }.flatten
      changes.each { |c| events = c.apply(events, r) }
      mark_cancels(events)
      events.each { |e| e.title = title }
    end

    def announces
      a = changes.select { |c| c.actual? or c.future? } +
          schedule.select { |s| s.future? }
      a.sort! { |a, b| a.range.begin <=> b.range.begin }
      a.collect { |a| a.announce }.join(' ')
    end

    def timeshort
      if actual?
        actual_schedule.timeshort
      else
        schedule.first.timeshort
      end
    end

    def actual_schedule
      schedule.detect { |s| s.week_range.cover?(Week.new) }
    end

    def on_load
      p = nil
      schedule.each do |s|
        if p and p.week_range.cover?(s.week_range.begin)
          p.end = s.week_range.begin.prev.sunday
        end
        p = s
      end
    end
  end

  class Event
    include Cancelable

    def events(r)
      events = date.events(r).each { |e| e.title = title }
      mark_cancels(events)
    end
  end

  class Banner
    def active?
      OpenRange.new(self.begin, self.end).cover?(Date.today)
    end
  end

  def events(r)
    res = classes.collect { |c| c.events(r) }.flatten
    res += event.collect { |e| e.events(r) }.flatten
    res.sort { |a, b| a.time.begin <=> b.time.begin }
  end

  def on_load
    classes.each { |c| c.on_load }
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
