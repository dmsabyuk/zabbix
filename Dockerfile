FROM ubuntu:16.04
MAINTAINER dimasabyuk@gmail.com

RUN apt-get update && apt-get upgrade && \
apt-get install -y apache2 openssh-server mysql-server mysql-client zabbix 

#!/bin/bash


# Script trace mode
if [ "${DEBUG_MODE}" == "true" ]; then
    set -o xtrace
fi

# Type of Zabbix component
# Possible values: [server, proxy, agent, frontend, java-gateway, appliance]
zbx_type=${ZBX_TYPE}
# Type of Zabbix database
# Possible values: [mysql, postgresql]
zbx_db_type=${ZBX_DB_TYPE}
# Type of web-server. Valid only with zbx_type = frontend
# Possible values: [apache, nginx]
zbx_opt_type=${ZBX_OPT_TYPE}

# Default Zabbix installation name
# Used only by Zabbix web-interface
ZBX_SERVER_NAME=${ZBX_SERVER_NAME:-"Zabbix docker"}
# Default Zabbix server host
ZBX_SERVER_HOST=${ZBX_SERVER_HOST:-"zabbix-server"}
# Default Zabbix server port number
ZBX_SERVER_PORT=${ZBX_SERVER_PORT:-"10051"}

# Default directories
# User 'zabbix' home directory
ZABBIX_USER_HOME_DIR="/var/lib/zabbix"
# Configuration files directory
ZABBIX_ETC_DIR="/etc/zabbix"
# Web interface www-root directory
ZBX_FRONTEND_PATH="/usr/share/zabbix"

