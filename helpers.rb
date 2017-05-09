module TeachingsHelper
  def load_teachings(options = {})
    teachings = []
    each_file("#{SiteData}/teachings", options) do |path|
      File.open(path) do |file|
        teachings << {
          id: path_to_id(path),
          document: TeachingsDocument.load(file)
        }
      end
    end
    teachings
  end

  def record_date(record)
    record.record_date.strftime('%Y.%m.%d')
  end

  def record_description(record, index)
    d = record.description
    return d if not d.nil?
    "Лекция №#{index}"
  end

  def record_link(record, idx)
    link = nil
    id = record.youtube_id
    link = "http://www.youtube.com/watch?v=#{id}" if id
    link(link, record_description(record, idx))
  end

  def record_download(record)
    return if not (record.audio_url and record.audio_size)
    download = ""
    download = "download" if not /yadi.sk/ =~ record.audio_url
    url = digest_url(record.audio_url)
    text = "mp3&nbsp;&nbsp;#{record.audio_size}&nbsp;Mб"
    "<a class='site-button' href='#{url}' #{download}>#{text}</a>"
  end

  def teachings_record(record, idx = nil)
    erb :'partials/record', locals: { record: record, idx: idx }
  end
end

module CommonHelpers
  def dir_files(dir, options={})
    default_options = {
      full_path: true,
      sorted: false,
      reverse: false
    }
    options = default_options.merge(options)
    names = Dir.entries(dir).select { |name| /^\./.match(name).nil? }

    if options[:sorted]
      names.sort_by! { |name| name }
      names.reverse! if options[:reverse]
    end

    names.map do |name|
      if options[:full_path]
        dir + '/' +  name
      else
        name
      end
    end
  end

  def each_file(dir, options={})
    dir_files(dir, options).each { |p| yield p }
  end

  def format_date(date)
    date.strftime('%d/%m/%y')
  end

  def link(link, title)
    return title if link.nil?
    "<a href=#{link}>#{title}</a>"
  end

  def link_if(show, link, title)
    if show
      "<a href=#{link}>#{title}</a>"
    else
      "<span>#{title}</span>"
    end
  end

  def div_if(condition, c, content)
    return if not condition
    "<div class='#{c}'>#{content}</div>"
  end

  def path_to_id(path)
    File.basename(path).gsub(/\.[^.]+$/, '')
  end

  def path_to_ext(path)
    path.gsub(/^[^.]+\./, '')
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

  def slug(title)
    title.downcase.strip.gsub(' ', '-').gsub(/[^\w-]/, '')
  end

  def load_page(path, url)
    @url = url
    Tilt.new("data/#{path}").render(self)
  end

  def digest_url(url, base = nil, context = nil)
    full_url = url
    full_url = "#{base}#{url}" if not base.nil?
    output_url = url
    output_url = full_url if not context.nil? and context != base
    return output_url if settings.development?
    digest = Cache::Digest[full_url]
    return output_url if digest.nil?
    "#{output_url}?sha1=#{digest[:digest]}"
  end

  def digest_local_url(url)
    digest_url(url, @url, @context_url)
  end

  def slideshow(dir, url = (@url or '/'), context_url = @context_url)
    erb :'partials/slideshow',
        locals: { url: url, context_url: context_url, directory: dir }
  end

  def slideshow_class(dir, extra_class,
                      url = (@url or '/'), context_url = @context_url)
    erb :'partials/slideshow',
        locals: { url: url, extra_class: extra_class,
                  context_url: context_url, directory: dir }
  end

  def fotorama_class(extra_class)
    c = "fotorama"
    c += " #{extra_class}" if extra_class
  end

  def local_uri(path, query_string)
    return path if query_string.empty?
    path += '?'
    path += query_string
  end

  def menu_link(name, link, title)
    c = "menu"
    c += " active" if name == @menu_active.to_s
    "<a class='#{c}' href='#{link}'>#{title}</a>"
  end
end

module NewsHelpers
  def render_news(news, cut)
    @url = "/news/#{news.id}/"
    doc = cut ? news.cut : news.body
    return doc if news.ext == 'html'
    Tilt::ERBTemplate.new { doc }.render(self)
  end

  def news_item(news, index = false)
    erb :'partials/news', locals: { news: news, index: index }
  end

  def news_single_class(news)
    c = "site-news"
    c += " short" if not news.has_more
    c
  end
end

module BookHelpers
  def book_info_line(name, value)
    return if value.nil?
    "<tr><td> #{name} </td><td> #{value} </td></tr>"
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

  def book_cover_url(id, size)
    digest_url("/books/#{id}/cover-#{size}.jpg")
  end

  def book_thumb(book)
    erb :'partials/book_thumb', locals: { book: book }
  end

  def book_category(category, upcase = true)
    name = category.name
    name = Unicode::upcase(category.name) if upcase
    erb :'partials/category_link',
        locals: { category: category, name: name }
  end
end

module TimetableHelper
  def timetable_months(week)
    first = week.monday
    last = week.next.sunday
    if first.month == last.month
      Russian::strftime(first, "%B")
    else
      "#{Russian::strftime(first, '%B')} - #{Russian.strftime(last, '%B')}"
    end
  end

  def week_day(date, events)
    locals = { date: date,
               events: events.select { |e| e.time.begin.to_date == date } }
    erb :'partials/week_day', locals: locals
  end

  def timetable_link(selected, skip)
      base = "/timetable?show=#{selected}"
      base += "&skip=#{skip}" if skip > 0
      base
  end

  def timetable_day_event(timetable)
    day = Date.today
    events = timetable.events(day..day)
    erb :'partials/week_day_places', locals: { events: events }
  end
end
