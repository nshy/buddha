require 'date'
require 'nokogiri'
require_relative 'models'

def event_each_conflict(events)
  events.each_with_index do |event, index|
    next if event[:cancel]
    succ_events = events.drop(index + 1)
    conflicts = succ_events.take_while do |succ_event|
      event[:time].end > succ_event[:time].begin
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
  groups = events.group_by { |event| (event[:time].begin.wday - 1) % 7 }
  partition = []
  (0..6).each do |day|
    partition << (groups.has_key?(day) ? groups[day] : [])
  end
  partition
end
