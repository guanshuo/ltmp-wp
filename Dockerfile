FROM alpine:edge
MAINTAINER guanshuo "12610446@qq.com"
ENV PHP_INI_DIR /usr/local/etc/php
RUN mkdir -p $PHP_INI_DIR/conf.d
ADD https://raw.githubusercontent.com/docker-library/php/master/7.2/alpine3.7/fpm/docker-php-ext-configure /usr/local/bin/
ADD https://raw.githubusercontent.com/docker-library/php/master/7.2/alpine3.7/fpm/docker-php-ext-enable    /usr/local/bin/
ADD https://raw.githubusercontent.com/docker-library/php/master/7.2/alpine3.7/fpm/docker-php-ext-install   /usr/local/bin/
RUN  \

# 创建用户与数据目录并赋予权限
addgroup -g 82 www-data ; \
adduser -u 82 -G www-data www-data ; \
mkdir -p /data/www && chown -R www-data:www-data /data/www/ ; \
# 国内使用阿里云的软件源
echo "http://mirrors.aliyun.com/alpine/edge/main/" > /etc/apk/repositories ; \
# apt包安装
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
    libc-dev \
    libedit-dev \
    libsodium-dev \
    libxml2-dev \
    pkgconf \
    re2c \
    sqlite-dev \
    # nginx
    geoip-dev\
    libtool \
    pcre-dev ; \
apk add --no-cache --virtual .run-deps \
    # public
    git \
    memcached \
    openssl openssh \
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
    libressl \
    xz \
    # nginx
    findutils \
    geoip \
    nghttp2 \
    pcre ; \
# 升级grep软件包不然无法使用Perl的正则表达式
apk add --upgrade --no-cache grep ; \

if false; then \
# 安装mariadb,先去官网获取最新稳定版版本号，再进行下载
Mariadb_Version=$(curl -s https://downloads.mariadb.org | grep -m 1 -oP '(?<=Download).*(?=Stable)' | sed 's/ //g') ; \
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
    -DENABLED_LOCAL_INFILE=ON \
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
     # 库文件加载选项
    -DWITH_READLINE=ON \
    -DWITH_ZLIB=system \
    -DWITH_SSL=system \
    -DWITH_LIBWRAP=OFF \
     # JEMALLOC优化内存
    -DWITH_JEMALLOC=no \
    -DWITH_EXTRA_CHARSETS=complex \
    -DWITH_EMBEDDED_SERVER=ON \
    -DWITH_ARCHIVE_STORAGE_ENGINE=1 \
    -DWITH_BLACKHOLE_STORAGE_ENGINE=1 \
    -DWITH_INNOBASE_STORAGE_ENGINE=1 \
    -DWITH_PARTITION_STORAGE_ENGINE=1 \
     # 不安装tokudb引擎
    -DPLUGIN_TOKUDB=NO \
    -DWITHOUT_TOKUDB=1 \
     # 不编译某存储引擎
    -DWITHOUT_INNOBASE_STORAGE_ENGINE=1 \
    -DWITHOUT_ARCHIVE_STORAGE_ENGINE=1 \
    -DWITHOUT_BLACKHOLE_STORAGE_ENGINE=1 \
    -DWITHOUT_EXAMPLE_STORAGE_ENGINE=1 \
    -DWITHOUT_FEDERATED_STORAGE_ENGINE=1 \
    -DWITHOUT_PBXT_STORAGE_ENGINE=1; \
make -j "$(nproc)" && make install && make clean && cd / && rm -rf master.tar.gz mariadb-${Mariadb_Version} ; \
fi ; \

# 安装php
wget -c https://secure.php.net/get/php-7.2.4.tar.xz/from/this/mirror -O master.tar.gz ; \
export CFLAGS="-fstack-protector-strong -fpic -fpie -O2" \
       CPPFLAGS="-fstack-protector-strong -fpic -fpie -O2" \
       LDFLAGS="-Wl,-O1 -Wl,--hash-style=both -pie" ; \
tar zxvf master.tar.gz && cd php-src-master && ./buildconf && gnuArch="$(dpkg-architecture --query DEB_BUILD_GNU_TYPE)" && ./configure \
    --build="$gnuArch" \
    --with-config-file-path="$PHP_INI_DIR" \
    --with-config-file-scan-dir="$PHP_INI_DIR/conf.d" \
    --disable-cgi \
    --enable-ftp \
    --enable-mbstring \
    --enable-mysqlnd \
    --with-sodium=shared \
    --with-curl \
    --with-libedit \
    --with-openssl \
    --with-zlib \
    $(test "$gnuArch" = 's390x-linux-gnu' && echo '--without-pcre-jit') \
    --enable-fpm \
    --with-fpm-user=www-data \
    --with-fpm-group=www-data \
&& make -j "$(nproc)" && make install ; \
{ find /usr/local/bin /usr/local/sbin -type f -perm +0111 -exec strip --strip-all '{}' + || true; } ; \
make clean && cd / && { find /usr/local/bin /usr/local/sbin -type f -perm +0111 -exec strip --strip-all '{}' + || true; } ; \
rm -rf master.tar.gz php-src-master ; \
runDeps="$( \
	scanelf --needed --nobanner --format '%n#p' --recursive /usr/local \
		| tr ',' '\n' \
		| sort -u \
		| awk 'system("[ -e /usr/local/lib/" $1 " ]") == 0 { next } { print "so:" $1 }' \
)" \
&& apk add --no-cache --virtual .run-deps $runDeps \
&& pecl update-channels ; \ 

if false; then \
# 安装tengine
wget -c https://github.com/alibaba/tengine/archive/master.tar.gz ; \
tar zxvf master.tar.gz && cd tengine-master && ./configure \
    --with-http_concat_module \
&& make -j "$(nproc)" && make install && make clean && cd / && rm -rf master.tar.gz tengine-master ; \
fi ; \

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
sed -i -e "s/^.*PermitRootLogin.*$/PermitRootLogin\ yes/" /etc/ssh/sshd_config

# 开始
VOLUME ["/data"]
EXPOSE 22 80 3306 9001 11211
CMD ["sh","-c"," \
    cd /data/www/ && git init && git remote add origin $(echo $git_url) && git pull origin master; \
    cp -f /data/www/configs/run.sh /run.sh && sed -i -e 's/\r//g' /run.sh && sed -i -e 's/^M//g' /run.sh && chmod +x /*.sh ; \
    . /run.sh \
"]
