module XDSL

module ElementClass
  def element(name, &block)
    if not block.nil?
      klass = Class.new(Element)
      klass.instance_eval(&block)
      define_method(name) do
        klass.new(@element.at_xpath(name.to_s))
      end
    else
      define_method(name) do
        @element.at_xpath(name.to_s).text
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
        @element.xpath("#{name.to_s}/text()")
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
end

end # module XDSL
