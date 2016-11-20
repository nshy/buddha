#!/bin/ruby

# NOTE youtube-upload must be in $PATH
# thus if it is installed in user home then path must be adjusted
# in ~/.bash_profile or similar

require_relative '../../routines.rb'

def get_value(element, xpath)
  e = element.at_xpath(xpath)
  return nil if e.nil?
  value = e.text.strip
  return nil if value.empty?
  value
end

def upload_url(file, title)
  cmd = <<END
  youtube-upload \
    --title='#{title}' \
    --client-secrets='secrets.json' \
    --credentials-file='credentials.yaml' \
    '#{file}'
END

  output = `bash -cl "#{cmd}"`
  return nil if not $?.success?
  output.lines.last.strip
end

options = {
  sorted: true,
  reverse: true
}
each_file('../../data/teachings', options) do |path|
  parse_xml(path) do |xml|
    xml.xpath('//theme').each do |theme|
      theme_title = theme.at_xpath('title').text
      idx = 0;
      theme.xpath('record').each do |record|
        idx += 1
        url = get_value(record, 'video_url')
        # we have no video for this record
        next if url.nil?
        yid = get_value(record, 'youtube_id')
        # already uploaded
        next if not yid.nil?
        file = "download/#{File.basename(url)}"
        # file is missing
        next if not File.exists?(file)

        date = record.at_xpath('record_date').text
        title = "#{date}-N#{idx} #{theme_title}"
        puts title
        id = upload_url(file, title)
        # failed to upload
        next if id.nil?

        record.add_child "  <youtube_id>#{id}</youtube_id}>\n    "
        save_xml(path, xml)
      end
    end
  end
end
