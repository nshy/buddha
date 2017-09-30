#!/usr/bin/ruby

require 'mysql2'
require 'nokogiri'
require 'date'

client = Mysql2::Client.new(username: 'budharu',
                            password: '123budharu123',
                            database: 'buddhadb')

# ext with dot, like .html
def spare_name(dir, name, ext)
  i = 1;
  file = name
  while File.exists?("#{dir}/#{file}#{ext}")
    file = "#{name}-#{i}"
    i += 1
  end
  "#{dir}/#{file}#{ext}"
end

def escape_double_quotes(o)
  o.to_s.gsub(/"/, '/"')
end

def write_preamble(out, preamble)
  out.write("---\n")
  preamble.each do |k, v|
    out.write(k)
    out.write(': "')
    out.write(escape_double_quotes(v))
    out.write("\"\n")
  end
  out.write("---\n\n")
end

client.query('SELECT * from events').each do |row|
  date = row['issuedate'].strftime("%Y-%m-%d")
  href = row['href']

  preamble = {
    title: row['subject'],
    publish_date: date,
    buddha_old_id: row['event_id']
  }
  name = spare_name('tmp/html', date, '.html')
  File.open(name, 'w') do |out|
    write_preamble(out, preamble)
    out.write('<p>')
    out.write(row['announce'])
    out.write('</p>')
    if ((not href.nil?) and (not href.empty?))
      out.write("\n\n")
      out.write("<p><a href=\"#{href}\">ПРИЛОЖЕНИЕ</a></p>\n")
    end
  end
end
