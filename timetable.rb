require 'date'
require 'nokogiri'
require_relative 'models'

def timetable_event_events(timetable, date_begin, date_end)
  events = []
  timetable.event.each do |event|
    next if event.date < date_begin or event.date > date_end
    events << {
      title: event.title,
      begin: DateTime.parse("#{event.date} #{event.begin}"),
      end: DateTime.parse("#{event.date} #{event.end}"),
      cancel: (not event.cancel.nil?)
    }
  end
  events
end

def classes_border(date, border)
  return border if date.nil?
  border = Date.parse(date)
end

def timetable_parse_classes_day(daytime)
  r = /([[:alpha:]]+)\s*,\s*(\d{2}:\d{2})-(\d{2}:\d{2})/.match(daytime)
  { day: r[1], begin: r[2], end: r[3] }
end

def timetable_parse_classes_date(datetime)
  a = datetime.split(',')
  date = a.shift.strip
  times = a.collect do |i|
    r = /(\d{2}:\d{2})-(\d{2}:\d{2})/.match(i)
    { begin: r[1], end: r[2] }
  end
  { date: date, times: times }
end

def timetable_classes_events(timetable, date_begin, date_end)
  events = []
  timetable.classes.each do |classes|
    classes_begin = classes_border(classes.begin, date_begin)
    classes_end = classes_border(classes.end, date_end)
    classes_begin = date_begin > classes_begin ? date_begin : classes_begin
    classes_end = date_end < classes_end ? date_end : classes_end
    next if classes_end < classes_begin
    cancels = classes.cancel.collect { |cancel| Date.parse(cancel) }
    classes.day.each do |daytime|
      d = timetable_parse_classes_day(daytime)
      cwday = Date.parse(d[:day]).cwday
      classes_begin.step(classes_end).each do |date|
        next if date.cwday != cwday
        strdate = date.strftime('%Y-%m-%d')
        events << {
          title: classes.title,
          begin: DateTime.parse("#{strdate} #{d[:begin]}"),
          end: DateTime.parse("#{strdate} #{d[:end]}"),
          cancel: cancels.include?(date)
        }
      end
    end
    classes.date.each do |day|
      d = timetable_parse_classes_date(day)
      date = Date.parse(d[:date])
      next if date < date_begin or date > date_end
      d[:times].each do |t|
        events << {
          title: classes.title,
          begin: DateTime.parse("#{d[:date]} #{t[:begin]}"),
          end: DateTime.parse("#{d[:date]} #{t[:end]}"),
          cancel: cancels.include?(date)
        }
      end
    end
  end
  events
end

# both dates are included
def timetable_events(timetable, date_begin, date_end)
  events = timetable_event_events(timetable, date_begin, date_end) +
           timetable_classes_events(timetable, date_begin, date_end)
  events.sort! do |a, b|
    a[:begin] <=> b[:begin]
  end
  events
end

def event_each_conflict(events)
  events.each_with_index do |event, index|
    next if event[:cancel]
    succ_events = events.drop(index + 1)
    conflicts = succ_events.take_while do |succ_event|
      event[:end] > succ_event[:begin]
    end
    conflicts = conflicts.select { |event| not event[:cancel] }
    next if conflicts.empty?
    yield event, conflicts
  end
end

def mark_event_conflicts(events)
  events.each { |event| event[:conflict] = false }
  event_each_conflict(events) do |event, conflicts|
    event[:conflict] = true
    conflicts.each { |event| event[:conflict] = true }
  end
end

def events_week_partition(events)
  groups = events.group_by { |event| (event[:begin].wday - 1) % 7 }
  partition = []
  (0..6).each do |day|
    partition << (groups.has_key?(day) ? groups[day] : [])
  end
  partition
end
