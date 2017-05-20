require 'nokogiri'

class ModelException < RuntimeError
  attr_accessor :document
end

module XDSL

module ElementClass

  attr_reader :parsers

  def element(name, scalar_klass = nil, options = {}, &block)
    @parsers ||= {}

    if block_given?
      throw "klass and block cannot be set both" if not scalar_klass.nil?
      klass = define_klass(name, &block)
      add_parser(name, options) { |e| klass.new(e) }
    else
      add_parser(name, options) do |e|
        t = e.text.strip
        if not scalar_klass.nil?
          scalar_klass.parse(t)
        else
          String.parse(e.inner_html)
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

  def root(root)
    @root = root
  end

  def load(path)
    return nil if not File.exists?(path)
    p = path.split('/')[1..-1].join('/')
    begin
      n = Nokogiri::XML(File.open(path)) { |config| config.strict }
    rescue Nokogiri::XML::SyntaxError => e
      raise ModelException.new("Нарушение xml синтаксиса в файле '#{p}': #{e}")
    end
    begin
      if n.root.name != @root.to_s
        raise ModelException.new "Неправильный корневой элемент #{n.root.path}"
      end
      doc = new(n.root)
    rescue ModelException => e
      raise ModelException.new("Нарушение формата в файле '#{p}': #{e}")
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

  def add_parser(name, options, &block)
    @parsers[name] = lambda do |element|
      e = element.at_xpath(name.to_s)
      v = e.nil? ? nil : block.call(e)
      if not v and options[:required]
        raise ModelException.new \
          "Подэлемент #{name} в элементе #{element.path}" \
          " должен присутствовать и иметь непустое значение"
      end
      v
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
    element.elements.each do |c|
      if not self.class.parsers.has_key?(c.name.to_sym)
        raise ModelException.new "Неизвестный элемент #{c.path}"
      end
    end
  end

end

end # module XDSL
