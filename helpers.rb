require 'open3'

Sites = [ :main, :edit ]

module SiteHelpers
  def SiteHelpers.file(site)
    ".#{site}.db"
  end

  def SiteHelpers.open(site)
    db = Sequel.connect("sqlite://#{SiteHelpers.file(site)}")
    db.run('pragma synchronous = off')
    db.run('pragma foreign_keys = on')
    db
  end

  def site_dir
    site.to_s
  end

  def build_dir
    '.build'
  end

  def site_build_dir
    File.join(build_dir, site_dir)
  end

  def site_path(path)
    File.join(site_dir, path)
  end

  def site_build_path(path)
    File.join(site_build_dir, path)
  end
end

module AppSites
  def self.connect
    servers = Sites.map { |n| [n, { database: SiteHelpers.file(n) }] }.to_h

    Sequel.connect(adapter: 'sqlite',
                   database: SiteHelpers.file(:main),
                   servers: servers)
  end

  def site
    session[:login] ? :edit : :main
  end

  def site_model(klass)
    klass.server(site)
  end

  def site_table(table)
    DB[table].server(site)
  end
end

module LibraryHelper
  Section = Struct.new(:name, :categories)

  def load_sections
    library = Library::Document.load(site_path('library.xml'))
    library.section.map do |s|
      a = site_model(Cache::Category).
              where(Sequel[:book_categories][:id] => s.category).all
      h = a.map { |c| [ c.id, c ] }.to_h
      Section.new(s.name, s.category.map { |id| h[id] })
    end
  end
end