configure_db_mysql() {
    [ "${DB_SERVER_HOST}" != "localhost" ] && return

    echo "** Configuring local MySQL server"

    MYSQL_ALLOW_EMPTY_PASSWORD=true
    MYSQL_DATA_DIR="/var/lib/mysql"

    if [ -f "/etc/mysql/my.cnf" ]; then
        MYSQL_CONF_FILE="/etc/mysql/my.cnf"
    elif [ -f "/etc/my.cnf.d/server.cnf" ]; then
        MYSQL_CONF_FILE="/etc/my.cnf.d/server.cnf"
        DB_SERVER_SOCKET="/var/lib/mysql/mysql.sock"
    else
        echo "**** Could not found MySQL configuration file"
        exit 1
    fi

    if [ -f "/usr/bin/mysqld" ]; then
        MYSQLD=/usr/bin/mysqld
    elif [ -f "/usr/sbin/mysqld" ]; then
        MYSQLD=/usr/sbin/mysqld
    elif [ -f "/usr/libexec/mysqld" ]; then
        MYSQLD=/usr/libexec/mysqld
    else
        echo "**** Could not found mysqld binary file"
        exit 1
    fi

    sed -Ei 's/^(bind-address|log)/#&/' "$MYSQL_CONF_FILE"

    if [ ! -d "$MYSQL_DATA_DIR/mysql" ]; then
        [ -d "$MYSQL_DATA_DIR" ] || mkdir -p "$MYSQL_DATA_DIR"

        chown -R mysql:mysql "$MYSQL_DATA_DIR"

        echo "** Installing initial MySQL database schemas"
        mysql_install_db --user=mysql --datadir="$MYSQL_DATA_DIR" 2>&1
    else
        echo "**** MySQL data directory is not empty. Using already existing installation."
        chown -R mysql:mysql "$MYSQL_DATA_DIR"
    fi

    mkdir -p /var/run/mysqld
    ln -s /var/run/mysqld /run/mysqld
    chown -R mysql:mysql /var/run/mysqld
    chown -R mysql:mysql /run/mysqld

    echo "** Starting MySQL server in background mode"

    nohup $MYSQLD --basedir=/usr --datadir=/var/lib/mysql --plugin-dir=/usr/lib/mysql/plugin \
            --user=mysql --log-output=none --pid-file=/var/lib/mysql/mysqld.pid \
            --port=3306 --character-set-server=utf8 --collation-server=utf8_bin &
}
# Check prerequisites for MySQL database
check_variables_mysql() {
    local type=$1

    DB_SERVER_HOST=${DB_SERVER_HOST:-"mysql-server"}
    DB_SERVER_PORT=${DB_SERVER_PORT:-"3306"}
    USE_DB_ROOT_USER=false
    CREATE_ZBX_DB_USER=false

    if [ ! -n "${MYSQL_USER}" ] && [ "${MYSQL_RANDOM_ROOT_PASSWORD}" == "true" ]; then
        echo "**** Impossible to use MySQL server because of unknown Zabbix user and random 'root' password"
        exit 1
    fi

    if [ ! -n "${MYSQL_USER}" ] && [ ! -n "${MYSQL_ROOT_PASSWORD}" ] && [ "${MYSQL_ALLOW_EMPTY_PASSWORD}" != "true" ]; then
        echo "*** Impossible to use MySQL server because 'root' password is not defined and it is not empty"
        exit 1
    fi

    if [ "${MYSQL_ALLOW_EMPTY_PASSWORD}" == "true" ] || [ -n "${MYSQL_ROOT_PASSWORD}" ]; then
        USE_DB_ROOT_USER=true
        DB_SERVER_ROOT_USER="root"
        DB_SERVER_ROOT_PASS=${MYSQL_ROOT_PASSWORD:-""}
    fi

    [ -n "${MYSQL_USER}" ] && CREATE_ZBX_DB_USER=true

    # If root password is not specified use provided credentials
    DB_SERVER_ROOT_USER=${DB_SERVER_ROOT_USER:-${MYSQL_USER}}
    [ "${MYSQL_ALLOW_EMPTY_PASSWORD}" == "true" ] || DB_SERVER_ROOT_PASS=${DB_SERVER_ROOT_PASS:-${MYSQL_PASSWORD}}
    DB_SERVER_ZBX_USER=${MYSQL_USER:-"zabbix"}
    DB_SERVER_ZBX_PASS=${MYSQL_PASSWORD:-"zabbix"}

    if [ "$type" == "proxy" ]; then
        DB_SERVER_DBNAME=${MYSQL_DATABASE:-"zabbix_proxy"}
    else
        DB_SERVER_DBNAME=${MYSQL_DATABASE:-"zabbix"}
    fi
}
}

