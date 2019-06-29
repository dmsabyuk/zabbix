FROM ubuntu:16.04
MAINTAINER dimasabyuk@gmail.com

RUN apt-get update && apt-get install -y zabbix-server-mysql

ADD run.sh /run.sh

ENV MYSQL_USER=admin \
    MYSQL_PASS=**Random** \
    ON_CREATE_DB=**False** \
    REPLICATION_MASTER=**False** \
    REPLICATION_SLAVE=**False** \
    REPLICATION_USER=replica \
    REPLICATION_PASS=replica
    
# mysql-server mysql-client \
#!/bin/bash


EXPOSE 22 80

#########################################################
FROM ubuntu:16.04
MAINTAINER dimasabyuk@gmail.com

ENV     MYSQL_USER=dima \
        MYSQL_VERSION=5.*.*\
        MYSQL_DATA_DIR=/var/lib/mysql \
        MYSQL_RUN_DIR=/run/mysqld \
        MYSQL_LOG_DIR=/var/log/mysql



RUN apt-get update && apt-get install -y zabbix-server-mysql && \
mysql-server=${MYSQL_VERSION} mysql-client


EXPOSE 3306/tcp

#CMD    MYSQL_USER=admin \
#       MYSQL_PASS=**111** \


#!/bin/bash


