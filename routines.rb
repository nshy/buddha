require 'nokogiri'
require_relative 'models'

def theme_file(name)
  "data/themes/#{name}.xml"
end

def themes_node_to_human
  doc = nil
  File.open('data/teachings.xml') do |file|
    doc = ArchiveDocument.new(Nokogiri::XML(file))
  end
  doc.archive.teachings.each do |teachings|
    teachings.theme.each do |theme|
      File.rename(theme_file(theme.page), theme_file(theme.page2))
    end
  end
end
