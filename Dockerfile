FROM ubuntu:precise
MAINTAINER Tasso Evangelista <tasso@tassoevan.me>

# Install build dependencies
ENV DEBIAN_FRONTEND noninteractive

# SSH Service
RUN apt-get update && \
    apt-get install -y openssh-server 
EXPOSE 22

RUN apt-get update && \
    apt-get install -y memcached unzip php5 php5-cli php5-dev php5-curl php5-xdebug php-db php-pear php5-sqlite php5-memcache build-essential libaio1 re2c sqlite curl sqlite3 php5-ldap && \
    ln -s /usr/include/php5 /usr/include/php

# Install Oracle Instant Client Basic and SDK
ADD instantclient-basic-linux.x64-12.1.0.2.0.zip /tmp/basic.zip
ADD instantclient-sdk-linux.x64-12.1.0.2.0.zip /tmp/sdk.zip
COPY libxl-lin-3.6.4.tar.gz /tmp/libxl-lin-3.6.4.tar.gz
ADD php_excel-master.zip /tmp/php_excel-master.zip

RUN mkdir -p /opt/oracle/instantclient && \
    unzip -q /tmp/basic.zip -d /opt/oracle && \
    mv /opt/oracle/instantclient_12_1 /opt/oracle/instantclient/lib && \
    unzip -q /tmp/sdk.zip -d /opt/oracle && \
    mv /opt/oracle/instantclient_12_1/sdk/include /opt/oracle/instantclient/include && \
    ln -s /opt/oracle/instantclient/lib/libclntsh.so.12.1 /opt/oracle/instantclient/lib/libclntsh.so && \
    ln -s /opt/oracle/instantclient/lib/libocci.so.12.1 /opt/oracle/instantclient/lib/libocci.so && \
    echo /opt/oracle/instantclient/lib >> /etc/ld.so.conf && \
    ldconfig

# Install PHP OCI8 extension
RUN echo 'instantclient,/opt/oracle/instantclient/lib' | pecl install oci8-2.0.12
ADD oci8.ini /etc/php5/conf.d/oci8.ini
ADD oci8-test.php /tmp/oci8-test.php
RUN php /tmp/oci8-test.php

# Build PHP PDO-OCI extension
RUN pecl channel-update pear.php.net && \
    cd /tmp && \
    pecl download pdo_oci && \
    tar xvf /tmp/PDO_OCI-1.0.tgz -C /tmp && \
    sed 's/function_entry/zend_function_entry/' -i /tmp/PDO_OCI-1.0/pdo_oci.c && \
    sed 's/10.1/12.1/' -i /tmp/PDO_OCI-1.0/config.m4 && \
    cd /tmp/PDO_OCI-1.0 && \
    phpize && \
    ./configure --with-pdo-oci=/opt/oracle/instantclient && \
    make install
ADD pdo_oci.ini /etc/php5/conf.d/pdo_oci.ini
ADD pdo_oci-test.php /tmp/pdo_oci-test.php
RUN php /tmp/pdo_oci-test.php


WORKDIR /tmp
RUN tar xvfz libxl-lin-3.6.4.tar.gz
RUN unzip php_excel-master.zip

RUN apt-get install libxml2-dev && cp -R /usr/include/libxml2/libxml/ /usr/include/

WORKDIR /tmp/php_excel-master
RUN phpize
RUN ./configure --with-libxl-incdir=../libxl-3.6.4.0/include_c --with-libxl-libdir=../libxl-3.6.4.0/lib64
RUN make && make install

ADD excel.ini /etc/php5/apache2/conf.d/excel.ini
ADD xdebug.ini /etc/php5/apache2/conf.d/xdebug.ini
RUN apt-get install memcached

VOLUME ["/var/www/html"]
