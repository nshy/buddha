steps to grab news from old site:

1. create file with news nodes, say tmp/nodes.txt
2. download pages into tmp/html
  >./load.sh < tmp/nodes.txt
3. clean empty files (some news are forbidden to download)
current forbidden nodes are stored in forbidden.txt
