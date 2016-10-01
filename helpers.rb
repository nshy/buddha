module TeachingsHelper
  def load_teachings
    teachings = {}
    each_file('data/teachings') do |path|
      File.open(path) do |file|
        teachings[path_to_id(path)] =
          TeachingsDocument.new(Nokogiri::XML(file)).teachings
      end
    end
    teachings
  end

  def download_link(record, media)
    url = record.send("#{media}_url".to_sym)
    return nil if url.nil? or url.empty?
    title = { audio: 'аудио', video: 'видео' }[media]
    size = { audio: record.audio_size, video: record.video_size }[media]
    size = 0 if size.nil?
    "<a href=#{url} class=\"btn btn-primary btn-xs button\""\
      " download>#{title}, #{size} M6</a>"
  end

  def record_description(record, index)
    d = record.description
    return d if not d.nil?
    "Лекция №#{index}"
  end

end

module CommonHelpers
  def each_file(dir)
    Dir.entries(dir).each do |p|
      # skip any dot files
      next if not /^\./.match(p).nil?
      yield dir + '/' +  p
    end
  end

  def each_file_sorted(dir)
    entries = Dir.entries(dir).reject do |p|
      # skip any dot files
      not /^\./.match(p).nil?
    end
    entries.sort_by! { |p| p }
    entries.each { |p| yield dir + '/' +  p }
  end

  def format_date(date)
    date.strftime('%d/%m/%y')
  end

  def link_if(show, link, title)
    if show
      "<a href=#{link}>#{title}</a>"
    else
      title
    end
  end

  def path_to_id(path)
    File.basename(path).gsub(/.xml$/, '')
  end

  def render_adoc(adoc, imagesdir = nil)
    attr = {
      'icons' => 'true',
      'iconsdir' => '/icons',
      'imagesdir' => imagesdir
    }
    Asciidoctor.render(adoc, attributes: attr)
  end

  def send_file_media(path)
    disposition = nil
    if not /.*\.(doc|pdf)$/.match(path).nil?
      disposition = :attachment
    elsif not /.*\.(jpg|gif|swf)$/.match(path).nil?
      # noop
    else
      halt 404
      return
    end
    send_file(path, disposition: disposition)
  end

  def yandex_money_url(target, title, sum, redirect)
    r = /[^a-zA-Z0-9*-._]/
    link = "#{SiteConfig::DOMAIN}#{redirect}"
    "https://money.yandex.ru/embed/shop.xml?"\
      "account=#{target}"\
      "&quickpay=shop&writer=seller"\
      "&targets=#{URI.escape(title, r)}"\
      "&default-sum=#{sum}&button-text=03"\
      "&successURL=#{URI.escape(link, r)}"
  end

  def render_text(text)
    @file = Preamble.load("data/#{text}/page.adoc")
    erb :text
  end

  def slug(title)
    title.downcase.strip.gsub(' ', '-').gsub(/[^\w-]/, '')
  end

end

class NewsDocument
  def initialize(path, options)
    @doc = Preamble.load(path)
    @content = @doc.content
    @content = @content.gsub(/^<<<$.*/m, '') if options[:page_cut]
  end

  def publish_date
    @doc.metadata['publish_date']
  end

  def title
    @doc.metadata['title']
  end

  def buddha_node
    @doc.metadata['buddha_node']
  end

  def body
    @content
  end
end

module NewsHelpers

  def body_path(path)
    File.directory?(path) ? "#{path}/page.adoc" : "#{path}.adoc"
  end

  def load_news()
    news = []
    each_file_sorted("data/news") do |news_path|
      slug = File.basename(news_path).gsub(/.adoc$/, '')
      puts slug
      news << {
        slug: slug,
        news: NewsDocument.new(
          body_path("data/news/#{slug}"), {
            page_cut: true
          }
        )
      }
    end
    news.sort do |a, b|
      Date.parse(b[:news].publish_date) <=> Date.parse(a[:news].publish_date)
    end
  end

  def news_years(news)
    years = news.collect { |news| Date.parse(news[:news].publish_date).year }.uniq
  end

  def news_query_each(news, params)
    result = nil
    if params['top'] == 'true'
      result = news.first(10)
    else
      result = news.select do |n|
        Date.parse(n[:news].publish_date).year == params['year'].to_i
      end
    end
    result.each do |n|
      yield n[:slug], n[:news]
    end
  end

  def render_news(news, slug)
    render_adoc(news, "/news/#{slug}")
  end

  def news_is_year(params)
    not params['year'].nil?
  end

  def news_year(news)
    Date.parse(news.publish_date).year
  end
