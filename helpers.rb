DbPathsMain = { db: 'sqlite://site.db', dir: 'data' }
DbPathsEdit = { db: 'sqlite://edit.db', dir: 'edit' }

def db_open(paths)
  db = Sequel.connect(paths[:db])
  db.run('pragma synchronous = off')
  db.run('pragma foreign_keys = on')
  { db: db, dir: paths[:dir] }
end

module TeachingsHelper
  def load_teachings(options = {})
    teachings = []
    each_file("#{SiteData}/teachings", options) do |path|
      File.open(path) do |file|
        teachings << {
          id: path_to_id(path),
          document: Teachings::Document.load(file)
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

  def slug(title)
    title.downcase.strip.gsub(' ', '-').gsub(/[^\w-]/, '')
  end

  def load_page(path, url)
    @base_url = url
    html_render(File.read(db_path(path)))
  end

  def get_full_url(url)
    if url[0] == '/'
      full_url = url
    else
      base = @base_url || request.path
      full_url = "#{base}#{url}"
    end
  end

  def digest_url(url)
    full_url = get_full_url(url)
    output_url = (@base_url and @base_url != request.path) ? full_url : url

    return output_url if settings.development?
    digest = Cache::Digest[full_url]
    return output_url if digest.nil?
    "#{output_url}?sha1=#{digest[:digest]}"
  end

  def slideshow(dir)
    erb :'partials/slideshow', locals: { directory: dir }
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

  def tab_link(link, title, r = request.path)
    c = ""
    c = "class='active'" if r == link
    "<a #{c} href='#{link}'>#{title}</a>"
  end

  def path_split(path)
    path.split('/')
  end

  def db_path(path)
    "#{@db[:dir]}/#{path}"
  end
end

module NewsHelpers
  def render_news(news, cut)
    @base_url = "/news/#{news.id}/"
    doc = cut ? news.cut : news.body
    return html_render(doc) if news.ext == 'html'
    Tilt::ERBTemplate.new { doc }.render(self)
  end

  def html_digest_urls(doc)
    doc.xpath('//a').each do |a|
      h = a.attribute('href')
      next if not h
      h.content = digest_url(h.content)

      h = a.attribute('data-full')
      next if not h
      h.content = digest_url(h.content)
    end
    doc.xpath('//img').each do |a|
      h = a.attribute('src')
      next if not h
      h.content = digest_url(h.content)
    end
  end

  def html_expand_slideshow(doc)
    doc.css('div.fotorama').each do |div|
      dir = div.attribute('data-dir')
      next if not dir
      dir = dir.content
      options = { full_path: false, sorted: true }
      each_file(db_path("#{request.path}/#{dir}"), options) do |name|
        a = doc.create_element('a', href: digest_url("#{dir}/#{name}"))
        div.add_child(a)
        div.add_child("\n")
      end
    end
  end

  def html_render(str)
    d = Nokogiri::HTML(str)
    html_digest_urls(d)
    html_expand_slideshow(d)
    d.to_xml
  end

  def news_item(news, index = false)
    erb :'partials/news', locals: { news: news, index: index }
  end

  def news_single_class(news)
    c = "site-news"
    c += " short" if not news.has_more
    c
  end

  def news_styles(news)
    styles = news.map do |n|
      if n.is_dir and File.exists?(db_path("news/#{n.id}/style.css"))
        "/news/#{n.id}/style.css"
      else
        nil
      end
    end
    styles.compact
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

  def headings_div(headings)
    return if not headings or headings.empty?
    erb :'partials/headings', locals: { headings: headings }
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

  def week_day(date)
    erb :'partials/week_day', locals: { date: date }
  end

  def timetable_link(selected, skip)
      base = "/timetable?show=#{selected}"
      base += "&skip=#{skip}" if skip > 0
      base
  end

  def timetable_day_events(date)
    erb :'partials/week_day_places', locals: { events: @timetable.events(date) }
  end

  def timetable_enhanced?
    settings.development? or session[:login]
  end

  def timetable_mytnaya?
    cur = Week.new + @skip
    nex = cur + 1
    events = (cur.monday..nex.sunday).collect { |d| @timetable.events(d) }.flatten
    events.any? { |e| e.place == 'Мытная' }
  end

  def timetable_place_events(events, place)
    e = events.select { |e| e.place == place }
    return if e.empty?
    erb :'partials/week_day_short',
      locals: { events: e, style: (place == 'Мытная') ? 'mytnaya' : nil }
  end
end
