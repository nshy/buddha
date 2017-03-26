require 'date'
require 'nokogiri'
require_relative 'models'

# both dates are included
def timetable_events(timetable, date_begin, date_end)
  events = []
  timetable.classes.each do |classes|
    classes_begin = classes.begin or date_begin
    classes_end = classes.end or date_end
    classes_begin = date_begin > classes_begin ? date_begin : classes_begin
    classes_end = date_end < classes_end ? date_end : classes_end
    next if classes_end < classes_begin
    classes.day.each do |day|
      classes_begin.step(classes_end).each do |date|
        w = Week.new(date)
        next if date.cwday != day.day
        events << {
          title: classes.title,
          begin: day.begin(w),
          end: day.end(w),
          place: day.place,
          cancel: classes.cancel.include?(date)
        }
      end
    end
    classes.date.each do |date|
      next if date.date < date_begin or date.date > date_end
      date.times.each do |t|
        events << {
          title: classes.title,
          begin: t[:begin],
          end: t[:end],
          place: 'Спартаковская',
          cancel: classes.cancel.include?(date.date)
        }
      end
    end
  end
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
    conflicts = conflicts.select do |candidate|
      (not candidate[:cancel]) and (candidate[:place] == event[:place])
    end
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
