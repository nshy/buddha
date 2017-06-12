def diff_path(path, action)
  if action == :changed
    path
  else
    present = { added: 'Добавлен', deleted: 'Удален' }
    "#{path} [#{present[action]}]"
  end
end

def diff_to_html(diff)
  klasses = { ' ' => 'context', '+' => 'add', '-' => 'del' }
  lines = diff.split("\n")
  l = lines.shift
  res = []
  while l and l.start_with?('diff')
    action = :changed
    mode = :text
    l = lines.shift while not (l.start_with?('---') or l.start_with?('Binary files'))
    if l.start_with?('---')
      a = l.sub(/^--- /, '')
      l = lines.shift
      b = l.sub(/^\+\+\+ /, '')
    else
      m = /^Binary files (.+) and (.+) differ$/.match(l)
      a = m[1]
      b = m[2]
      mode = :binary
    end
    action = :added if a == '/dev/null'
    action = :deleted if b == '/dev/null'
    path = a != '/dev/null' ? a : b
    path = path.sub(/.\//, '')
    res << \
    <<-END
      <div class="file">
        <div class="path #{mode}">#{diff_path(path, action)}</div>
    END
    l = lines.shift
    while l and l[0] == '@'
      if action == :changed
        lnum = /^@@ -([^,]+)/.match(l)[1]
        res << \
        <<-END
          <div class="line">
            <span class="title">Строка:</span>
            <span class="value">#{lnum}</span>
          </div>
        END
      end
      l = lines.shift
      while l and klasses.keys.include?(c = l[0])
        res << "<pre class='#{klasses[c]}'>"
        while l and l[0] == c
          res << Rack::Utils.escape_html(l)
          l = lines.shift
        end
        res << '</pre>'
      end
    end
    res << "</div>"
  end
  res.join("\n")
end
