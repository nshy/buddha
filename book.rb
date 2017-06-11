require_relative 'xmldsl'

def join_no_empty(a)
  return nil if a.empty?
  a.join(', ')
end

class BookHeadings
  def self.parse(text)
    return nil if not text or text.empty?
    headings = []
    stack = [ headings ]
    text.each_line do |line|
      original = line
      next if line.strip.empty? or line.start_with?('#')
      indent = line.index(/[^ ]/)
      if line[indent] == "\t"
        raise ModelException.new \
          "Строка:\n#{original}Табуляция не допускается, только пробелы."
      end
      line = line.strip
      level = stack.size - 1
      if indent == (2 * level + 1)
        headings.last[:name] << ' ' << line
      elsif indent % 2 == 1
        raise ModelException.new \
          "Строка:\n#{original}Используйте два пробела для организации" \
          "дерева заголовков."
      end
      indent /= 2
      if indent == level + 1
        headings = headings.last[:children]
        stack << headings
      elsif indent < level
        headings = stack[indent]
        stack = stack.slice(0..indent)
      elsif indent != level
        raise ModelException.new \
          "Строка:\n#{original}Используйте два пробела для организации" \
          " дерева заголовков."
      end
      headings << { name: line, children: [] }
      level = stack.size - 1
    end
    stack.first
  end
end

module Book

class Document < XDSL::Element
  root :book
  element :title, String, required: true
  elements :author
  elements :translator
  element :year
  element :isbn
  element :publisher
  element :amount
  element :annotation
  element :contents
  element :added
  element :outer_id
  elements :links
  elements :attachments

  def doc_check
    begin
      BookHeadings.parse(contents)
    rescue ModelException => e
      raise ModelException.new \
        "Элемент content содержит ошибки:\n#{e}"
    end
  end

  def translators
    join_no_empty(translator)
  end

  def authors
    join_no_empty(author)
  end
end

end # module Book
