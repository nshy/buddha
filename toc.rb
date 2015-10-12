module TOC
module Parse

class Element
  def empty?
    false
  end

  def heading?
    false
  end

  def bookmark?
    false
  end
end

class EmptyLine < Element
  def empty?
    true
  end

  def format
    ''
  end
end

class Heading < Element
  attr_reader :indent

  def initialize(lines, indent)
    raise 'Empty heading' if lines.empty?
    @lines = lines
    @indent = indent
  end

  def heading?
    true
  end

  def format
    first = ' ' * (2 * @indent) + @lines.first
    others = @lines.slice(1..-1).collect do |line|
      ' ' * (2 * @indent + 1) + line
    end
    [ first, others ].flatten
  end

  def text
    @lines.join ' '
  end

  def lines_info
    @lines.collect { |line| line.split(' ').size }
  end
end

class Bookmark < Element
  attr_reader :text

  def initialize(text)
    @text = text
  end

  def bookmark?
    true
  end

  def format
    @text
  end
end

module State

class Normal
  def initialize(block)
    @block = block
  end

  def empty
      @block.call EmptyLine.new
      self
  end

  def bookmark(text)
      @block.call Bookmark.new text
      self
  end

  def heading(text, indent)
    MultiLine.new @block, text, indent
  end

  def multiline(text)
      raise ParseException.new "dangling multiline: #{text}"
  end

  def finish
  end
end

class MultiLine
  def initialize(block, text, indent)
    @block = block
    @lines = [ text ]
    @indent = indent
  end

  def empty
    yield_heading
    @block.call EmptyLine.new
    Normal.new @block
  end

  def bookmark(text)
    yield_heading
    @block.call Bookmark.new text
    Normal.new @block
  end

  def heading(text, indent)
    yield_heading
    MultiLine.new @block, text, indent
  end

  def multiline text
    @lines << text
  end

  def finish
    yield_heading
  end

private

  def yield_heading
      @block.call Heading.new @lines, @indent
  end
end

end # module State
end # module Parse

def TOC.parse text, &block
  current = 0
  state = Parse::State::Normal.new block
  text.each_line do |line|
    line = line.gsub /\n$/, ''
    if line.empty?
      state = state.empty
      next
    end
    d = /(?<indent>\s*)(?<text>.*)/.match line
    if not /[^ ]/.match(d[:indent]).nil?
      raise "Only spaces are allowed to indent: #{d[:indent].dump}#{d[:text]}"
    end
    indent = d[:indent].size
    if indent == (current + 1)
      state.multiline d[:text]
      next
    end
    if (indent % 2) != 0
      raise "Use multiple of 2 spaces to indent: '#{line}'"
    end
    if d[:text].start_with? '#'
      if indent != 0
        raise "Bookmark should have zero indent: '#{line}'"
      end
      state = state.bookmark d[:text]
      next
    end
    if (indent - current) > 2
      raise "Use 2 spaces to indent sublevel: '#{line}'"
    end
    state = state.heading d[:text], indent / 2
    current = indent
  end
  state.finish
end

class Heading
  attr_reader :name, :children

  def self.parse text
    path = [ Heading.new(nil) ]
    TOC.parse text do |element|
      next if element.empty? or element.bookmark?
      node = Heading.new element.text
      step = element.indent - path.size + 1
      if step == 1
        parent = path.last.children.last
        path << parent
      elsif step == 0
        parent = path.last
      else
        path = path.slice 0...step
        parent = path.last
      end
      parent.children << node
    end
    path.first
  end

private
  def initialize(name)
    @name = name
    @children = []
  end

end

end # module TOC