module TeachingsHelper
  def load_teachings(options = {})
    teachings = []
    each_file("#{SiteData}/teachings", options) do |path|
      File.open(path) do |file|
        teachings << {
          id: File.basename(path, '.*'),
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
    if record.respond_to? :theme
      @base_url = "/teachings/#{record.theme.teaching.id}/"
    end
    url = digest_url(record.audio_url)
    text = "mp3&nbsp;&nbsp;#{record.audio_size}&nbsp;Mб"
    "<a class='site-button' href='#{url}' #{download}>#{text}</a>"
  end

  def teachings_record(record, idx = nil)
    erb :'partials/record', locals: { record: record, idx: idx }
  end
end

module CommonHelpers
  def execute(cmd)
    o, e, s = Open3.capture3(cmd)
    if not s.success?
      logger.error(e)
      raise "Command execution error: #{cmd}"
    end
    o
  end

  def send_app_file(p)
    cache_control :public, max_age: 0 if settings.development?
    d = :attachment if /\.(doc|pdf)$/ =~ p
    send_file p, disposition: d
  end

  def find_simple_page
    url = request.path
    return nil if not /\/$/ =~ url
    p = url.sub(/^\//, '').sub(/\/$/, '')
    find_page(p, 'html')
  end

  def find_page(url, ext)
    p = site_path(url)
    s = "#{p}.#{ext}"
    l = "#{p}/page.#{ext}"
    if File.exist?(s) and File.exist?(l)
      raise ModelException.new(collision_error(s, l))
    elsif File.exists?(s)
      s
    elsif File.exists?(l)
      l
    else
      nil
    end
  end

  def simple_page(p)
    @html, header = load_preamble(p, ['menu'])
    @menu_active = header['menu']
    @extra_scripts += page_scripts(header['scripts'])
    erb "<%= html_render(@html) %>"
  end

  def check_url_nice(path, assets = false)
    s = path_split(path)
    # shift is for the first directory that can contain '.' like '.build'
    s.shift
    s.last.sub!(/\..+$/, '')
    a = "-a-zA-Z0-9"
    a += "_" if assets
    r = Regexp.new("^[#{a}]+$")
    if s.any? { |p| not r =~ p }
      raise ModelException.new \
        "Неправильный формат имени в пути #{path_from_db(path)}:" \
        "Имя должно состоять только из латинских строчных и заглавных букв, " \
        "цифр и тире, если не считать точки перед расширением файла. " \
        "В имени аудио файлов, изображений и проч. также можно использовать " \
        "подчеркивание."
    end
  end

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

  def slug(title)
    title.downcase.strip.gsub(' ', '-').gsub(/[^\w-]/, '')
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
    begin
      return url if URI(url).absolute?
    rescue URI::InvalidURIError
      return url
    end
    full_url = get_full_url(url)
    output_url = (@base_url and @base_url != request.path) ? full_url : url

    return output_url if settings.development?
    digest = site_model(Cache::Digest_SHA1).where(id: full_url).first
    return "#{output_url}?sha1=#{digest[:sha1]}" if digest
    digest = site_model(Cache::Digest_UUID).where(id: full_url).first
    return "#{output_url}?uuid=#{digest[:uuid]}" if digest and digest[:uuid]
    return output_url
  end

  def slideshow(dir)
    erb :'partials/slideshow', locals: { directory: dir }
  end

  def local_uri(path, query_string)
    return path if query_string.empty?
    path += '?'
    path += query_string
  end

  def menu_link(link, title)
    c = "menu"
    c += " active" if title == @menu_active
    "<a class='#{c}' href='#{link}'>#{title}</a>"
  end

  def tab_link(link, title, r = request.path)
    c = ""
    c = "class='active'" if r == link
    "<a #{c} href='#{link}'>#{title}</a>"
  end

  def path_split(path)
    path.sub(/^\//, '').split('/')
  end

  def model_errors
    site_model(Cache::Error).all.collect { |e| e.message }
  end

  def collision_error(short, long)
    "Присутствуют оба варианта #{path_from_db(short)} и " \
    "#{path_from_db(long)} " \
    "Используйте либо вариант с директорией и файлом внутри " \
    "либо только файл."
  end

  def collision_errors
    collisions = [ :teachings, :news, :books, :book_categories ].map do |t|
      site_table(t).
        join(Sequel[t].as(:table_alias), id: :id).
          where{ length(Sequel[t][:path]) < length(Sequel[:table_alias][:path]) }.
            select(Sequel[t][:path], Sequel[:table_alias][:path].as(:path_alias)).
        all
    end
    collisions.flatten!
    collisions.map { |c| collision_error(c[:path], c[:path_alias]) }
  end

  def site_errors
    model_errors + collision_errors
  end

  def site_errors_html(errors)
    errors.map { |e|
      "<pre class='site-error'>#{e}</pre>"
    }.join("\n")
  end
end

module NewsHelpers
  def render_news(news, cut)
    @base_url = "/news/#{news.id}/"
    doc = cut ? news.cut : news.body
    html_render(doc)
  end

  def news_urls(doc)
    doc.xpath('//a').each do |a|
      yield a.attribute('href')
      yield a.attribute('data-full')
    end
    doc.xpath('//img').each do |a|
      yield a.attribute('src')
    end
  end

  def html_digest_urls(doc)
    news_urls(doc) do |url|
      next if not url
      url.content = digest_url(url.content)
    end
  end

  def html_expand_slideshow(doc)
    doc.css('div.fotorama').each do |div|
      dir = div.attribute('data-dir')
      next if not dir
      dir = dir.content
      options = { full_path: false, sorted: true }
      p = site_path(get_full_url(dir))
      next if not File.directory?(p)
      each_file(p, options) do |name|
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
    body = d.at_xpath('/html/body')
    return "" if not body
    body.inner_html
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
      p = "/news/#{n.id}.css"
      if n.is_dir and File.exists?(site_build_path(p))
        p
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
    digest_url("/books/#{id}.jpg")
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

  def timetable_day(date)
    erb :'partials/timetable_day', locals: { date: date }
  end

  def timetable_link(selected, skip)
      base = "/timetable?show=#{selected}"
      base += "&skip=#{skip}" if skip > 0
      base
  end

  def timetable_enhanced?
    settings.development? or session[:login]
  end

  def timetable_place?(place)
    cur = Week.new + @skip
    nex = cur + 1
    events = (cur.monday..nex.sunday).collect { |d| @timetable.events(d) }.flatten
    events.any? { |e| e.place == place }
  end

  def index_events(events, place)
    timetable_events(events, place, true)
  end

  def timetable_events(events, place, index = false)
    e = events.select { |e| e.place == place }
    s = events.select { |e| e.place == 'Спартаковская' }
    return if e.empty?
    erb :'partials/timetable_events',
        locals: { events: e,
                  place: place,
                  index: index,
                  explicit: s.size != events.size }
  end

  def timetable_announces(a)
    a = a.collect { |a| a.capitalize }
    a.first.downcase! if not a.empty?
    a.collect { |a| a}.join(' ')
  end
end

module AdminHelpers
  def diff_path(file)
    l = { added: "A", deleted: "D", changed: "M" }[file.action]
    "<span class='action #{file.action}'>#{l}</span> #{file.path}"
  end

  def diff_class(change)
    { ' ' => 'context', '+' => 'add', '-' => 'del' }[change[0]]
  end
end
