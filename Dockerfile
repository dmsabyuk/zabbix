FROM ubuntu:16.04
MAINTAINER dimasabyuk@gmail.com

RUN apt-get update && apt-get install -y zabbix-server-mysql && \
# mysql-server mysql-client \

 { \
        echo debconf debconf/frontend select Noninteractive; \
        echo mysql-community-server mysql-community-server/data-dir \
            select ''; \
        echo mysql-community-server mysql-community-server/root-pass \
            password '111'; \
        echo mysql-community-server mysql-community-server/re-root-pass \
            password '111'; \
        echo mysql-community-server mysql-community-server/remove-test-db \
            select true; \
    } | debconf-set-selections \

#!/bin/bash






EXPOSE 22 80
