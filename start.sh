#!/bin/bash
if [ ! -d /data/www ]; then
  mkdir data/www && cd /data/www/ && git init
  git remote add origin $(echo $git_url)
  git pull origin master
else
  cd /data/www/ && git init
  git pull origin master
fi
cp -f /data/www/configs/run.sh /run.sh && sed -i -e 's/\r//g' /run.sh && sed -i -e 's/^M//g' /run.sh && chmod +x /*.sh
. /run.sh
