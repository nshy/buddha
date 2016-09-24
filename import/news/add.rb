#!/bin/ruby

require_relative 'routines.rb'
require 'preamble'

from = "tmp/adoc"
to = "../../data/news"

client = Mysql2::Client.new(username: 'budharu',
                            password: '123budharu123',
                            database: 'buddhadb2')

each_file(from) do |path|
  id = path_to_id(path)
  query = <<END
  SELECT
    node.created,
    node_revisions.title
  FROM #{news_table}
  WHERE node.nid = #{id}
END

  info = client.query(query).first
  date = Time.at(info['created']).strftime('%Y-%m-%d')
  dst = "#{to}/#{date}.adoc"
  i = 1
  while File.exists?(dst) do
    dst = "#{to}/#{date}-#{i}.adoc"
    i += 1
  end
  File.open(dst, 'w') do |out|
    out.write("---\n")
    out.write("title: \"")
    out.write(info['title'])
    out.write("\"\n")
    out.write("publish_date: \"")
    out.write(date)
    out.write("\"\n")
    out.write("buddha_node: \"")
    out.write(id)
    out.write("\"\n")
    out.write("---\n\n")
    File.open(path) do |file|
      out.write(file.read)
    end
  end
end
