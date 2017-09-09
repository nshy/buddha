require 'rack/utils.rb'

def diff_path(path, action)
  if action == :changed
    path
  else
    present = { added: 'Добавлен', deleted: 'Удален' }
    "#{path} [#{present[action]}]"
  end
end

def make_html(patch, options)
  klasses = { ' ' => 'context', '+' => 'add', '-' => 'del' }
  res = []
  patch.each do |f|
    res << \
    <<-END
<div class="file">
  <div class="path #{f.mode}">#{diff_path(f.path, f.action)}</div>
    END
    f.hunks.each do |h|
      if f.action == :changed
        res << \
        <<-END
  <div class="line">
    <span class="title">Строка:</span>
    <span class="value">#{h.lnum}</span>
  </div>
        END
      end
      h.changes.each do |c|
        res << "  <pre class='#{klasses[c[0]]}'>"
        res << (options[:escape] ? Rack::Utils.escape_html(c) : c)
        res << '  </pre>'
      end
    end
    res << "</div>"
  end
  # remove newlines introduced by << string literals
  res = res.collect { |h| h.rstrip }
  res.join("\n")
end

module Diff
  File = Struct.new(:path, :mode, :action, :hunks)
  Hunk = Struct.new(:lnum, :changes)
end

def parse_diff(diff)
  lines = diff.split("\n")
  l = lines.shift
  patch = []
  while l and l.start_with?('diff')
    file = Diff::File.new
    file.action = :changed
    l = lines.shift while not (l.start_with?('---') or l.start_with?('Binary files'))
    if l.start_with?('---')
      a = l.sub(/^--- /, '')
      l = lines.shift
      b = l.sub(/^\+\+\+ /, '')
      file.mode = :text
    else
      m = /^Binary files (.+) and (.+) differ$/.match(l)
      a = m[1]
      b = m[2]
      file.mode = :binary
    end
    file.action = :added if a == '/dev/null'
    file.action = :deleted if b == '/dev/null'
    file.path = a != '/dev/null' ? a : b
    file.path = file.path.sub(/.\//, '')
    file.hunks = []
    l = lines.shift
    while l and l[0] == '@'
      hunk = Diff::Hunk.new
      hunk.lnum = /^@@ -([^ ]+)/.match(l)[1].gsub(/,.*$/, '')
      l = lines.shift
      hunk.changes = []
      while l and [' ', '-', '+', '\\'].include?(c = l[0])
        # skip technical git comments
        if c == '\\'
          l = lines.shift
          next
        end
        lines_ = []
        while l and l[0] == c
          lines_ << l
          l = lines.shift
        end
        hunk.changes << lines_.join("\n")
      end
      file.hunks << hunk if file.mode == :text
    end
    if file.hunks.size == 1 and
       file.hunks[0].changes.size == 1 and
       file.hunks[0].changes[0] =~/.\/bsym\//
      file.mode = :binary
    end
    patch << file
  end
  patch
end

def diff_to_html(diff, options = {})
  default_options = {
    escape: true
  }
  options = default_options.merge(options)

  p = parse_diff(diff)
  make_html(p, options)
end