end

module BookHelpers
  def variable_row(name, value)
    return if value.nil? or value.empty?
    erb :'partials/variable_row', locals: { name: name, value: value }
  end

  def comma_present(values)
    values.join(', ')
  end

  def parse_annotation(text)
    return [] if text.nil?
    text.split "\n\n"
  end

  def parse_toc(text)
    TOC::Heading::parse(text.nil? ? '' : text)
  end

  def headings_div(heading)
    return if heading.children.empty?
    erb :'partials/headings', locals: { headings: heading.children }
  end

  def each_book
    Dir.entries('data/books').each do |book|
      next if not File.exist?("data/books/#{book}/info.xml")
      yield book
    end
  end

  def book_cover_url(id, size)
    "/book/#{id}/cover-#{size}.jpg"
  end

  def book_categories(categories, id)
    r = categories.select do |cid, c|
      c.group.any? do |g|
        g.book.include?(id)
      end
    end
    r.keys
  end

  def book_thumb(id, book)
    erb :'partials/book_thumb', locals: { id: id, book: book }
  end
end

module CategoryHelpers
  def category_categories(categories, id)
    r = categories.select { |cid, c| c.subcategory.include?(id) }
    r.keys
  end

  def load_categories
    categories = {}
    each_file('data/book-category') do |path|
      File.open(path) do |file|
        categories[path_to_id(path)] =
          BookCategoryDocument.new(Nokogiri::XML(file)).category
      end
    end
    categories
  end

  def count_category(categories, cid, subcategories = nil, books = nil)
    books = Set.new if books.nil?
    subcategories = Set.new if subcategories.nil?
    categories[cid].group.each do |g|
      g.book.each do |bid|
        books.add(bid)
      end
    end
    categories[cid].subcategory.each do |sid|
      next if subcategories.include?(sid)
      count_category(categories, sid, subcategories, books)
    end
    books.size
  end

  def category_link(categories, category)
    locals = { categories: categories, category: category }
    erb :'partials/category_link', locals: locals
  end
end

module TimetableHelper
  def timetable_months()
    first = week_begin(Date.today)
    last = first + 13
    if first.month == last.month
      Russian::strftime(first, "%B")
    else
      "#{Russian::strftime(first, '%B')} - #{Russian.strftime(last, '%B')}"
    end
  end

  def event_interval(event)
    time_interval(event[:begin], event[:end])
  end

  def time_interval(b, e)
     "#{b.strftime('%H:%M')} - #{e.strftime('%H:%M')}"
  end

  def format_date_classes(date)
    date.strftime("%-d %B");
  end

  def print_week_days(offset)
      b, e = week_borders(offset)
      "from #{format_date_classes(b)} till #{format_date_classes(e)}"
  end

  def week_borders(offset)
    today = Date.today
    [ week_begin(today) + 7 * offset,
      week_end(today) + 7 * offset ]
  end

  def past_classes(classes)
    return false if classes.end.nil?
    Date.parse(classes.end) < week_begin(Date.today)
  end

  def future_classes(classes)
    return false if classes.begin.nil?
    Date.parse(classes.begin) > week_end(Date.today)
  end

  def actual_classes(classes)
    not (past_classes(classes) or future_classes(classes))
  end

  def classes_dates(classes)
    b = e = ""
    if not classes.begin.nil?
      d = Date.parse(classes.begin)
      b = "с #{Russian::strftime(d, "%e %B")}"
    end
    if not classes.end.nil?
      d = Date.parse(classes.end)
      e = " по #{Russian::strftime(d, "%e %B")}"
    end
    b + e
  end

  def classes_days(classes)
    days = classes.day.collect do |d|
      i = timetable_parse_classes_day(d)
      day = Date.parse(i[:day])
      "#{Russian::strftime(day, "%A")} #{i[:begin]}"
    end
    days.join(", ")
  end

  def week_events(timetable, offset)
    b, e = week_borders(offset)
    week = timetable_events(timetable, b, e)
    mark_event_conflicts(week)
    events_week_partition(week)
  end
end

module TimeUpdateHelpers
  def render_changes(message)
    Asciidoctor.render(message)
  end
end
