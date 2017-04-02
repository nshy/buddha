#!/bin/ruby

require_relative 'timetable'

if ARGV.size < 1
  puts 'Usage: timecheck <year>'
  exit 1
end
year = ARGV[0]

timetable = TimetableDocument.load('data/timetable/timetable.xml')

date_begin = Date.parse("#{year}-01-01")
date_end = Date.parse("#{year}-12-31")
events = timetable.events(date_begin, date_end)

event_each_conflict(events) do |event, conflicts|
  puts "#{event[:title]} "\
       "#{event[:time].begin.strftime('%Y-%m-%d')} "\
       "#{event[:time].classes_time}"
  conflicts.each do |conflict|
    puts "  #{conflict[:title]} #{conflict[:time].classes_time}"
  end
end
