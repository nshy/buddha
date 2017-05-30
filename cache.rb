#!/bin/ruby

module Cache

DB = DbMain[:db]

archive = DB[:teachings].
            join(:themes, teaching_id: :id).
            join(:records, theme_id: :id).
              select_group(:teachings__id).
              select_append(:teachings__title).
              select_append{ min(record_date).as(begin_date) }.
                order(:begin_date).reverse

themes = DB[:themes].
            join(:records, theme_id: :id).
              select_group(:themes__id).
              select_append(:themes__title, :teaching_id).
              select_append{ count(records__id).as(count) }.
              select_append{ min(record_date).as(begin_date) }.
                order(:begin_date)


# --------------------- teachings --------------------------

class Teaching < Sequel::Model(archive)
  set_primary_key :id

  one_to_many :themes

  def date
    Date.parse(begin_date())
  end

  def Teaching.archive()
    eager(:themes).all
  end
end

class Theme < Sequel::Model(themes)
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

  def News.by_id(id)
    where(id: id).first
  end

  def News.by_year(year)
    where{{strftime('%Y', date) => year}}.order(:date).reverse.all
  end
end

# --------------------- books --------------------------

# create table mapping category id to its 'direct' size
# direct means only books of category itself are counted
category_sizes =
  DB[:book_categories].
  join(:category_books, category_id: :book_categories__id).
  join(:books, id: :category_books__book_id).
    select_group(:category_id).
    select_append{ count(:books__id).as(:count) }

# extra construction to calculate full size of category
# creates table 'id, child id' so that for every
# category we have list of direct/indirect subcategories
# to count for full size
sources = DB[:sources].with_recursive(
            :sources,
            DB[:book_categories].
              select(:id, Sequel::as(:id, :source_id)),
            DB[:category_subcategories].
              join(:sources, source_id: :category_subcategories__category_id).
                select(:category_subcategories__category_id,
                       :category_subcategories__subcategory_id),
            union_all: false)

# this table is 'id, count' with full sizes of categories
category_sizes_full =
  sources.
    join(category_sizes, category_id: :source_id).
      select_group(:id).
      select_append{ sum(:count).as(:count) }

# this table is 'id, name, count' category table
# so all tech columnts are filtered out and count column is added
book_categories_sizes =
  DB[:book_categories].
    join(category_sizes_full, id: :book_categories__id).
      select(:book_categories__id, :name, :count)

class Category < Sequel::Model(book_categories_sizes)
  set_primary_key :id
  many_to_many :parents,
                  left_key: :subcategory_id,
                  right_key: :category_id,
                  join_table: :category_subcategories,
                  :class => self,
                  :select => [:book_categories__id, :name, :count]

  many_to_many :children,
                  left_key: :category_id,
                  right_key: :subcategory_id,
                  join_table: :category_subcategories,
                  :class => self,
                  :select => [:book_categories__id, :name, :count]

  many_to_many :books,
                  left_key: :category_id,
                  right_key: :book_id,
                  join_table: :category_books,
                  class: '::Cache::Book',
                  :select => [:id, :title, :authors, :category_books__group]

  def books_by_group
    books.group_by { |b| b.group }
  end

  def Category.find(id)
    Category.eager(:children, :parents, :books).
              where(:book_categories__id => id).first
  end
end

class Book < Sequel::Model
  many_to_many :categories,
                  left_key: :book_id,
                  right_key: :category_id,
                  join_table: :category_books,
                  class: Category,
                  :select => [:book_categories__id, :name, :count]

  def group
    self[:group]
  end

  def Book.recent(num)
    order(:added).reverse.limit(num)
  end

  def Book.find(id)
    eager(:categories).where(:id => id).first
  end
end

class Section
  attr_reader :categories, :name

  def initialize(section)
    @name = section.name
    cats = Category.where(:book_categories__id => section.category).all
    cats = cats.map { |c| [ c.id, c ] }.to_h
    @categories = section.category.map { |id| cats[id] }
  end

  def Section.load(path)
    library = Library::Document.load(path)
    library.section.map { |s| Section.new(s) }
  end
end

# --------------------- digests --------------------------

class Digest < Sequel::Model
end

# --------------------- error --------------------------

class Error < Sequel::Model
end

end
