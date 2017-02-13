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

# --------------------- books --------------------------

# create table mapping category url to its 'direct' size
# direct means only books of category itself are counted
category_sizes =
  DB[:book_categories].
  join(:category_books, category_id: :book_categories__url).
  join(:books, url: :category_books__book_id).
    select_group(:category_id).
    select_append{ count(:books__url).as(:count) }

# extra construction to calculate full size of category
# creates table 'url, child url' so that for every
# category we have list of direct/indirect subcategories
# to count for full size
sources = DB[:sources].with_recursive(
            :sources,
            DB[:book_categories].
              select(:url, Sequel::as(:url, :source_id)),
            DB[:category_subcategories].
              join(:sources, source_id: :category_subcategories__category_id).
                select(:category_subcategories__category_id,
                       :category_subcategories__subcategory_id),
            union_all: false)

# this table is 'url, count' with full sizes of categories
category_sizes_full =
  sources.
    join(category_sizes, category_id: :source_id).
      select_group(:url).
      select_append{ sum(:count).as(:count) }

# this table is 'url, name, count' category table
# so all tech columnts are filtered out and count column is added
book_categories_sizes =
  DB[:book_categories].
    join(category_sizes_full, url: :book_categories__url).
      select(:book_categories__url, :name, :count)
DB.create_view(:book_categories_sizes, book_categories_sizes, temp: true)

class Category < Sequel::Model(:book_categories_sizes)
  set_primary_key :url
  many_to_many :parents,
                  left_key: :subcategory_id,
                  right_key: :category_id,
                  join_table: :category_subcategories,
                  :class => self

  many_to_many :children,
                  left_key: :category_id,
                  right_key: :subcategory_id,
                  join_table: :category_subcategories,
                  :class => self

  many_to_many :books,
                  left_key: :category_id,
                  right_key: :book_id,
                  join_table: :category_books,
                  class: '::Cache::Book',
                  :select => [:url, :title, :authors, :category_books__group]

  def books_by_group
    books.group_by { |b| b.group }
  end

  def Category.find(url)
    Category.eager(:children, :parents, :books).
              where(:url => url).first
  end
end

class Book < Sequel::Model
  many_to_many :categories,
                  left_key: :book_id,
                  right_key: :category_id,
                  join_table: :category_books,
                  class: Category

  def group
    self[:group]
  end

  def Book.recent(num)
    order(:added).reverse.limit(num)
  end

  def Book.find(url)
    eager(:categories).where(:url => url).first
  end
end

sections = DB[:top_categories].select(Sequel::as(:section, :name)).distinct

class Section < Sequel::Model(sections)
  set_primary_key :name

  many_to_many :categories,
                  left_key: :section,
                  right_key: :category_id,
                  join_table: :top_categories,
                  class: Category

  def Section.all
    eager(:categories).all
  end
end

end
