steps to grab news from prehistoric site:

1. put dump into file buddhadb.dump
2. load database from dump into mysql
  >./load.sh
3. extract news from 'events' info tmp/html
  >./extract.sh
events are ready to be placed into new site data dir
