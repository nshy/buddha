require 'nokogiri'
require_relative 'utils'

module XDSL

module ElementClass

  def add_element(name, multi, scalar_klass, options = {}, &block)
    if block_given?
      throw "klass and block cannot be set both" if not scalar_klass.nil?
      klass = Class.new(Element)
      @module.const_set(name.capitalize, klass)
      klass.instance_exec(@module) { |m| @module = m }
      klass.instance_eval(&block)
      scalar_parser = lambda { |e| klass.parse(e) }
    else
      scalar_parser = lambda do |e|
        t = e.inner_html.strip
        if t.empty?
          return scalar_klass == Boolean ? true : nil
        end
        return t if not scalar_klass
        begin
          scalar_klass.parse(t)
        rescue ArgumentError
          raise ModelException.new \
            "#{spec(e)}:\nНедопустимое значение '#{t}'"
        rescue ModelException => err
          raise ModelException.new "#{spec(e)}:\n#{err}"
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
        c = e.xpath(name.to_s)
        if c.size > 1
          raise ModelException.new \
            "#{spec(e)}:\nЭлемент #{name} должен присутствовать " \
            "в одном экземпляре"
        end
        v = scalar_klass == Boolean ? false : nil
        v = scalar_parser.call(c[0]) if not c.empty?
        if not v and options[:required]
          raise ModelException.new \
            "#{spec(e)}:\ Элемент #{name} должен присутствовать " \
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

  def elements(name, scalar_klass = nil, options = {}, &block)
    add_element(name, true, scalar_klass, options, &block)
  end

  def root(root)
    @root = root
    # this little magic get the module/class in which caller is defined
    @module = class_eval(self.name.split("::")[-2])
  end

  def load(path)
    return nil if not File.exists?(path)
    begin
      n = Nokogiri::XML(File.open(path)) { |config| config.strict }
    rescue Nokogiri::XML::SyntaxError => e
      raise format_file_error(path, "Нарушение синтаксиса XML: #{e}")
    end
    if n.root.name != @root.to_s
      raise format_file_error(path, "Неправильный корневой элемент #{n.root.path}")
    end
    begin
      doc = parse(n.root)
    rescue ModelException => e
      raise format_file_error(path, e)
    end
    doc
  end

  def parse(element)
    values = {}
    @parsers.each do |name, parser|
      values[name] = parser.call(element)
    end
    element.elements.each do |c|
      if not @parsers.has_key?(c.name.to_sym)
        raise ModelException.new "#{spec(c)}:\nНеизвестный элемент"
      end
    end
    r = new(values)
    if r.respond_to? :doc_check
      begin
        r.doc_check
      rescue ModelException => e
        raise ModelException.new \
          "#{spec(element)}:\n#{e}"
      end
    end
    r
  end

  def spec(e)
    "По пути: элемент #{e.path}, строка #{e.line}"
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
