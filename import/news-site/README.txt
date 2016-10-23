steps to grab news from old site:

1. create file with news nodes, say tmp/nodes.txt
2. download pages into tmp/html
  >./load.sh < tmp/nodes.txt
3. clean empty files (some news are forbidden to download)
current forbidden nodes are stored in forbidden.txt
4. extract news from htmls into tmp/news
  rm -rf tmp/news/* && ./extract.rb

Correct preamble is added, files are ready to be put on site data. However some
grabbed html has no news publish date, thus they stored as ${id}.html and have
unfilled 'publish_date' in metadata. These have to be fixed manually.

BEWARE! extract.rb need to be fixed to handle titles
with double quotes.
