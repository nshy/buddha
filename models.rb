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
