1. edit pages to download and convert in tmp/pages.rb
  format is: geshe-node => 'filename'
  PAGES = {
    2190 => "2015-ershovo",
    2217 => "2015-autumn-paramitas",
    2225 => "2015-autumn-guru-yoga",
    2231 => "2016-spring-guru-yoga",
    2234 => "2016-spring-shamatha"
  }

2. download pages to tmp/html
  > ./download.rb
3. convert pages from tmp/html to tmp/xml
  > ./convert.rb
4. you probably need to edit titles in xml etc, then after you copy
  the files to $site_data/teachings you need to update media link sizes
  with update_records_sizes.rb site routine.
