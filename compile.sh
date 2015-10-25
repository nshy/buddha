#!/bin/bash

for path in assets/css/*.scss; do
  file=`basename $path`
  name=${file%.scss}
  sass "$path" > "public/css/${name}.css"
done
