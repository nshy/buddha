require 'nokogiri'

class ModelException < RuntimeError
  attr_accessor :document
end

module XDSL

module ElementClass

  def add_element(name, multi, scalar_klass, options = {}, &block)
    if block_given?
      throw "klass and block cannot be set both" if not scalar_klass.nil?
      klass = Class.new(Element)
      const_set(name.capitalize, klass)
      klass.instance_eval(&block)
      scalar_parser = lambda { |e| klass.parse(e) }
    else
      scalar_parser = lambda do |e|
        t = e.inner_html.strip
        return nil if t.empty?
        return t if not scalar_klass
        begin
          scalar_klass.parse(t)
        rescue ArgumentError
          raise ModelException.new \
            "Элемент #{e.path}/#{name} имеет недопустимое значение '#{t}'"
        end
      end
    end

    if multi
      parser = lambda do |e|
        p = "#{e.path}/#{name}"
        a = e.xpath(name.to_s).map { |c| scalar_parser.call(c) }
        a.select { |v| v }
      end
    else
      parser = lambda do |e|
        c = e.at_xpath(name.to_s)
        v = nil
        v = scalar_parser.call(c) if c
        if not v and options[:required]
          raise ModelException.new \
            "Элемент #{e.path}/#{name} должен присутствовать " \
            "и иметь непустое значение"
        end
        v
      end
    end

    @parsers ||= {}
    @parsers[name] = parser

    define_method(name) do
      @values[name]
    end
    define_method("#{name}=".to_sym) do |v|
      @values[name] = v
    end
  end

  def element(name, scalar_klass = nil, options = {}, &block)
    add_element(name, false, scalar_klass, options, &block)
  end

  def elements(name, scalar_klass = nil, &block)
    add_element(name, true, scalar_klass, nil, &block)
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
      doc = parse(n.root)
    rescue ModelException => e
      raise ModelException.new("Нарушение формата в файле '#{p}': #{e}")
    end
    doc.on_load if doc.respond_to? :on_load
    doc
  end

  def check(&block)
    @checker = block
  end

  def parse(element)
    values = {}
    @parsers.each do |name, parser|
      values[name] = parser.call(element)
    end
    element.elements.each do |c|
      if not @parsers.has_key?(c.name.to_sym)
        raise ModelException.new "Неизвестный элемент #{c.path}"
      end
    end
    r = new(values)
    if @checker
      begin
        @checker.call(r)
      rescue ModelException => e
        raise ModelException.new \
          "Не выполнено соглашение для элемента #{element.path}: #{e}"
      end
    end
    r
  end
end

class Element
  extend ElementClass

  attr_reader :values

  def initialize(values)
    @values = values
  end
end

end # module XDSL
