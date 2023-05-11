#!/usr/bin/env bash

MYSQL_DOCKER_NAME="mysql"

tiup playground --tiflash 0 &

# stop & rm the container if exist
old_container=$(docker ps -a | grep mysql | awk -F ' ' '{print $1}')
docker stop ${old_container} && docker rm ${old_container}
docker run --name ${MYSQL_DOCKER_NAME} -e MYSQL_ALLOW_EMPTY_PASSWORD=yes -p 3306:3306 -d mysql:8.0
