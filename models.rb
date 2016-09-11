require_relative 'xmldsl'

class ArchiveDocument < XDSL::Element
  element :archive do
    elements :year do
      element :year
      elements :teachings
    end
  end
end

class TeachingsDocument < XDSL::Element
  element :teachings do
    element :title
    element :year
    elements :theme do
      element :title
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
  end
end

class BookDocument < XDSL::Element
  element :book do
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
end

class BookCategoryDocument < XDSL::Element
  element :category do
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
end

class LibraryDocument < XDSL::Element
  element :library do
    elements :section do
      element :name
      elements :category
    end
    element :recent do
      elements :book
    end
  end
end

class TimetableDocument < XDSL::Element
  element :timetable do
    elements :event do
      element :title
      element :date
      element :begin
      element :end
      element :cancel
    end
    elements :classes do
      element :title
      elements :timetable do
        element :day
        element :begin
        element :end
      end
      element :begin
      element :end
      elements :cancel
    end
  end
end

class TimeUpdateDocument < XDSL::Element
  element :update do
    element :publish_date
    element :message
  end
end

class TeachersDocument < XDSL::Element
  element :teachers do
    elements :teacher do
      element :name
      element :page
      element :image
      element :presentation
    end
  end
end

class ClassesDocument < XDSL::Element
  element :classes do
    elements :classes do
      element :title
      element :description
      element :timetable
      element :page
      element :image
    end
  end
end
