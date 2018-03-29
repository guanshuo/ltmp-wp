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
    zlib-dev && \

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
    tzdata ; \



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
# 设置软件参数
sed -i -e "s/^.*PermitRootLogin.*$/PermitRootLogin\ yes/" /etc/ssh/sshd_config; \
# 创建目录并设置权限
mkdir -p /data/www
# 开始
VOLUME ["/data"]
EXPOSE 22 80 3306 8388 9001 11211
CMD ["sh","-c","cd /data/www/ && git init && git remote add origin $(echo $git_url) && git pull origin master; \
cp -f /data/www/configs/run.sh /run.sh && sed -i -e 's/\r//g' /run.sh && sed -i -e 's/^M//g' /run.sh && chmod +x /*.sh && . /run.sh "]
