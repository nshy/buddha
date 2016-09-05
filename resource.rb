module News
  include NewsHelpers
  def options
    {
      type: 0,
      dir: 'news',
      send: {
        subject: 'Новости центра',
        email: 'news'
      },
      css: 'news.css',
      template: 'news-feed.erb',
      helpers: NewsHelpers
    }
  end

  def load_item(id)
    news = nil
    File.open(body_path("data/news/#{id}")) do |file|
      news = NewsDocument.new(Nokogiri::XML(file)).news
    end
    news
  end

  def render_options(items)
    { news_all: items }
  end
end

module Books
  def options
    {
      type: 1,
      dir: 'books',
      send: {
        subject: 'Новости библиотеки',
        email: 'library',
      },
      css: 'book-feed.css',
      template: 'book-feed.erb',
      helpers: BookHelpers
    }
  end

  def load_item(id)
    book = nil
    File.open("data/books/#{id}/info.xml") do |file|
      book = BookDocument.new(Nokogiri::XML(file)).book
    end
    book
  end

  def render_options(items)
    { books: items }
  end
end

module TimeUpdates
  def options
    {
      type: 2,
      dir: 'time-update',
      send: {
        subject: 'Изменения в расписании',
        email: 'timetable',
      },
      css: 'time-feed.css',
      template: 'time-feed.erb',
      helpers: TimeUpdateHelpers
    }
  end

  def load_item(id)
    change = nil
    File.open("data/time-update/#{id}.xml") do |file|
      change = TimeUpdateDocument.new(Nokogiri::XML(file)).update
    end
    change
  end

  def render_options(items)
    { changes: items }
  end
end