prepare_web_server_apache() {
    if [ -d "/etc/apache2/sites-available" ]; then
        APACHE_SITES_DIR=/etc/apache2/sites-available
    elif [ -d "/etc/apache2/conf.d" ]; then
        APACHE_SITES_DIR=/etc/apache2/conf.d
    elif [ -d "/etc/httpd/conf.d" ]; then
        APACHE_SITES_DIR=/etc/httpd/conf.d
    else
        echo "**** Apache is not available"
        exit 1
    fi
  echo "** Adding Zabbix virtual host (HTTP)"
    if [ -f "$ZABBIX_ETC_DIR/apache.conf" ]; then
        ln -s "$ZABBIX_ETC_DIR/apache.conf" "$APACHE_SITES_DIR/zabbix.conf"
        if [ -f "/usr/sbin/a2dissite" ]; then
            /usr/sbin/a2ensite zabbix.conf 1>/dev/null
        fi
    else
        echo "**** Impossible to enable HTTP virtual host"
    fi

    if [ -f "/etc/apache2/conf.d/ssl.conf" ]; then
        rm -f "/etc/apache2/conf.d/ssl.conf"
    fi

    if [ -f "/etc/ssl/apache2/ssl.crt" ] && [ -f "/etc/ssl/apache2/ssl.key" ]; then
        echo "** Enable SSL support for Apache2"
        if [ -f "/usr/sbin/a2enmod" ]; then
            /usr/sbin/a2enmod ssl 1>/dev/null
        fi

        echo "** Adding Zabbix virtual host (HTTPS)"
        if [ -f "$ZABBIX_ETC_DIR/apache_ssl.conf" ]; then
            ln -s "$ZABBIX_ETC_DIR/apache_ssl.conf" "$APACHE_SITES_DIR/zabbix_ssl.conf"
            if [ -f "/usr/sbin/a2dissite" ]; then
                /usr/sbin/a2ensite zabbix_ssl.conf 1>/dev/null
            fi
}
  if [ $type == "server" ]; then
        update_config_var $ZBX_CONFIG "HistoryStorageURL" "${ZBX_HISTORYSTORAGEURL}"
        update_config_var $ZBX_CONFIG "HistoryStorageTypes" "${ZBX_HISTORYSTORAGETYPES}"
    fi

    update_config_var $ZBX_CONFIG "DBSocket" "${DB_SERVER_SOCKET}"

    if [ "$type" == "proxy" ]; then
        update_config_var $ZBX_CONFIG "ProxyLocalBuffer" "${ZBX_PROXYLOCALBUFFER}"
        update_config_var $ZBX_CONFIG "ProxyOfflineBuffer" "${ZBX_PROXYOFFLINEBUFFER}"
        update_config_var $ZBX_CONFIG "HeartbeatFrequency" "${ZBX_PROXYHEARTBEATFREQUENCY}"
        update_config_var $ZBX_CONFIG "ConfigFrequency" "${ZBX_CONFIGFREQUENCY}"
        update_config_var $ZBX_CONFIG "DataSenderFrequency" "${ZBX_DATASENDERFREQUENCY}"
    fi

    update_config_var $ZBX_CONFIG "StatsAllowedIP" "${ZBX_STATSALLOWEDIP}"

    update_config_var $ZBX_CONFIG "StartPollers" "${ZBX_STARTPOLLERS}"
    update_config_var $ZBX_CONFIG "StartIPMIPollers" "${ZBX_IPMIPOLLERS}"
    update_config_var $ZBX_CONFIG "StartPollersUnreachable" "${ZBX_STARTPOLLERSUNREACHABLE}"
    update_config_var $ZBX_CONFIG "StartTrappers" "${ZBX_STARTTRAPPERS}"
    update_config_var $ZBX_CONFIG "StartPingers" "${ZBX_STARTPINGERS}"
    update_config_var $ZBX_CONFIG "StartDiscoverers" "${ZBX_STARTDISCOVERERS}"
    update_config_var $ZBX_CONFIG "StartHTTPPollers" "${ZBX_STARTHTTPPOLLERS}"

    if [ "$type" == "server" ]; then
        update_config_var $ZBX_CONFIG "StartPreprocessors" "${ZBX_STARTPREPROCESSORS}"
        update_config_var $ZBX_CONFIG "StartTimers" "${ZBX_STARTTIMERS}"
        update_config_var $ZBX_CONFIG "StartEscalators" "${ZBX_STARTESCALATORS}"
        update_config_var $ZBX_CONFIG "StartAlerters" "${ZBX_STARTALERTERS}"
    fi

    ZBX_JAVAGATEWAY_ENABLE=${ZBX_JAVAGATEWAY_ENABLE:-"false"}
    if [ "${ZBX_JAVAGATEWAY_ENABLE}" == "true" ]; then
        update_config_var $ZBX_CONFIG "JavaGateway" "${ZBX_JAVAGATEWAY:-"zabbix-java-gateway"}"
        update_config_var $ZBX_CONFIG "JavaGatewayPort" "${ZBX_JAVAGATEWAYPORT}"
        update_config_var $ZBX_CONFIG "StartJavaPollers" "${ZBX_STARTJAVAPOLLERS:-"5"}"
    else
        update_config_var $ZBX_CONFIG "JavaGateway"
        update_config_var $ZBX_CONFIG "JavaGatewayPort"
        update_config_var $ZBX_CONFIG "StartJavaPollers"
    fi



EXPOSE 22 80
