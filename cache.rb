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

# --------------------- teachings --------------------------

class Teaching < Sequel::Model(:archive_teachings)
  set_primary_key :id

  one_to_many :themes

  def date
    Date.parse(begin_date())
  end

  def Teaching.archive()
    eager(:themes).all
  end
end

class Theme < Sequel::Model(:archive_themes)
  set_primary_key :id

  many_to_one :teaching
end

class Record < Sequel::Model

  def Record.latest(num)
    order(:record_date).reverse.limit(num).all
  end
end


# --------------------- news --------------------------
#
class News < Sequel::Model
  alias_method :cut_plain, :cut

  def style
    return nil if not is_dir
    path = "data/news/#{url}/style.css"
    return nil if not File.exists?(path)
    "/news/#{url}/style.css"
  end

  def has_more
    not cut_plain.nil?
  end

  def cut
    cut_plain.nil? ? body : cut_plain
  end

  def News.years
    select{strftime('%Y', date).as(:year)}.distinct.map(:year).reverse
  end

  def News.latest(num)
    order(:date).limit(num).reverse.all
  end

  def News.by_url(url)
    where(url: url).first
  end

  def News.by_year(year)
    where{{strftime('%Y', date) => year}}.order(:date).reverse.all
  end
end

end
