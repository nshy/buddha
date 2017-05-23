require 'date'
require 'nokogiri'
require_relative 'models'

module Timetable

class ClassesDay; end
class ClassesDate; end
class Cancel; end

class Document < XDSL::Element
  root :timetable

  element :banner do
    element :begin, ModelDate
    element :end, ModelDate
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
      element :begin, ModelDate
      element :end, ModelDate
      elements :date, ClassesDate
    end

    elements :cancel, Cancel
    elements :hide, Cancel

    elements :changes do
      element :announce
      element :begin, ModelDate
      element :end, ModelDate
      elements :day, ClassesDay
      elements :date, ClassesDate
    end
  end

  elements :event do
    element :title
    elements :date, ClassesDate
    elements :cancel, Cancel
  end

  def events(r)
    res = classes.collect { |c| c.events(r) }.flatten
    res += event.collect { |e| e.events(r) }.flatten
    res.sort { |a, b| a.period.begin <=> b.period.begin }
  end

  def on_load
    classes.each { |c| c.on_load }
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

class EventLine
  attr_accessor :title, :date, :period, :place

  attr_writer :conflict, :cancelled

  def initialize(date, period, place)
    @date = date
    @period = period
    @place = place
  end

  def conflict?
    @conflict
  end

  def cancelled?
    @cancelled
  end

  def to_s
    "#{@date} #{@time} #{@title} #{@place}"
  end
end

class Time
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

  def <=>(time)
    to_minutes <=> time.to_minutes
  end

  def to_minutes
    @hour * 24 + @minute
  end
end

class Period
  REGEXP = /\d{2}:\d{2}/

  attr_reader :begin, :end

  def initialize(b, e)
    @begin = b
    @end = e
  end

  def self.parse(value)
    a = value.strip.split('-')
    bs = a.shift
    return nil if not REGEXP.match(bs)
    b = Time.parse(bs)
    es = a.shift
    if es
      return nil if not REGEXP.match(es)
      e = Time.parse(es)
    else
      e = Time.new((b.hour + 2) % 24, b.minute)
    end
    new(b, e)
  end

  def cross(p)
    not (p.begin > @end or p.end < @begin)
  end

  def to_s
    "#{@begin} - #{@end}"
  end
end

module ParseHelper
  def parse_periods(a)
    periods = []
    while a.first
      period = Period.parse(a.first)
      break if period.nil?
      periods << period
      a.shift
    end
    periods
  end

  def parse_place(a)
    place = a.shift || 'Спартаковская'
    place.strip!
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

  def initialize(day, mul, start, periods, place)
    @day = day
    @mul = mul
    @start = start
    @periods = periods
    @place = place
  end

  def self.parse(value)
    mul = nil
    start = nil

    a = value.split(',')

    d = a.shift.strip.split('/')
    day = Date.parse(d.shift.strip).cwday
    if not d.empty?
      mul = d.shift.to_i
      start = Date.parse(d.shift)
    end

    periods = parse_periods(a)
    # for luck
    raise "Time must be specified" if periods.empty?

    place = parse_place(a)
    parse_check_tail(a)

    new(day, mul, start, periods, place)
  end

  def events(r)
    b = Week.new(r.begin)
    e = Week.new(r.end)
    weeks = b..e
    if @mul
      s = Week.new(@start)
      weeks = weeks.select { |w| (s - w) % @mul == 0 }
    end
    events = weeks.collect do |w|
      @periods.collect { |p| EventLine.new(w.day(@day), p, @place) }
    end
    events.flatten.select { |e| r.cover?(e.date) }
  end
end

class ClassesDate
  extend ParseHelper

  attr_reader :date, :periods, :place

  def initialize(date, periods, place)
    @date = date
    @periods = periods
    @place = place
  end

  def self.parse(value)
    a = value.split(',')

    date = Date.parse(a.shift.strip)

    periods = parse_periods(a)
    place = parse_place(a)
    parse_check_tail(a)

    new(date, periods, place)
  end

  def events(r)
    events = @periods.collect { |p| EventLine.new(@date, p, @place) }
    events.select { |e| r.cover?(e.date) }
  end
end

class Cancel
  extend ParseHelper

  attr_reader :date, :periods

  def initialize(date, periods)
    @periods = periods
    @date = date
  end

  def self.parse(value)
    a = value.split(',')

    date = Date.parse(a.shift.strip)
    periods = parse_periods(a)
    parse_check_tail(a)

    new(date, periods)
  end

  def affect?(e)
    @date == e.date && \
      (@periods.empty? || @periods.any? { |p| p.cross(e.period) })
  end
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
  def future?(week)
    week_range.left?(week)
  end

  def actual?(week)
    week_range.cover?(week)
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

module Utils
  def self.mark_cancels(events, cancels)
    events.each { |e| e.cancelled = cancels.any? { |c| c.affect?(e) } }
  end
end

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
  def apply_change(events, filtered, changes)
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

class Classes
  include WeekBorders
  include TimePosition

  def range
    OpenRange.new(schedule.first.range.begin, schedule.last.range.end)
  end

  def events(r)
    events = schedule.collect { |s| s.events(r) }.flatten
    changes.each { |c| events = c.apply(events, r) }
    Utils.mark_cancels(events, cancel)
    events = events.select { |e| not hide.any? { |h| h.affect?(e) } }
    events.each { |e| e.title = title }
  end

  def announces(week)
    a = changes.select { |c| c.actual?(week) or c.future?(week) } +
        schedule.select { |s| s.future?(week) }
    a.sort! { |a, b| a.range.begin <=> b.range.begin }
    a.collect { |a| a.announce }.join(' ')
  end

  def timeshort(week)
    if actual?(week)
      actual_schedule(week).timeshort
    else
      schedule.first.timeshort
    end
  end

  def actual_schedule(week)
    schedule.detect { |s| s.week_range.cover?(week) }
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
  def events(r)
    events = date.collect { |d| d.events(r) }.flatten
    events.each { |e| e.title = title }
    Utils.mark_cancels(events, cancel)
  end
end

class Banner
  def active?
    OpenRange.new(self.begin, self.end).cover?(Date.today)
  end
end

end # module Timetable

def mark_event_conflicts(events)
  events.each_index do |i|
    p = events[i].period
    j = i + 1
    while j < events.size and events[j].period.cross(p)
      events[j].conflict = true
      events[i].conflict = true
      j += 1
    end
  end
end
