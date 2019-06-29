FROM ubuntu:16.04
MAINTAINER dimasabyuk@gmail.com

RUN apt-get update && apt-get install -y zabbix-server-mysql

ENV MYSQL_USER=admin \
    MYSQL_PASS=**111** \
    
# mysql-server mysql-client \
#!/bin/bash






EXPOSE 22 80
