require_relative 'xmldsl'
require_relative 'utils'
require 'date'

class NewsDocument
  attr_reader :date, :title, :cut, :body, :is_dir, :buddha_node

  PageCut = /(.*)<!--[\t ]*page-cut[\t ]*-->(.*)/m
  PageCutSimple = /(.*)<!--[\t ]*page-cut-simple[\t ]*-->/m

  def initialize(path)
    @is_dir = path_is_dir(path)
    begin
      doc = Preamble.load(path)
    rescue StandardError
      raise ModelException.new("Ошибочное форматирование заголовка новости")
    end
    if m = PageCut.match(doc.content)
      @cut = m[1]
      @body = m[2]
    elsif m = PageCutSimple.match(doc.content)
      @cut = m[1]
      @body = doc.content
    else
      @body = doc.content
      @cut = nil
    end

    ds = doc.metadata['publish_date']
    if not ds
      raise ModelException.new("Не указана дата публикации новости")
    end
    @title = doc.metadata['title']
    if not @title
      raise ModelException.new("Не указано заглавие новости")
    end
    @buddha_node = doc.metadata['buddha_node']
    d = DateTime.parse(ds)
    if d.hour == 0 and d.minute == 0
      if d.strftime("%Y-%m-%d") != ds
        raise ModelException.new("Неправильный формат даты #{ds}")
      end
    else
      if d.strftime("%Y-%m-%d %H:%M") != ds
        raise ModelException.new("Неправильный формат даты и времени #{ds}")
      end
    end
    @date = d
  end

  def path_is_dir(path)
    p = Pathname.new(path).each_filename.to_a
    return p.find_index('news') == p.size - 3
  end
end

class Integer
  def self.parse(v)
    Integer(v)
  end
end

class ModelDate; end

def ModelDate.parse(v)
  d = Date.parse(v)
  raise ArgumentError.new if d.strftime("%Y-%m-%d") != v
  d
end

def String.parse(v)
  v
end

module Teachings

class Document < XDSL::Element
  root :teachings
  element :title, String, required: true
  element :year
  elements :theme do
    element :title, String, required: true
    element :buddha_node
    element :geshe_node
    element :annotation
    elements :record do
      element :description
      element :record_date, ModelDate, required: true
      element :audio_url
      element :audio_size, Integer
      element :video_url
      element :video_size, Integer
      element :youtube_id
    end
  end

  def begin_date
    t = theme.min { |a, b| a.begin_date <=> b.begin_date }
    t.begin_date
  end
end

class Theme
  def begin_date
    r = record.min { |a, b| a.record_date <=> b.record_date }
    r.record_date
  end

  def doc_check
    r = record.collect { |r| r.record_date }
    if r != r.sort
      raise ModelException.new \
        "Записи должны быть упорядочены по дате записи. " \
        "Более поздние должны идти ниже"
    end
  end
end

class Record
  def doc_check
    if audio_url and audio_size.nil?
      raise ModelException.new \
	"Если указана ссылка на аудио-файл, то " \
	"нужно указать и размер файла."
    end
  end
end

end # module Teachings

module BookCategory

class Document < XDSL::Element
  root :category
  element :name, String, required: true
  elements :subcategory
  elements :group do
    element :name, String, required: true
    elements :book
  end
end

end # module BookCategory

module Library

class Document < XDSL::Element
  root :library
  elements :section do
    element :name, String, required: true
    elements :category
  end
end

end # module Library

module Menu

class Document < XDSL::Element
  root :menu
  elements :item do
    element :title, String, required: true
    element :link, String, required: true
    elements :subitem do
      element :title, String, required: true
      element :link, String, required: true
    end
  end

  def about
    item.select { |i| i.title == 'О ЦЕНТРЕ' }.first
  end

  def others
    item.select { |i| i.title != 'О ЦЕНТРЕ' }
  end
end

end # module Menu

module Quotes

class Document < XDSL::Element
  root :quotes
  elements :begin, ModelDate
  elements :quote

  def current_quotes
    num = 5
    w = Week.new
    b = self.begin.select { |b| b <= w.monday }.last

    wb = Week.new(b)
    wb += 1 if not b.monday?
    (quote + quote.slice(0, num)).slice((w - wb) % quote.length, num)
  end

  def doc_check
    if self.begin.empty?
      raise ModelException.new \
        "Не указно начало отсчета цитат"\
        "(начало нового года по лунному календарю)"
    end

    if quote.size < 5
      raise ModelException.new \
        "Должно быть по крайней мере 5 цитат"
    end

    b = self.begin
    if b != b.sort
      raise ModelException.new \
        "Даты первых дней лунных лет должны быть упорядочены. " \
        "Более поздние должны идти ниже"
    end
  end
end

end # module Quotes

module Index

class Document < XDSL::Element
  root :index
  element :welcome, String, required: true
  element :announce do
    element :image, String, required: true
    element :link, String, required: true
    element :end, ModelDate
  end
end

end # module Index
