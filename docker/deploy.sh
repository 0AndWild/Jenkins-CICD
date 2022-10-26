#!/bin/bash

#nginx 컨테이너가 떠있는지 확인
EXIST_NGINX=$(docker ps | grep nginx-webserver)
#떠있지 않으면 nginx 서버를 구동한다 이미 구동중이라면 skip
if [ -z "$EXIST_NGINX" ]; then
    echo "nginx container start"
    docker-compose -p nginx-webserver -f /home/ubuntu/nginx/conf.d/docker-compose.nginx.yml up -d
else
    echo "nginx is already running"
fi

sleep 3

#docker 컨테이너 이름
DOCKER_APP_NAME=springboot

# Blue 를 기준으로 현재 떠있는 컨테이너를 체크한다.
EXIST_BLUE1=$(docker-compose -p ${DOCKER_APP_NAME}-blue -f /home/ubuntu/docker/docker-compose.blue.yml ps | grep Up)

# 컨테이너 스위칭
if [ -z "$EXIST_BLUE1" ]; then
    echo "blue up"
    docker-compose -p ${DOCKER_APP_NAME}-blue -f /home/ubuntu/docker/docker-compose.blue.yml up -d
    BEFORE_COMPOSE_COLOR="green"
    AFTER_COMPOSE_COLOR="blue"
else
    echo "green up"
    docker-compose -p ${DOCKER_APP_NAME}-green -f /home/ubuntu/docker/docker-compose.green.yml up -d
    BEFORE_COMPOSE_COLOR="blue"
    AFTER_COMPOSE_COLOR="green"
fi

sleep 3

# 새로운 컨테이너가 제대로 떴는지 확인
EXIST_AFTER=$(docker-compose -p ${DOCKER_APP_NAME}-${AFTER_COMPOSE_COLOR} -f /home/ubuntu/docker/docker-compose.${AFTER_COMPOSE_COLOR}.yml ps | grep Up)

if [ -n "$EXIST_AFTER" ]; then
  # nginx.config를 컨테이너에 맞게 변경해주고 reload 한다
  cp /home/ubuntu/nginx/conf.d/nginx.${AFTER_COMPOSE_COLOR}.conf /home/ubuntu/nginx/conf.d/nginx.conf

  #서버를중단하지 않고 변경된 사항을 적용시켜줌
  docker exec nginx-webserver nginx -s reload

  # 이전 컨테이너 종료
  docker-compose -p ${DOCKER_APP_NAME}-${BEFORE_COMPOSE_COLOR} -f /home/ubuntu/docker/docker-compose.${BEFORE_COMPOSE_COLOR}.yml down
  echo "$BEFORE_COMPOSE_COLOR down"
fi
