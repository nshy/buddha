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
end

module CommonHelpers
  def each_file(dir, options={})
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

    names.each do |name|
      if options[:full_path]
        yield dir + '/' +  name
      else
        yield name
      end
    end
  end

  def format_date(date)
    date.strftime('%d/%m/%y')
  end

  def link_if(show, link, title)
    if show
      "<a href=#{link}>#{title}</a>"
    else
      "<span>#{title}</span>"
    end
  end

  def path_to_id(path)
    File.basename(path).gsub(/\.[^.]+$/, '')
  end

  def render_adoc(adoc, imagesdir = nil)
    attr = {
      'icons' => 'true',
      'iconsdir' => '/icons',
      'imagesdir' => imagesdir
    }
    Asciidoctor.render(adoc, attributes: attr)
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
    return output_url if @digests.nil?
    sha1 = @digests[full_url]
    return output_url if sha1.nil?
    "#{output_url}?sha1=#{sha1}"
  end

  def digest_local_url(url)
    digest_url(url, @url, @context_url)
  end

  def load_digests
    return nil if not File.exist?('digests.txt') or settings.development?
    digests = {}
    File.readlines('digests.txt').each do |line|
      hash, path = line.split(' ')
      digests[path] = hash
    end
    digests
  end

  def slideshow(dir, url = (@url or '/'), context_url = @context_url)
    erb :'partials/slideshow',
        locals: {
          url: url,
          context_url: context_url,
          directory: dir,
        }
  end
end

NewsFormat = {
  adoc: {
    cutter: /^<<<$.*/m,
    render: lambda { |doc, id, context|
      attr = {
        'icons' => 'true',
        'iconsdir' => '/icons',
        'imagesdir' => "news/#{id}"
      }
      Asciidoctor.render(doc, attributes: attr)
    }
  },
  html: {
    cutter: /<!--[\t ]*page-cut[\t ]*-->.*/m,
    render: lambda { |doc, id, context| doc }
  },
  erb: {
    cutter: /<!--[\t ]*page-cut[\t ]*-->.*/m,
    render: lambda { |doc, id, context|
      Tilt::ERBTemplate.new { doc }.render(context)
    }
  }
}

class News
  DIR_PAGE = 'page'
  FILE_REGEXP = /^([\w_-]+)\.([[:alnum:]]+)$/

  include CommonHelpers

  attr_reader :news_dir

  def initialize(news_dir)
    @news_dir = news_dir
  end

  def find(id)
    id_dir = "#{@news_dir}/#{id}"
    is_dir = File.directory?(id_dir)
    if is_dir
      path = find_file(id_dir, DIR_PAGE)
    else
      path = find_file(@news_dir, id)
    end
    return nil if path.nil?
    NewsDocument.new(id, path, is_dir)
  end

  def load()
    @news = []
    each_file(@news_dir) do |item|
      is_dir = File.directory?(item)
      if is_dir
        id = File.basename(item)
        path = find_file("#{@news_dir}/#{id}", DIR_PAGE)
        next if path.nil?
      else
        m = FILE_REGEXP.match(File.basename(item))
        next if m.nil?
        id = m[1]
        path = item
      end
      @news << {
        slug: id,
        news: NewsDocument.new(id, path, is_dir)
      }
    end
    @news.sort! do |a, b|
      b[:news].date <=> a[:news].date
    end
  end

  def top(n)
    @news.first(n)
  end

  def by_year(year)
    @news.select do |n|
      n[:news].date.year == year
    end
  end

  def years()
    @news.collect { |news| news[:news].date.year }.uniq
  end

private

  def find_file(dir, name)
    paths = NewsFormat.keys.map { |ext| "#{dir}/#{name}.#{ext}" }
    paths.find { |path| File.exists?(path) }
  end

end


class NewsDocument
  attr_reader :has_more, :cut, :date, :ext, :is_dir

  def initialize(id, path, is_dir)
    @ext = News::FILE_REGEXP.match(File.basename(path))[2].to_sym
    @doc = Preamble.load(path)
    @content = @doc.content
    @cut = @doc.content.gsub(NewsFormat[@ext][:cutter], '')
    @has_more = @cut != @content
    @date = Date.parse(@doc.metadata['publish_date'])
    @is_dir = is_dir
    @id = id
  end

  def title
    @doc.metadata['title']
  end

  def buddha_node
    @doc.metadata['buddha_node']
  end

  def style
    return nil if not @is_dir
    path = "#{NewsStore.news_dir}/#{@id}/style.css"
    return nil if not File.exists?(path)
    "/news/#{@id}/style.css"
  end

  def body
    @content
  end
end

module NewsHelpers
  def render_news(news, slug, ext)
    @url = "/news/#{slug}/"
    NewsFormat[ext][:render].call(news, slug, self)
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
    Dir.entries('data/book').each do |book|
      next if not File.exist?("data/book/#{book}/info.xml")
      yield book
    end
  end

  def book_cover_url(id, size)
    digest_url("/book/#{id}/cover-#{size}.jpg")
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
      categories[path_to_id(path)] = BookCategoryDocument.load(path)
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
end

module TimetableHelper
  def timetable_months()
    first = Week.new.monday
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

  def past_classes(classes)
    return false if classes.end.nil?
    Date.parse(classes.end) < Week.new.monday
  end

  def future_classes(classes)
    return false if classes.begin.nil?
    Date.parse(classes.begin) > Week.new.sunday
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

  def week_events(timetable, week)
    week = timetable_events(timetable, week.monday, week.sunday)
    events_week_partition(week)
  end
end
