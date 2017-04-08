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
events = timetable.events(date_begin..date_end)

def event_title_string(event)
  title = Nokogiri::HTML.fragment(event[:title]).text
  title.strip!
  title.gsub!(/\n/, '')
  title.gsub!(/ {2,}/, ' ')
  title
end

event_each_conflict(events) do |event, conflicts|
  puts "#{event_title_string(event)} "\
       "#{event[:time].begin.strftime('%Y-%m-%d')} "\
       "#{event[:time].classes_time}"
  conflicts.each do |conflict|
    puts "  #{event_title_string(conflict)} #{conflict[:time].classes_time}"
  end
end
