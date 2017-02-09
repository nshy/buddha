#!/bin/ruby

archive = DB[:teachings].
            join(:themes, teaching_id: :id).
            join(:records, theme_id: :id).
              select_group(:teachings__id).
              select_append(:teachings__title, :url).
              select_append{ min(record_date).as(begin_date) }.
                order(:begin_date).reverse

DB.create_view(:archive_teachings, archive, temp: true)

themes = DB[:themes].
            join(:records, theme_id: :id).
              select_group(:themes__id).
              select_append(:themes__title, :teaching_id).
              select_append{ count(records__id).as(count) }.
              select_append{ min(record_date).as(begin_date) }.
                order(:begin_date)
DB.create_view(:archive_themes, themes, temp: true)

module Cache

class Teaching < Sequel::Model(:archive_teachings)
  set_primary_key :id

  one_to_many :themes

  def date
    Date.parse(begin_date())
  end
end

class Theme < Sequel::Model(:archive_themes)
  set_primary_key :id

  many_to_one :teaching
end

class Record < Sequel::Model
end

def Cache.archive()
  Teaching.eager(:themes).all
end

def Cache.last_records()
  Record.order(:record_date).reverse.limit(5).all
end

end

