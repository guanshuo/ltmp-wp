FROM alpine:edge
RUN  \

# apt install
apk add --update --no-cache --virtual .build-deps \
    # public
    autoconf \
    coreutils \
    libressl-dev \
    make \
    
    # php
    dpkg-dev dpkg \
    file \
    g++ \
    gcc \
    libc-dev \
    pkgconf \
    re2c \
    curl-dev \
    libedit-dev \
    libsodium-dev \
    libxml2-dev \
    sqlite-dev \
    
    # mariadb
    attr \
    bison \
    build-base \
    cmake \
    gnupg \
    libaio-dev \
    linux-headers \
    ncurses-dev \
    patch \
    readline-dev \
    zlib-dev &&

apk add --no-cache --virtual .run-deps \
    # public
    git \
    memcached \
    openssl openssh-server \
    supervisor \
    
    # php
    ca-certificates \
    curl \
    tar \
    xz \
    libressl \
    
    # mariadb
    libaio \
    libstdc++ \
    pwgen \
    sudo \
    tzdata &&

# Install mariadb
git clone --recurse-submodules --depth=1 https://github.com/MariaDB/server.git && \
cd server && cmake . \
    -DCMAKE_INSTALL_PREFIX=/usr/local/mysql \
    -DMYSQL_DATADIR=/data/mysql \
    -DSYSCONFDIR=/etc/mysql \
    -DWITHOUT_TOKUDB=1 \
    -DMYSQL_UNIX_ADDR=/tmp/mysql.sock \
    -DDEFAULT_CHARSET=utf8 \
    -DDEFAULT_COLLATION=utf8_general_ci \
    -DWITHOUT_INNOBASE_STORAGE_ENGINE=1 \
    -DWITHOUT_ARCHIVE_STORAGE_ENGINE=1 \
    -DWITHOUT_BLACKHOLE_STORAGE_ENGINE=1 \
&& make -j "$(nproc)" && make install && make clean && rm -rf /mariadb.tar.gz /mariadb && cd / && \ 

# Install php
git clone --recurse-submodules --depth=1 https://github.com/php/php-src.git && \
cd php-src && ./buildconf && ./configure \
    --prefix=/usr/local/php7 \
    --exec-prefix=/usr/local/php7 \
    --bindir=/usr/local/php7/bin \
    --sbindir=/usr/local/php7/sbin \
    --includedir=/usr/local/php7/include \
    --libdir=/usr/local/php7/lib/php \
    --mandir=/usr/local/php7/php/man \
    --with-config-file-path=/usr/local/php7/etc \
    --with-mysql-sock=/var/run/mysqld/mysqld.sock \
    --with-mhash \
    --with-openssl \
    --with-mysqli=shared,mysqlnd \
    --with-pdo-mysql=shared,mysqlnd \
    --with-gd \
    --with-iconv \
    --with-zlib \
    --enable-zip \
    --enable-inline-optimization \
    --disable-debug \
    --disable-rpath \
    --enable-shared \
    --enable-xml \
    --enable-bcmath \
    --enable-shmop \
    --enable-sysvsem \
    --enable-mbregex \
    --enable-mbstring \
    --enable-ftp \
    --enable-pcntl \
    --enable-sockets \
    --with-xmlrpc \
    --enable-soap \
    --without-pear \
    --with-gettext \
    --enable-session \
    --with-curl \
    --with-jpeg-dir \
    --with-freetype-dir \
    --enable-opcache \
    --enable-fpm \
    --with-fpm-user=www-data \
    --with-fpm-group=www-data \
    --without-gdbm \
    --enable-fast-install \
    --disable-fileinfo \
&& make -j "$(nproc)" && make install && make clean && rm -rf /php-src && cd / && \ 

# Install tengine
git clone --recurse-submodules --depth=1 https://github.com/alibaba/tengine.git && \
cd tengine && ./configure \
    --with-http_concat_module \
&& make -j "$(nproc)" && make install && make clean && rm -rf /tengine && cd / && \ 

# Install tingyun
wget http://download.networkbench.com/agent/php/2.7.0/tingyun-agent-php-2.7.0.x86_64.deb?a=1498149881851 -O tingyun-agent-php.deb && \
wget http://download.networkbench.com/agent/system/1.1.1/tingyun-agent-system-1.1.1.x86_64.deb?a=1498149959157 -O tingyun-agent-system.deb && \
dpkg -i tingyun-agent-php.deb && dpkg -i tingyun-agent-system.deb && rm -rf /tingyun-*.deb && \ 

# clean
apk del --purge .build-deps; \
rm -rf /tmp/*; \
rm -rf /var/cache/apk/*

# Start
ADD start.sh /start.sh
RUN sed -i -e 's/\r//g' /start.sh && sed -i -e 's/^M//g' /start.sh && chmod +x /*.sh
VOLUME ["/data"]
EXPOSE 22 80 3306 8388 9001 11211
CMD ["/bin/bash", "/start.sh"]
