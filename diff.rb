def diff_to_html(diff)
  klasses = { ' ' => 'context', '+' => 'add', '-' => 'del' }
  lines = diff.split("\n")
  l = lines.shift
  res = []
  while l and l[0] = 'd'
    # skip index, ---
    lines.shift; lines.shift
    path = lines.shift[6..-1]
    res << \
    <<-END
      <div class="file">
        <div class="path">#{path}</div>
    END
    l = lines.shift
    while l and l[0] == '@'
      lnum = /^@@ -([^,]+)/.match(l)[1]
      res << \
      <<-END
        <div class="line">
          <span class="title">Строка:</span>
          <span class="value">#{lnum}</span>
        </div>
      END
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
