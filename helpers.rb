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

  def render_adoc(adoc, imagesdir)
    attr = {
      'icons' => 'true',
      'iconsdir' => '/icons',
      'imagesdir' => imagesdir
    }
    Asciidoctor.render(adoc, attributes: attr)
  end

end

module NewsHelpers

  def body_path(path)
      File.directory?(path) ? "#{path}/body.xml" : path
  end

  def load_news()
    news = []
    each_file_sorted("data/news") do |news_path|
      File.open(body_path(news_path)) do |file|
        news << { slug: File.basename(news_path),
                  news: NewsDocument.new(Nokogiri::XML(file)).news }
      end
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
  def day_names(day)
    [
      'Понедельник',
      'Вторник',
      'Среда',
      'Четверг',
      'Пятница',
      'Суббота',
      'Воскресенье'
    ][day]
  end

  def translate_day(day)
    eng = Date.parse(day).cwday
    ru = (eng - 1) % 7
    day_names(ru)
  end

  def event_interval(event)
    time_interval(event[:begin], event[:end])
  end

  def time_interval(b, e)
     "#{b.strftime('%H:%M')}-#{e.strftime('%H:%M')}"
  end

  def print_week_days(offset)
      b, e = week_borders(offset)
      "#{format_date(b)} - #{format_date(e)}"
  end

  def print_week_symbolic(offset)
    if offset < -1
      "Далекое прошлое"
    elsif offset > 1
      "Далекое будущее"
    else
      [
        "Предыдущая неделя",
        "Текущая неделя",
        "Cледующая неделя"
      ][offset + 1]
    end
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
      b = "с #{format_date(Date.parse(classes.begin))}"
    end
    if not classes.end.nil?
      e = " по #{format_date(Date.parse(classes.end))}"
    end
    b + e
  end
end

module TimeUpdateHelpers
  def render_changes(message)
    Asciidoctor.render(message)
  end
end
