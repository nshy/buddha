#!/usr/bin/ruby

module Cache

archive = DB[:teachings].
            join(:themes, teaching_id: :id).
            join(:records, theme_id: :id).
              select_group(Sequel[:teachings][:id]).
              select_append(Sequel[:teachings][:title]).
              select_append{ min(record_date).as(begin_date) }.
                order(:begin_date).reverse

themes = DB[:themes].
            join(:records, theme_id: :id).
              select_group(Sequel[:themes][:id]).
              select_append(Sequel[:themes][:title], :teaching_id).
              select_append{ count(records[:id]).as(count) }.
              select_append{ min(record_date).as(begin_date) }.
                order(:begin_date)


# --------------------- teachings --------------------------

class Teaching < Sequel::Model(archive.from_self)
  set_primary_key :id

  one_to_many :themes

  def date
    Date.parse(begin_date())
  end

  dataset_module do
    def archive()
      eager(:themes).all
    end
  end
end

class Theme < Sequel::Model(themes.from_self)
  set_primary_key :id

  many_to_one :teaching
end

class Record < Sequel::Model

  dataset_module do
    def latest(num)
      order(:record_date).reverse.limit(num).all
    end
  end
end


# --------------------- news --------------------------
#
class News < Sequel::Model
  alias_method :cut_plain, :cut
  alias_method :scripts_plain, :scripts

  def has_more
    not cut_plain.nil?
  end

  def cut
    cut_plain.nil? ? body : cut_plain
  end

  def scripts
    scripts_plain ? page_scripts(YAML.load(scripts_plain)) : []
  end

  dataset_module do
    def years
      select{strftime('%Y', date).as(:year)}.distinct.map(:year).reverse
    end

    def latest(num)
      order(:date).limit(num).reverse.all
    end

    def by_id(id)
      where(id: id).first
    end

    def by_year(year)
      where{{strftime('%Y', date) => year}}.order(:date).reverse.all
    end
  end
end

# --------------------- books --------------------------

# create table mapping category id to its 'direct' size
# direct means only books of category itself are counted
category_sizes =
  DB[:book_categories].
  join(:category_books, category_id: Sequel[:book_categories][:id]).
  join(:books, id: Sequel[:category_books][:book_id]).
    select_group(:category_id).
    select_append{ count(Sequel[:books][:id]).as(:count) }

# extra construction to calculate full size of category
# creates table 'id, child id' so that for every
# category we have list of direct/indirect subcategories
# to count for full size
sources = DB[:sources].with_recursive(
            :sources,
            DB[:book_categories].
              select(:id, Sequel::as(:id, :source_id)),
            DB[:category_subcategories].
              join(:sources, source_id: Sequel[:category_subcategories][:category_id]).
                select(Sequel[:category_subcategories][:category_id],
                       Sequel[:category_subcategories][:subcategory_id]),
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
    join(category_sizes_full, id: Sequel[:book_categories][:id]).
      select(Sequel[:book_categories][:id], :name, :count).
        from_self(alias: :book_categories)

class Category < Sequel::Model(book_categories_sizes)
  set_primary_key :id
  many_to_many :parents,
                  left_key: :subcategory_id,
                  right_key: :category_id,
                  join_table: :category_subcategories,
                  :class => self,
                  :select => [Sequel[:book_categories][:id], :name, :count]

  many_to_many :children,
                  left_key: :category_id,
                  right_key: :subcategory_id,
                  join_table: :category_subcategories,
                  :class => self,
                  :select => [Sequel[:book_categories][:id], :name, :count]

  many_to_many :books,
                  left_key: :category_id,
                  right_key: :book_id,
                  join_table: :category_books,
                  class: '::Cache::Book',
                  :select => [:id, :title, :authors, Sequel[:category_books][:group]]

  def books_by_group
    books.group_by { |b| b.group }
  end

  dataset_module do
    def find(id)
      eager(:children, :parents, :books).
                where(Sequel[:book_categories][:id] => id).first
    end
  end
end

class Book < Sequel::Model
  set_primary_key :id
  many_to_many :categories,
                  left_key: :book_id,
                  right_key: :category_id,
                  join_table: :category_books,
                  class: Category,
                  :select => [Sequel[:book_categories][:id], :name, :count]

  def group
    self[:group]
  end

  dataset_module do
    def recent(num)
      order(:added).reverse.limit(num)
    end

    def find(id)
      eager(:categories).where(:id => id).first
    end
  end
end

# --------------------- digests --------------------------

class Digest_SHA1 < Sequel::Model
end

class Digest_UUID < Sequel::Model
end

# --------------------- error --------------------------

class Error < Sequel::Model
end

end
