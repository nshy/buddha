require 'nokogiri'

module XDSL

module ElementClass

  attr_reader :parsers

  def element(name, scalar_klass = nil, &block)
    @parsers ||= {}

    if block_given?
      throw "klass and block cannot be set both" if not scalar_klass.nil?
      klass = define_klass(name, &block)
      add_parser(name) { |e| klass.new(e) }
    else
      add_parser(name) do |e|
        t = e.text.strip
        if not scalar_klass.nil?
          scalar_klass.parse(t)
        elsif not t.empty?
          t
        else
          nil
        end
      end
    end

    add_getter(name)
  end

  def elements(name, &block)
    @parsers ||= {}

    if block_given?
      klass = define_klass(name, &block)
      add_set_parser(name) { |c| klass.new(c) }
    else
      add_set_parser(name) { |c| c.text }
    end

    add_getter(name)
  end

  def load(path)
    doc = nil
    File.open(path) do |file|
      doc = new(Nokogiri::XML(file).root)
    end
    doc
  end

private

  def define_klass(name, &block)
    klass = Class.new(Element)
    const_set(name.capitalize, klass)
    klass.instance_eval(&block)
    klass
  end

  def add_getter(name)
    define_method(name) do
      @values[name]
    end
  end

  def add_set_parser(name, &block)
    @parsers[name] = lambda do |element|
      element.xpath(name.to_s).map { |c| block.call(c) }
    end
  end

  def add_parser(name, &block)
    @parsers[name] = lambda do |element|
      e = element.at_xpath(name.to_s)
      e.nil? ? nil : block.call(e)
    end
  end

end

class Element
  extend ElementClass

  attr_reader :values

  def initialize(element)
    @values = {}
    self.class.parsers.each do |name, parser|
      @values[name] = parser.call(element)
    end
  end

end

end # module XDSL
