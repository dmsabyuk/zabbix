FROM ubuntu:16.04
MAINTAINER dimasabyuk@gmail.com

ENV     MYSQL_USER=dima \
        MYSQL_VERSION=5.*.*\
        MYSQL_DATA_DIR=/var/lib/mysql \
        MYSQL_RUN_DIR=/run/mysqld \
        MYSQL_LOG_DIR=/var/log/mysql



RUN apt-get update && apt-get install -y zabbix-server-mysql && \
mysql-server=${MYSQL_VERSION} mysql-client

RUN echo "mysql-server mysql-server/root_password password root" | debconf-set-selections
RUN echo "mysql-server mysql-server/root_password_again password root" | debconf-set-selections

EXPOSE 3306/tcp

#CMD    MYSQL_USER=admin \
#       MYSQL_PASS=**111** \


#!/bin/bash
EXPOSE 22 80

