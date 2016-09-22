#!/bin/bash

rm -rf tmp/adoc
mkdir tmp/adoc

for file in tmp/html/*; do
  html=${file#tmp/html/}
  node=${html%.html}
  pandoc -f html -t asciidoc -o "tmp/adoc/${node}.adoc" $file
done
