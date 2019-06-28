FROM ubuntu:16.04
MAINTAINER dimasabyuk@gmail.com

RUN apt-get update && apt-get upgrade && \
apt-get install -y apache2 openssh-server mysql-server mysql-client zabbix 

#!/bin/bash





EXPOSE 22 80
