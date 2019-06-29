FROM ubuntu:16.04
MAINTAINER dimasabyuk@gmail.com

#       MYSQL_VERSION=5.*.*\
#       MYSQL_DATA_DIR=/var/lib/mysql \
#       MYSQL_RUN_DIR=/run/mysqld \
#       MYSQL_LOG_DIR=/var/log/mysql

RUN echo "mysql-server mysql-server/root_password password root" | debconf-set-selections
RUN echo "mysql-server mysql-server/root_password_again password root" | debconf-set-selections


RUN apt-get update && apt-get install -y \
        zabbix-server-mysql\
        vim


#!/bin/bash
EXPOSE 22 80 3306/tcp

