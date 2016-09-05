require 'date'
require 'nokogiri'
require_relative 'models'

def timetable_event_events(timetable, date_begin, date_end)
  events = []
  timetable.event.each do |event|
    date = Date.parse(event.date)
    next if date < date_begin or date > date_end
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

def timetable_classes_events(timetable, date_begin, date_end)
  events = []
  timetable.classes.each do |classes|
    classes_begin = classes_border(classes.begin, date_begin)
    classes_end = classes_border(classes.end, date_end)
    classes_begin = date_begin > classes_begin ? date_begin : classes_begin
    classes_end = date_end < classes_end ? date_end : classes_end
    next if classes_end < classes_begin
    cancels = classes.cancel.collect { |cancel| Date.parse(cancel) }
    classes.timetable.each do |timetable|
      cwday = Date.parse(timetable.day).cwday
      classes_begin.step(classes_end).each do |date|
        next if date.cwday != cwday
        strdate = date.strftime('%Y-%m-%d')
        events << {
          title: classes.title,
          begin: DateTime.parse("#{strdate} #{timetable.begin}"),
          end: DateTime.parse("#{strdate} #{timetable.end}"),
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

def week_begin(date)
  date - ((date.wday - 1) % 7)
end

def week_end(date)
  week_begin(date) + 6
end
