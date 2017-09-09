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
       file.hunks[0].changes.size < 3 and
       file.hunks[0].changes.all? { |c| c =~/.\/bsym\// }
      file.mode = :binary
    end
    patch << file
  end
  patch
end
