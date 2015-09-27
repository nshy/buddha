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
