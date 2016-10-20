#!/bin/bash

rm -rf tmp/html
mkdir -p tmp/html

cat $1 | while read node
do
  wget "buddha.ru/content/?q=node/$node" -O "tmp/html/${node}.html"
done
