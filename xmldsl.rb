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
          e.inner_html
        else
          nil
        end
      end
    end

    add_accessors(name)
  end

  def elements(name, scalar_klass = nil, &block)
    @parsers ||= {}

    if block_given?
      throw "klass and block cannot be set both" if not scalar_klass.nil?
      klass = define_klass(name, &block)
      add_set_parser(name) { |c| klass.new(c) }
    else
      add_set_parser(name) do |c|
        if not scalar_klass.nil?
          scalar_klass.parse(c.text.strip)
        else
          c.text
        end
      end
    end

    add_accessors(name)
  end

  def load(path)
    return nil if not File.exists?(path)
    doc = nil
    File.open(path) do |file|
      doc = new(Nokogiri::XML(file).root)
    end
    doc.on_load if doc.respond_to? :on_load
    doc
  end

private

  def define_klass(name, &block)
    klass = Class.new(Element)
    const_set(name.capitalize, klass)
    klass.instance_eval(&block)
    klass
  end

  def add_accessors(name)
    define_method(name) do
      @values[name]
    end
    define_method("#{name}=".to_sym) do |v|
      @values[name] = v
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
