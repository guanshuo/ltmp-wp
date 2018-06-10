FROM alpine:latest
MAINTAINER guanshuo "12610446@qq.com"
ENV PHP_INI_DIR /usr/local/etc/php
RUN  \
mkdir -p $PHP_INI_DIR/conf.d
# 创建用户与数据目录并赋予权限
addgroup -g 82  www-data && adduser -u 82  -D -S -G www-data www-data ; \
addgroup -g 101 mysql    && adduser -u 100 -D -S -s /bin/bash -G mysql mysql && echo "PS1='\w\$ '" >> /home/mysql/.bashrc; \
mkdir -p /data/www   && chown -R www-data:www-data /data/www/ ; \
mkdir -p /data/mysql && chown -R mysql:mysql       /data/mysql/ ; \
chmod +x /usr/local/bin/docker-php-* ; \
# 国内使用阿里云的软件源
echo "http://mirrors.aliyun.com/alpine/latest-stable/main/" > /etc/apk/repositories ; \
# apt包安装
apk add --no-cache --virtual .run-deps \
    # public
    git \
    memcached \
    openssh \
    supervisor \
    tar\
    # mariadb
    libaio \
    libstdc++ \
    pwgen \
    sudo \
    tzdata \
    # php
    ca-certificates \
    curl \
    libgd \
    libjpeg \
    libpng \
    libressl \
    libmemcached \
    xz \
    # nginx
    findutils \
    geoip \
    nghttp2 \
    pcre ; \
apk add --update --no-cache --virtual .build-deps \
    # public
    autoconf \
    build-base \
    coreutils \
    gnupg \
    libressl-dev \
    make \
    zlib-dev \
    # mariadb
    attr \
    bison \
    cmake \
    libaio-dev \
    linux-headers \
    ncurses-dev \
    patch \
    readline-dev \
    # php
    curl-dev \
    dpkg-dev dpkg\ 
    file \
    g++ \
    gcc \
    jpeg-dev \
    libpng-dev \
    libc-dev \
    libedit-dev \
    libsodium-dev \
    libxml2-dev \
    libmemcached-dev \
    pkgconf \
    re2c \
    sqlite-dev \
    # nginx
    geoip-dev\
    libtool \
    pcre-dev ; \
# 升级grep软件包不然无法使用Perl的正则表达式
apk add --upgrade --no-cache grep ; \

