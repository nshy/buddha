=Usage example:

0. copy database dump to tmp/dump.txt
1. load database from dump into mysql
  >./load.sh
2. convert records in DB starting from node 366 into tmp/html dir
  >./extract_html.rb 366
3. convert html into asciidoc with pandoc, result is in tmp/adoc dir
  >./html-2-adoc.sh
4. check you don't miss any text on conversion,
this will print all nodes that need manual check:
  >./check-text.sh
  >367
  >391
  >395
see difference
  >vimdiff tmp/text/adoc/395.txt tmp/text/html/395.txt
fix tmp/html/395.html and rerun 3 & 4 steps.
