require_relative 'xmldsl'

class TeachingsDocument < XDSL::Element
  element :title
  element :year
  elements :theme do
    element :title
    element :buddha_node
    elements :record do
      element :description
      element :record_date
      element :audio_url
      element :audio_size
      element :video_url
      element :video_size
      element :youtube_id
    end
  end

  def begin_date
    t = theme.min { |a, b| a.begin_date <=> b.begin_date }
    t.begin_date
  end

  class Theme
    def begin_date
      r = record.min do |a, b|
        Date.parse(a.record_date) <=> Date.parse(b.record_date)
      end
      Date.parse(r.record_date)
    end
  end
end

class BookDocument < XDSL::Element
  element :title
  elements :author
  elements :translator
  element :year
  element :isbn
  element :publisher
  element :amount
  element :annotation
  element :contents
  element :outer_id
end

class BookCategoryDocument < XDSL::Element
  element :name
  elements :category
  elements :subcategory
  elements :parent
  elements :child
  elements :group do
    element :name
    elements :book
  end
end

class LibraryDocument < XDSL::Element
  elements :section do
    element :name
    elements :category
  end
  element :recent do
    elements :book
  end
end

class TimeUpdateDocument < XDSL::Element
  element :update do
    element :publish_date
    element :message
  end
end

class TimetableDocument < XDSL::Element
  element :banner do
    element :begin
    element :end
    element :message
  end
  element :annual
  elements :event do
    element :title
    element :date
    element :begin
    element :end
    element :cancel
  end
  elements :classes do
    element :image
    element :title
    element :info
    element :timeshort
    elements :day
    element :begin
    element :end
    elements :cancel
    elements :date
  end
end

class MenuDocument < XDSL::Element
  elements :item do
    element :name
    element :title
    element :link
    elements :subitem do
      element :title
      element :link
    end
  end
end

class QuotesDocument < XDSL::Element
  elements :quote
end
