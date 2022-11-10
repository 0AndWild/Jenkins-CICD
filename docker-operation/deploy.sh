#!/bin/bash

#Nginx.conf 파일경로
NGINX_DIR=/home/ec2-user/nginx/conf.d
#Docker-compose 파일경로
DOCKER_DIR=/home/ec2-user/docker-operation
#docker 컨테이너 이름
DOCKER_APP_NAME=springboot

#nginx 컨테이너가 떠있는지 확인
EXIST_NGINX=$(docker ps | grep nginx-webserver)
#떠있지 않으면 nginx 서버를 구동한다 이미 구동중이라면 skip
if [ -z "$EXIST_NGINX" ]; then
    echo "nginx container start"
    docker-compose -p nginx-webserver -f ${NGINX_DIR}/docker-compose.nginx.yml up -d
else
    echo "nginx is already running"
fi

sleep 5

# Blue 를 기준으로 현재 떠있는 컨테이너를 체크한다.
EXIST_BLUE_A=$(docker-compose -p ${DOCKER_APP_NAME}-blue-a -f ${DOCKER_DIR}/docker-compose.blue1.yml ps --status=running | grep ${DOCKER_APP_NAME}-blue-a)
EXIST_BLUE_B=$(docker-compose -p ${DOCKER_APP_NAME}-blue-b -f ${DOCKER_DIR}/docker-compose.blue2.yml ps --status=running | grep ${DOCKER_APP_NAME}-blue-b)

# 컨테이너 스위칭
if [ -z "$EXIST_BLUE_A" ] && [ -z "$EXIST_BLUE_B" ]; then
    echo "blue up"
    docker-compose -p ${DOCKER_APP_NAME}-blue-a -f ${DOCKER_DIR}/docker-compose.blue1.yml up -d
    docker-compose -p ${DOCKER_APP_NAME}-blue-b -f ${DOCKER_DIR}/docker-compose.blue2.yml up -d
    IDLE_PORT=8080
    BEFORE_COMPOSE_COLOR="green"
    AFTER_COMPOSE_COLOR="blue"
else
    echo "green up"
    docker-compose -p ${DOCKER_APP_NAME}-green-a -f ${DOCKER_DIR}/docker-compose.green1.yml up -d
    docker-compose -p ${DOCKER_APP_NAME}-green-b -f ${DOCKER_DIR}/docker-compose.green2.yml up -d
    IDLE_PORT=8082
    BEFORE_COMPOSE_COLOR="blue"
    AFTER_COMPOSE_COLOR="green"
fi

sleep 5

# 새로운 컨테이너가 제대로 떴는지 확인
EXIST_AFTER_A=$(docker-compose -p ${DOCKER_APP_NAME}-${AFTER_COMPOSE_COLOR}-a -f ${DOCKER_DIR}/docker-compose.${AFTER_COMPOSE_COLOR}"1".yml ps --status=running | grep ${DOCKER_APP_NAME}-${AFTER_COMPOSE_COLOR}-a)
EXIST_AFTER_B=$(docker-compose -p ${DOCKER_APP_NAME}-${AFTER_COMPOSE_COLOR}-b -f ${DOCKER_DIR}/docker-compose.${AFTER_COMPOSE_COLOR}"2".yml ps --status=running | grep ${DOCKER_APP_NAME}-${AFTER_COMPOSE_COLOR}-b)
if [ -n "$EXIST_AFTER_A" ] && [ -n "$EXIST_AFTER_B" ]; then
  # health check
  echo "> Health Check Start!"
  echo "> IDLE_PORT: $IDLE_PORT"
  echo "> curl -s http://{nginx 서버 ip 주소}:$IDLE_PORT "
  sleep 5

  for RETRY_COUNT in {1..10}
  do
    RESPONSE=$(curl -s http://3.36.66.225:${IDLE_PORT})
    UP_COUNT=$(echo ${RESPONSE} | grep "timestamp" | wc -l)

    if [ ${UP_COUNT} -ge 1 ]
    then # $up_count >= 1
        echo "> Health check 성공"
        # nginx.config를 컨테이너에 맞게 변경해주고 reload 한다
        cp ${NGINX_DIR}/nginx.${AFTER_COMPOSE_COLOR}.conf ${NGINX_DIR}/nginx.conf
        #서버를중단하지 않고 변경된 사항을 적용시켜줌
        docker exec nginx-webserver nginx -s reload

        sleep 5

        # 이전 컨테이너 종료
        docker-compose -p ${DOCKER_APP_NAME}-${BEFORE_COMPOSE_COLOR}-a -f ${DOCKER_DIR}/docker-compose.${BEFORE_COMPOSE_COLOR}"1".yml down
        docker-compose -p ${DOCKER_APP_NAME}-${BEFORE_COMPOSE_COLOR}-b -f ${DOCKER_DIR}/docker-compose.${BEFORE_COMPOSE_COLOR}"2".yml down
        echo "$BEFORE_COMPOSE_COLOR down"
    break

    else
          echo "> Health check의 응답을 알 수 없거나 혹은 실행 상태가 아닙니다."
          echo "> Health check: ${RESPONSE}"
    fi

    if [ ${RETRY_COUNT} -eq 10 ]
      then
        echo "> Health check 실패. "
        echo "> 엔진엑스에 연결하지 않고 배포를 종료합니다."
        exit 1
      fi

      echo "> Health check 연결 실패. 재시도..."
      sleep 7
    done

else
  echo "> 새로운 ${AFTER_COMPOSE_COLOR} 컨테이너가 정상적으로 띄워지지 않았습니다."
fi
