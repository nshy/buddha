#!/bin/bash

set -xe

# before stopping the server try to merge in upstream changes
cd main
git fetch server
git rebase server/master
cd ..

ssh buddha.ru <<-END
set -xe

cd buddha
sudo systemctl stop buddha.ru
sudo systemctl stop buddha.ru-watch
END

git push
cd main
git push
cd ..

ssh buddha.ru <<-END
set -xe

export LANG=ru_RU.utf8
export LC_MESSAGES=en_US.utf8

cd buddha
git pull

cd main
git pull
cd ..

sudo bundle install
./create.rb
./sync.rb
rm -rf .cache/*
sudo systemctl start buddha.ru
sudo systemctl start buddha.ru-watch
END
