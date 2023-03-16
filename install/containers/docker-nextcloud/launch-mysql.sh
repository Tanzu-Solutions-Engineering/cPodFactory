#!/bin/sh

VOLUME=/data/Volumes/mysql
docker run -d --name mysql -p 3306:3306 -p 8080:80 -v ${VOLUME}:/var/lib/mysql bdereims/mysql-phpmyadmin
