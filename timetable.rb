require 'date'
require 'nokogiri'
require_relative 'models'

module Timetable

class DayParser; end
class DateParser; end
class Cancel; end

class Document < XDSL::Element
  root :timetable

  element :banner do
    element :begin, ModelDate
    element :end, ModelDate
    element :message, String, required: true
  end

  element :annual, String, require: true
  elements :classes do
    element :image, String, required: true
    element :title, String, required: true
    element :info, String, required: true

    elements :schedule do
      element :timeshort, String, required: true
      element :announce
      elements :day, DayParser
      element :begin, ModelDate
      element :end, ModelDate
      elements :date, DateParser
    end

    elements :cancel, Cancel
    elements :hide, Cancel

    elements :changes do
      element :announce, String, required: true
      element :begin, ModelDate
      element :end, ModelDate
      elements :day, DayParser
      elements :date, DateParser
    end
  end

  elements :event do
    element :title, String, required: true
    elements :date, DateParser
    elements :cancel, Cancel
  end

  def events(d)
    res = (classes + event).collect { |x| x.events(d) }.flatten
    res = res.sort { |a, b| a.period.begin <=> b.period.begin }
    mark_conflicts(res)
  end

  def mark_conflicts(events)
    events.each_index do |i|
      next if events[i].cancelled?
      p = events[i].period
      j = i + 1
      while j < events.size and events[j].period.cross(p) and
        not events[j].cancelled? and
        events[i].place == events[j].place

        events[j].conflict = true
        events[i].conflict = true
        j += 1
      end
    end
  end
end

class OpenRange
  attr_reader :begin, :end

  def initialize(b, e)
    if b and e and e < b
      raise ModelException.new \
        "Дата окончания должна быть позднее даты начала"
    end
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
    if hour < 0 or hour > 23 or minute < 0 or minute > 59
      raise ArgumentError.new
    end
    @hour = hour
    @minute = minute
  end

  def to_s
    "%02d:%02d" % [ @hour, @minute ]
  end

  def self.parse(v)
    m = /^(\d{1,2}):(\d{1,2})$/.match(v)
    return nil if not m
    t = new(Integer(m[1]), Integer(m[2]))
    raise ArgumentError if t.to_s != v
    t
  end

  def <=>(time)
    to_minutes <=> time.to_minutes
  end

  def to_minutes
    @hour * 60 + @minute
  end
end

class Period
  attr_reader :begin, :end

  def initialize(b, e)
    raise ArgumentError if e <= b
    @begin = b
    @end = e
  end

  @@HideBegin = Time.parse("00:00")
  @@HideEnd = Time.parse("23:59")

  def self.parse(v)
    begin
      a = v.split('-')
      b = Time.parse(a[0]); e = nil
      return nil if not b
      if a.size == 1
        e = Time.new(b.hour + 2, b.minute)
      elsif a.size == 2
        e = Time.parse(a[1])
      end
      return nil if not e
      new(b, e)
    rescue ArgumentError
      raise ModelException.new \
        "Неправильный формат времени проведения: #{v}"
    end
  end

  def cross(p)
    not (p.begin > @end or p.end < @begin)
  end

  def to_s
    if @begin == @@HideBegin && @end == @@HideEnd
      return ""
    end
    "#{@begin} - #{@end}"
  end
end

module ParseHelper
  def parse_values(v)
    v.split(',').map { |v| v.strip }
  end

  def parse_periods(a)
    periods = []
    while a.first
      period = Period.parse(a.first)
      break if period.nil?
      periods << period
      a.shift
    end
    b = periods.collect { |p| p.begin }
    if b.sort != b
      raise ModelException.new \
        "Часы должны быть упорядочены. Более позднее должны идти правее"
    end
    periods
  end

  def parse_place(a)
    place = a.shift || 'Спартаковская'
    if not ['Спартаковская', 'Мытная', 'Весна'].include?(place)
      raise ModelException.new \
        "Место проведения должно быть либо 'Спартаковская' либо 'Мытная' "
        " либо 'Весна'"
    end
    place
  end

  def parse_check_tail(a)
    if not a.empty?
      raise ModelException.new "Лишние символы после места проведения"
    end
  end
end

class DayWeekly
  Days = [ 'Monday', 'Tuesday', 'Wednesday', 'Thursday',
           'Friday', 'Saturday', 'Sunday' ]

  attr_reader :cwday

  def initialize(cwday, mul = nil, start = nil)
    raise ArgumentError.new if mul and mul <= 1
    @cwday = cwday
    @mul = mul
    @start = start
  end

  def include?(d)
    d.cwday == @cwday and (not @mul or (Week.new(d) - Week.new(@start)) % @mul == 0)
  end

  def self.parse(v)
    begin
      a = v.split('/')
      cwday = Days.index(a[0])
      raise ArgumentError.new if not cwday
      cwday += 1
      return new(cwday) if a.size == 1
      raise ArgumentError.new if a.size != 3
      new(cwday, Integer(a[1]), ModelDate.parse(a[2]))
    rescue ArgumentError
      raise ModelException.new "Неправильный формат дня проведения: #{v}"
    end
  end

  def to_s
    @mul ? "#{@cwday}/#{@mul}/#{@start}" : "#{@cwday}"
  end
