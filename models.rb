require_relative 'xmldsl'

class ArchiveDocument < XDSL::Element
  element :archive do
    elements :teachings do
      element :title
      element :year
      elements :theme do
        element :title
        element :page
      end
    end
  end
end

class ThemeDocument < XDSL::Element
  element :theme do
    element :title
    element :year
    elements :record do
      element :description
      element :record_date
      element :audio_url
      element :video_url
      element :youtube_id
    end
  end
end

class NewsDocument < XDSL::Element
  element :news do
    element :title
    element :publish_date
    element :buddha_node
    element :body
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
    elements :parent
    elements :child
    elements :group do
      element :name
      elements :book
    end
  end
end