# 安装mariadb,先去官网获取最新稳定版版本号，再进行下载
Mariadb_Version=$(curl -s https://downloads.mariadb.org | grep -oPm 1 '(?<=Download).*(?=Stable)' | sed 's/ //g') ; \
wget -c https://downloads.mariadb.org/interstitial/mariadb-${Mariadb_Version}/source/mariadb-${Mariadb_Version}.tar.gz -O master.tar.gz ; \
tar zxvf master.tar.gz && cd mariadb-${Mariadb_Version} && cmake . \
    -DBUILD_CONFIG=mysql_release \
     # 指定CMAKE编译后的安装的目录
    -DCMAKE_INSTALL_PREFIX=/usr \
    -DSYSCONFDIR=/etc/mysql \    
    # 默认数据目录
    -DMYSQL_DATADIR=/data/mysql \
    -DMYSQL_UNIX_ADDR=/run/mysqld/mysqld.sock \
    -DDEFAULT_CHARSET=utf8 \
    -DDEFAULT_COLLATION=utf8_general_ci \
    -DINSTALL_INFODIR=share/mysql/docs \
    -DINSTALL_MANDIR=share/man \
    -DINSTALL_PLUGINDIR=lib/mysql/plugin \
    -DINSTALL_SCRIPTDIR=bin \
    -DINSTALL_INCLUDEDIR=include/mysql \
    -DINSTALL_DOCREADMEDIR=share/mysql \
    -DINSTALL_SUPPORTFILESDIR=share/mysql \
    -DINSTALL_MYSQLSHAREDIR=share/mysql \
    -DINSTALL_DOCDIR=share/mysql/docs \
    -DINSTALL_SHAREDIR=share/mysql \
    -DENABLED_LOCAL_INFILE=1 \    
     # 库文件加载选项
    -DWITH_ZLIB=system \
    -DWITH_SSL=system \
     # 不安装tokudb引擎
    -DPLUGIN_TOKUDB=NO ; \
make -j "$(nproc)" && make install && make clean && cd / && rm -rf master.tar.gz mariadb-${Mariadb_Version} ; \

# 安装php,先去官网获取最新稳定版版本号，再进行下载
Php_Version=$(curl -s http://php.net/downloads.php | sed 's/ //g'| sed ':label;N;s/\n//;b label' | grep -oPm 1 '(?<=Stable\<\/span\>PHP).*?(?=\(\<ahref)' | head -n1) ; \
wget -c http://cn2.php.net/get/php-${Php_Version}.tar.gz/from/this/mirror -O master.tar.gz ; \
export CFLAGS="-fstack-protector-strong -fpic -fpie -O2" \
       CPPFLAGS="-fstack-protector-strong -fpic -fpie -O2" \
       LDFLAGS="-Wl,-O1 -Wl,--hash-style=both -pie" ; \
tar zxvf master.tar.gz && cd php-${Php_Version} && gnuArch="$(dpkg-architecture --query DEB_BUILD_GNU_TYPE)" && ./buildconf --force && ./configure \
    --build="$gnuArch" \
    --with-config-file-path="$PHP_INI_DIR" \
    --with-config-file-scan-dir="$PHP_INI_DIR/conf.d" \
    --with-mysql-sock=/run/mysqld/mysqld.sock \
    --disable-cgi \
    --enable-ftp \
    --enable-mbstring \
    --enable-mysqlnd \
    --with-mysqli=mysqlnd \
    --with-pdo-mysql=mysqlnd \
    --with-sodium=shared \
    --with-curl \
    --with-gd \
    --with-libedit \
    --with-openssl \
    --with-zlib \
    $(test "$gnuArch" = 's390x-linux-gnu' && echo '--without-pcre-jit') \
    --enable-fpm \
    --with-fpm-user=www-data \
    --with-fpm-group=www-data \
&& make -j "$(nproc)" \
&& make install \
&& { find /usr/local/bin /usr/local/sbin -type f -perm +0111 -exec strip --strip-all '{}' + || true; } \
&& make clean \
&& cd / \
&& runDeps="$( \
	scanelf --needed --nobanner --format '%n#p' --recursive /usr/local \
		| tr ',' '\n' \
		| sort -u \
		| awk 'system("[ -e /usr/local/lib/" $1 " ]") == 0 { next } { print "so:" $1 }' \
)" \
&& apk add --no-cache --virtual .run-deps $runDeps \
&& pecl update-channels \ 
&& rm -rf master.tar.gz php-${Php_Version} ; \

# 安装memcach扩展
wget -c https://codeload.github.com/websupport-sk/pecl-memcache/tar.gz/NON_BLOCKING_IO_php7 -O pecl-memcache.tar.gz ; \
tar zxvf pecl-memcache.tar.gz && cd pecl-memcache-NON_BLOCKING_IO_php7 && /usr/local/bin/phpize && ./configure \
    --with-php-config=/usr/local/bin/php-config \
&& make -j "$(nproc)" && make install && make clean && cd / && rm -rf pecl-memcache.tar.gz pecl-memcache-NON_BLOCKING_IO_php7 ; \

# 安装memcache扩展
wget -c https://github.com/php-memcached-dev/php-memcached/archive/php7.tar.gz ; \
tar zxvf php7.tar.gz && cd php-memcached-php7 && /usr/local/bin/phpize && ./configure \
    --with-php-config=/usr/local/bin/php-config \
&& make -j "$(nproc)" && make install && make clean && cd / && rm -rf php7.tar.gz php-memcached-php7 ; \

# 安装tengine
wget -c https://github.com/alibaba/tengine/archive/master.tar.gz ; \
tar zxvf master.tar.gz && cd tengine-master && ./configure \
    --with-http_concat_module \
&& make -j "$(nproc)" && make install && make clean && cd / && rm -rf master.tar.gz tengine-master ; \

# 删除构建文件、测试文件、说明文档、检测文件等
rm -rf \
    /usr/share/man \
    /usr/include/mysql \
    /usr/mysql-test \
    /usr/sql-bench \
    /usr/lib/libmysqlclient.so* \
    /usr/lib/libmysqlclient_r.so* \
    /usr/lib/libmysqld.so.* \
    /usr/bin/mysql_config \
    /usr/bin/mysql_client_test ; \
find /usr/lib -name '*.a' -maxdepth 1 -print0 | xargs -0 rm; \
find /usr/lib -name '*.so' -type l -maxdepth 1 -print0 | xargs -0 rm; \
# 扫描共享目录，并移除无用的二进制文件与.so文件
scanelf --symlink --recursive --nobanner --osabi --etype "ET_DYN,ET_EXEC" \
    /usr/bin/* /usr/lib/mysql/plugin/* | while read type osabi filename; do \
    ([ "$osabi" != "STANDALONE" ] && [ "${filename}" != "/usr/bin/strip" ]) || continue; \
    XATTR=$(getfattr --match="" --dump "${filename}"); \
    strip "${filename}"; \
    if [ -n "$XATTR" ]; then \
        echo "$XATTR" | setfattr --restore=-; \
    fi; \
done; \
# 清理构建依赖及软件包缓存
apk del --purge .build-deps; \
rm -rf /tmp/*; \
rm -rf /var/cache/apk/*; \
rm -rf /data/www/*; \

# 设置软件参数
sed -i -e "s/^.*PermitRootLogin.*$/PermitRootLogin\ yes/" /etc/ssh/sshd_config ; \
sed -i -e "s/^.*ClientAliveInterval.*$/ClientAliveInterval\ 60/" /etc/ssh/sshd_config ; \
sed -i -e "s/^.*ClientAliveCountMax.*$/ClientAliveCountMax\ 3/" /etc/ssh/sshd_config

# 开始
VOLUME ["/data"]
EXPOSE 22 80 3306 9001 11211
CMD ["sh","-c"," \
    cd /data/www/ && git init && git remote add origin $(echo $git_url) && git pull origin master; \
    cp -f /data/www/configs/run.sh /run.sh && sed -i -e 's/\r//g' /run.sh && sed -i -e 's/^M//g' /run.sh && chmod +x /*.sh ; \
    . /run.sh \
"]
