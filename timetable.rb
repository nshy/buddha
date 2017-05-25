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

  def events(d)
    res = classes.collect { |c| c.events(d) }.flatten
    res += event.collect { |e| e.events(d) }.flatten
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
  attr_accessor :title, :period, :place

  attr_writer :conflict, :cancelled

  def initialize(period, place)
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
    "#{@time} #{@title} #{@place}"
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

  def self.parse(v)
    m = /^(\d{2}):(\d{2})$/.match(v)
    return nil if not m
    new(m[1].to_i, m[2].to_i)
  end

  def <=>(time)
    to_minutes <=> time.to_minutes
  end

  def to_minutes
    @hour * 24 + @minute
  end
end

class Period
  attr_reader :begin, :end

  def initialize(b, e)
    @begin = b
    @end = e
  end

  def self.parse(v)
    a = v.strip.split('-')
    b = Time.parse(a[0]); e = nil
    return nil if not b
    if a.size == 1
      e = Time.new(b.hour + 2, b.minute)
    elsif a.size == 2
      e = Time.parse(a[1])
    end
    return nil if not e
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

  attr_reader :day, :place, :periods

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

  def include?(d)
    d.cwday == @day and (not @mul or (Week.new(d) - Week.new(@start)) % @mul == 0)
  end

  def events
     @periods.collect { |p| EventLine.new(p, @place) }
  end

  def to_s
    p = @periods.join(' ')
    @mul ?  "#{@day}/#{@mul}#/#{@start} #{p}" : "#{@day} #{p}"
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

  def include?(d)
    @date == d
  end

  def events
    @periods.collect { |p| EventLine.new(p, @place) }
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
    @periods.empty? || @periods.any? { |p| p.cross(e.period) }
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
  def range
    OpenRange.new(self.begin, self.end)
  end

  def events(d)
    return nil if not range.cover?(d)
    a = day.select { |x| x.include?(d) }.collect { |x| x.events }
    b = date.select { |x| x.include?(d) }.collect { |x| x.events }
    (a + b).flatten
  end
end

module Utils
  def self.mark_cancels(date, events, cancels)
    cans = cancels.select { |c| c.date == date }
    events.each { |e| e.cancelled = cans.any? { |c| c.affect?(e) } }
  end
end

class Schedule
  include WeekBorders
  include TimePosition
  include DayDates
end

class Changes
  include DayDates
  include WeekBorders
  include TimePosition
end

class Classes
  include WeekBorders
  include TimePosition

  def range
    OpenRange.new(schedule.first.range.begin, schedule.last.range.end)
  end

  def events(d)
    events = changes.reverse.collect { |c| c.events(d) }.find { |e| e }
    events = schedule.collect { |s| s.events(d) }.compact.flatten if not events
    return [] if not events

    Utils.mark_cancels(d, events, cancel)
    hides = hide.select { |h| h.date == d }
    events = events.select { |e| not hides.any? { |h| h.affect?(e) } }
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
  def events(d)
    events = date.select { |x| x.include?(d) }.collect { |x| x.events }.flatten
    events.each { |e| e.title = title }
    Utils.mark_cancels(d, events, cancel)
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
