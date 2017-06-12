def diff_path(path, mode)
  if mode == :changed
    path
  else
    present = { added: 'Добавлен', deleted: 'Удален' }
    "#{path} [#{present[mode]}]"
  end
end

def diff_to_html(diff)
  klasses = { ' ' => 'context', '+' => 'add', '-' => 'del' }
  lines = diff.split("\n")
  l = lines.shift
  res = []
  while l and l.start_with?('diff')
    mode = :changed
    # skip till ---
    l = lines.shift while not l.start_with?('---')
    a = l.sub(/^--- /, '')
    mode = :added if a == '/dev/null'
    l = lines.shift
    b = l.sub(/^\+\+\+ /, '')
    mode = :deleted if b == '/dev/null'
    path = a != '/dev/null' ? a : b
    path = path.sub(/.\//, '')
    res << \
    <<-END
      <div class="file">
        <div class="path">#{diff_path(path, mode)}</div>
    END
    l = lines.shift
    while l and l[0] == '@'
      if mode == :changed
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