end

class DayDate
  attr_reader :date

  def initialize(date)
    @date = date
  end

  def self.parse(v)
    begin
      new(ModelDate.parse(v))
    rescue ArgumentError
      raise ModelException.new 'Неправильный формат даты проведения'
    end
  end

  def include?(d)
    @date == d
  end

  def to_s
    @date.to_s
  end
end


def DateParser.parse(v)
  Day.parse(v, DayDate)
end

def DayParser.parse(v)
  Day.parse(v, DayWeekly)
end

class Day
  extend ParseHelper

  attr_reader :day, :place, :periods

  def initialize(day, periods, place)
    @periods = periods
    @place = place
    @day = day
  end

  def self.parse(value, daytype)
    a = parse_values(value)

    day = daytype.parse(a.shift)
    periods = parse_periods(a)
    if periods.empty?
      raise ModelException.new \
        "Нет ни одного времени проведения занятий"
    end

    place = parse_place(a)
    parse_check_tail(a)

    new(day, periods, place)
  end

  def events
     @periods.collect { |p| EventLine.new(p, @place) }
  end

  def to_s
    "#{@day} #{@periods.join(' ')} #{@place}"
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
    a = parse_values(value)

    date = ModelDate.parse(a.shift)
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
    Utils::events(day + date, d)
  end

  def visible2weeks?(b)
    week_range.cover?(b) or week_range.cover?(b.next)
  end

  def check_date_order
    Utils::check_order(date.collect { |d| d.day.date })
    Utils::check_order(day.collect { |d| d.day.cwday })
  end
end

module Utils
  def self.mark_cancels(date, events, cancels)
    cans = cancels.select { |c| c.date == date }
    events.each { |e| e.cancelled = cans.any? { |c| c.affect?(e) } }
  end

  def self.events(days, d)
    days.select { |x| x.day.include?(d) }.collect { |x| x.events }.flatten
  end

  def self.neighbours(a)
    p = a.clone; p.pop
    n = a.clone; n.shift
    p.zip(n)
  end

  def self.check_order(d)
    if d.sort != d
      raise ModelException.new \
        "Элементы с датами и днями недели должны быть упорядочены. " \
        "Более поздние должны идти ниже"
    end
  end
end

class Schedule
  include WeekBorders
  include DayDates

  def visible?(week)
    not actual?(week) and visible2weeks?(week)
  end

  def doc_check
    check_date_order
  end
end

class Changes
  include DayDates
  include WeekBorders

  def doc_check
    check_range_finite
    check_date_order
    range
  end

  def check_range_finite
    if not self.begin or not self.end
      raise ModelException.new \
        "Изменения должны иметь начало и конец"
    end
  end

  def visible?(week)
    visible2weeks?(week)
  end
end

class Classes
  include WeekBorders

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
    v = (changes + schedule).select { |c| c.visible?(week) }
    v.collect { |a| a.announce }.compact
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

  def doc_check
    if changes.size > 1
      if Utils::neighbours(changes).any? { |v| not v[0].range.right?(v[1].begin) }
        raise ModelException.new \
          "Изменения не должны перекрываться по времени и " \
          "более поздние должны идти ниже более ранних"
      end
    end

    if schedule.size > 1
      Utils::neighbours(schedule).each do |v|
        p = v[0]; n = v[1]
        if not n.begin
          raise ModelException.new \
            "План расписания начиная со второго должен иметь дату начала"
        end
        if not n.announce
          raise ModelException.new \
            "План расписания начиная со второго должен иметь "\
            "объявление изменений"
        end
        if p.end
          raise ModelException.new \
            "План расписания кроме последнего не должен иметь даты окончания"
        end
        if p.begin and n.begin <= p.begin
          raise ModelException.new \
            "Более поздние расписания должны идти ниже более ранних"
        end
        p.end = n.begin - 1
      end
    end

    Utils::check_order(cancel.collect { |c| c.date })
    Utils::check_order(hide.collect { |h| h.date })
  end
end

class Event
  def events(d)
    events = Utils::events(date, d)
    events.each { |e| e.title = title }
    Utils.mark_cancels(d, events, cancel)
  end

  def doc_check
    Utils::check_order(cancel.collect { |c| c.date })
    Utils::check_order(date.collect { |d| d.day.date })
  end
end

class Banner
  def active?(week)
    b = self.begin ? Week.new(self.begin) : nil
    e = self.end ? Week.new(self.end) : nil
    OpenRange.new(b, e).cover?(week)
  end
end

end # module Timetable
