require_relative 'convert'

module Assets

module News

  def src
    DirFiles.new(site_path("news"), "scss", DirFiles::IN_DIR, name: "style")
  end

  def dst
    DirFiles.new(site_build_path("news"), "css", DirFiles::PLAIN)
  end

  def preprocess(path, input)
    id = path_split(path)[2]
    "#news-#{id} {\n\n#{input}\n}"
  end

  def shorten(path)
    path_from_db(path)
  end

  def compile(path)
    compile_css(self, path)
  end
end

module Public
  def src
    DirFiles.new("assets/css", "scss", DirFiles::PLAIN)
  end

  def dst
    DirFiles.new(".build/css", "css", DirFiles::PLAIN)
  end

  def mixins
    "assets/css/_mixins.scss"
  end

  def shorten(path)
    path
  end

  def compile(path)
    compile_css(self, path)
  end

  # create bundle
  def postupdate
    bundle = ""
    dst.files.each { |p| bundle += File.read(p) }
    File.write('.build/bundle.css', bundle)
  end
end

end
