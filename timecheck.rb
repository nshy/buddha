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

def print_event_interval(event)
   "#{event[:begin].strftime('%H:%M')}-#{event[:end].strftime('%H:%M')}"
end

event_each_conflict(events) do |event, conflicts|
  puts "#{event[:title]} "\
       "#{event[:begin].strftime('%Y-%m-%d')} "\
       "#{print_event_interval(event)}"
  conflicts.each do |conflict|
    puts "  #{conflict[:title]} #{print_event_interval(conflict)}"
  end
end
