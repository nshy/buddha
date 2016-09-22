require 'mysql2'
require 'nokogiri'

def news_table
  table = <<END
  node
    INNER JOIN
      (
        SELECT
          distinct(node_revisions.nid)
        FROM node_revisions
          INNER JOIN term_node
            ON term_node.nid = node_revisions.nid
        WHERE term_node.tid IN (1, 2, 3, 4, 5, 6, 16)
      ) AS news
      ON node.nid = news.nid
    LEFT OUTER JOIN node_revisions
      ON node.nid = node_revisions.nid
END
  table
end

def extract_html(from)
  client = Mysql2::Client.new(username: 'budharu',
                              password: '123budharu123',
                              database: 'buddhadb2')

  query = <<END
  SELECT
    node.created,
    node.nid,
    node_revisions.body
  FROM #{news_table}
END

  client.query(query).each do |row|
    next if row['nid'].to_i < from
    File.open("tmp/html/#{row['nid']}.html", "w") do |file|
      file << Nokogiri::HTML(row['body'].gsub("\r", '')).to_html
    end
  end
end

def each_file(dir)
  Dir.entries(dir).each do |p|
    # skip any dot files
    next if not /^\./.match(p).nil?
    yield dir + '/' +  p
  end
end

def parse_html(path)
  f = File.open(path)
  yield Nokogiri::HTML(f, nil, 'utf-8')
  f.close
end

def path_to_id path
    File.basename(path).gsub(/\.html$/, '')
end

def extract_text(from, to)
  each_file from do |path|
    parse_html path do |html|
      File.open("#{to}/#{path_to_id(path)}.txt", "w") do |file|
        file << html.text.gsub(/\s+/, "\n").strip
      end
    end
  end
end
