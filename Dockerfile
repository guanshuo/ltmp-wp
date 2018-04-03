FROM alpine:edge
MAINTAINER guanshuo "12610446@qq.com"
ARG git_url
RUN  \
# 创建用户与数据目录
addgroup -g 82 www-data ; \
adduser -u 82 -G www-data www-data ; \
mkdir -p /data/www && chown -R www-data:www-data /data/www/ ; \
# 国内使用阿里云的软件源
echo "http://mirrors.aliyun.com/alpine/edge/main/" > /etc/apk/repositories ; \
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
    zlib-dev ; \
apk add --no-cache --virtual .run-deps \
    # public
    git \
    memcached \
    openssl openssh \
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
    tzdata ; \
# 判断下有没有指定giturl
if [ ! -n "$git_url" ]; then \
    # 没有的话用git协议下载
    git clone --recurse-submodules --depth=1 https://github.com/MariaDB/server.git ; \
    git clone --recurse-submodules --depth=1 https://github.com/php/php-src.git ; \
    git clone --recurse-submodules --depth=1 https://github.com/alibaba/tengine.git ; \
else \
    # 有的话先设置ssh信息再用ssh协议下载
    sed -i -e "s/^.*StrictHostKeyChecking.*$/StrictHostKeyChecking\ no/" /etc/ssh/ssh_config; \
    sed -i -e "s/^.*UserKnownHostsFile.*$/UserKnownHostsFile\ \/dev\/null/" /etc/ssh/ssh_config; \
    (echo;read;echo)|ssh-keygen -t rsa ; \
    git clone --depth=1 $(echo $git_url) /data/www ; \
    cp -f /data/www/configs/id_rsa /root/.ssh && cp -f /data/www/configs/id_rsa.pub /root/.ssh ; \
    echo yes|ssh -T git@github.com ; \
    git clone --recurse-submodules --depth=1 git@github.com:MariaDB/server.git ; \
    git clone --recurse-submodules --depth=1 git@github.com:php/php-src.git ; \
    git clone --recurse-submodules --depth=1 git@github.com:alibaba/tengine.git ; \
fi; \
# 安装mariadb
cd server && cmake . \
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
make -j "$(nproc)" && make install && make clean && rm -rf /server && cd / ; \

# 安装php
export CFLAGS="-fstack-protector-strong -fpic -fpie -O2" \
       CPPFLAGS="-fstack-protector-strong -fpic -fpie -O2" \
       LDFLAGS="-Wl,-O1 -Wl,--hash-style=both -pie" ; \
cd php-src && ./buildconf && gnuArch="$(dpkg-architecture --query DEB_BUILD_GNU_TYPE)" && ./configure \
    --build="$gnuArch" \
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
    --disable-cgi \
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
&& make -j "$(nproc)" && make install \
&& { find /usr/local/bin /usr/local/sbin -type f -perm +0111 -exec strip --strip-all '{}' + || true; } \
&& make clean && rm -rf /php-src && cd / \
&& runDeps="$( \
	scanelf --needed --nobanner --format '%n#p' --recursive /usr/local \
		| tr ',' '\n' \
		| sort -u \
		| awk 'system("[ -e /usr/local/lib/" $1 " ]") == 0 { next } { print "so:" $1 }' \
)" \
&& apk add --no-cache --virtual .run-deps $runDeps \
&& pecl update-channels ; \ 

# 安装tengine
cd tengine && ./configure \
    --with-http_concat_module \
&& make -j "$(nproc)" && make install && make clean && rm -rf /tengine && cd / ; \

# 安装听云
wget http://download.networkbench.com/agent/php/2.7.0/tingyun-agent-php-2.7.0.x86_64.deb?a=1498149881851 -O tingyun-agent-php.deb ; \
wget http://download.networkbench.com/agent/system/1.1.1/tingyun-agent-system-1.1.1.x86_64.deb?a=1498149959157 -O tingyun-agent-system.deb ; \
dpkg -i tingyun-agent-php.deb && dpkg -i tingyun-agent-system.deb && rm -rf /tingyun-*.deb ; \

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
    /usr/bin/mysql_client_test; \
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
EXPOSE 22 80 3306 8388 9001 11211
CMD ["sh","-c","cd /data/www/ && git init && git remote add origin $(echo $git_url) && git pull origin master; \
cp -f /data/www/configs/run.sh /run.sh && sed -i -e 's/\r//g' /run.sh && sed -i -e 's/^M//g' /run.sh && chmod +x /*.sh && . /run.sh "]
