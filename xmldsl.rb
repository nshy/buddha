module XDSL

module ElementClass
  def element(name, &block)
    if not block.nil?
      klass = Class.new(Element)
      klass.instance_eval(&block)
      define_method(name) do
        child = @element.at_xpath(name.to_s)
        return nil if child.nil?
        klass.new(child)
      end
    else
      define_method(name) do
        e = @element.at_xpath("#{name.to_s}")
        return e.text if not e.nil?
        nil
      end
    end
  end

  def elements(name, &block)
    if not block.nil?
      klass = Class.new(Element)
      klass.instance_eval(&block)
      define_method(name) do
        ElementSet.new(@element.xpath(name.to_s), klass)
      end
    else
      define_method(name) do
        @element.xpath("#{name.to_s}").map { |e| e.text }
      end
    end
  end
end

class Element
  extend ElementClass

  def initialize(element)
    @element = element
  end
end

class ElementSet
  include Enumerable

  def initialize(set, klass)
    @set = set
    @klass = klass
  end

  def each
    @set.each do |e|
      yield @klass.new(e)
    end
  end

  def size
    @set.size
  end
end

end # module XDSL
