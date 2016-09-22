#!/bin/bash

rm -rf tmp/text
rm -rf tmp/back
mkdir tmp/back
mkdir tmp/text
mkdir tmp/text/html
mkdir tmp/text/adoc

for file in tmp/adoc/*; do
  adoc=${file#tmp/adoc/}
  node=${adoc%.adoc}
  asciidoctor -s $file -o "tmp/back/${node}.html"
done

ruby -r "`pwd`/routines" <<END

extract_text('tmp/html', 'tmp/text/html')
extract_text('tmp/back', 'tmp/text/adoc')
END

for file in tmp/text/adoc/*; do
  adoc=${file#tmp/text/adoc/}
  node=${adoc%.txt}
  diff -u "tmp/text/adoc/${node}.txt" \
          "tmp/text/html/${node}.txt" >/dev/null || echo $node
done
