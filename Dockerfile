#
# 最终版 v4: 采用 FHS 标准目录结构，并融合安全、模块化和 Docker 日志最佳实践
#
FROM alpine:latest AS builder

# 使用 /tmp 作为工作目录
WORKDIR /tmp

# 安装构建依赖
RUN set -eux && \
    # 添加模块所需的额外构建依赖
    apk add --no-cache --virtual .build-deps \
        build-base \
        curl \
        linux-headers \
        perl \
        sed \
        grep \
        tar \
        bash \
        jq \
        gd-dev \
        geoip-dev \
        libxslt-dev && \
    # 动态获取最新版本号
    NGINX_VERSION=$(wget -q -O - https://nginx.org/en/download.html | grep -oE 'nginx-[0-9]+\.[0-9]+\.[0-9]+' | head -n1 | cut -d'-' -f2) && \
    OPENSSL_VERSION=$(wget -q -O - https://www.openssl.org/source/ | grep -oE 'openssl-[0-9]+\.[0-9]+\.[0-9]+' | head -n1 | cut -d'-' -f2) && \
    ZLIB_VERSION=$(wget -q -O - https://zlib.net/ | grep -oE 'zlib-[0-9]+\.[0-9]+\.[0-9]+' | head -n1 | cut -d'-' -f2) && \
    PCRE2_VERSION=$(curl -sL https://github.com/PCRE2Project/pcre2/releases/ | grep -ioE 'pcre2-[0-9]+\.[0-9]+' | grep -v RC | cut -d'-' -f2 | sort -Vr | head -n1) && \
    NJS_VERSION=$(curl -s https://api.github.com/repos/nginx/njs/releases/latest | grep -oE '"tag_name": "[^"]+' | cut -d'"' -f4) && \
    \
    # 使用 nobody 用户进行不安全的下载和解压操作
    su nobody -s /bin/sh -c " \
        curl -fSL https://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz -o nginx.tar.gz && \
        curl -fSL https://www.openssl.org/source/openssl-${OPENSSL_VERSION}.tar.gz -o openssl.tar.gz && \
        curl -fSL https://fossies.org/linux/misc/zlib-${ZLIB_VERSION}.tar.gz -o zlib.tar.gz && \
        curl -fSL https://github.com/PCRE2Project/pcre2/releases/download/pcre2-${PCRE2_VERSION}/pcre2-${PCRE2_VERSION}.tar.gz -o pcre2.tar.gz && \
        curl -fSL https://github.com/nginx/njs/archive/refs/tags/${NJS_VERSION}.tar.gz -o njs.tar.gz && \
        tar xzf nginx.tar.gz && tar xzf openssl.tar.gz && tar xzf zlib.tar.gz && tar xzf pcre2.tar.gz && tar xzf njs.tar.gz \
    " && \
    # 配置和编译回到 root 用户
    cd "nginx-${NGINX_VERSION}" && \
    #
    # <- 核心修改点 1: 使用您指定的 FHS 路径来配置 Nginx ->
    #
    ./configure \
        --prefix=/etc/nginx \
        --sbin-path=/usr/sbin/nginx \
        --modules-path=/etc/nginx/modules \
        --conf-path=/etc/nginx/nginx.conf \
        --error-log-path=/var/log/nginx/error.log \
        --http-log-path=/var/log/nginx/access.log \
        --pid-path=/var/run/nginx.pid \
        --lock-path=/var/run/nginx.lock \
        --http-client-body-temp-path=/var/cache/nginx/client_temp \
        --http-proxy-temp-path=/var/cache/nginx/proxy_temp \
        --http-fastcgi-temp-path=/var/cache/nginx/fastcgi_temp \
        --http-uwsgi-temp-path=/var/cache/nginx/uwsgi_temp \
        --http-scgi-temp-path=/var/cache/nginx/scgi_temp \
        --with-compat \
        --with-openssl="../openssl-${OPENSSL_VERSION}" \
        --with-zlib="../zlib-${ZLIB_VERSION}" \
        --with-pcre="../pcre2-${PCRE2_VERSION}" \
        --with-pcre-jit \
        --with-threads \
        --with-http_ssl_module \
        --with-http_v2_module \
        --with-http_gzip_static_module \
        --with-http_stub_status_module \
        --with-http_xslt_module=dynamic \
        --with-http_image_filter_module=dynamic \
        --with-http_geoip_module=dynamic \
        --add-dynamic-module="../njs-${NJS_VERSION}/nginx" \
    && \
    make -j$(nproc) && \
    make install && \
    strip /usr/sbin/nginx

# 最小运行时镜像
FROM alpine:latest

# 为运行时安全创建非 root 用户
RUN addgroup -S nginx && adduser -S -G nginx nginx

#
# <- 核心修改点 2: 从构建器中拷贝分散的文件到最终镜像的对应位置 ->
#
COPY --from=builder /usr/sbin/nginx /usr/sbin/nginx
COPY --from=builder /etc/nginx /etc/nginx

#
# <- 核心修改点 3: 创建您指定的目录结构和 Nginx 运行时需要的缓存目录 ->
#
RUN mkdir -p /var/www/html && \
    mkdir -p /etc/nginx/certs && \
    mkdir -p /var/cache/nginx && \
    # 确保日志目录存在
    mkdir -p /var/log/nginx

#
# <- 核心修改点 4: 针对新的配置文件路径和结构进行修改 ->
#
RUN # 1. 修改默认的 web root 指向 /var/www/html
    sed -i 's|root   html;|root   /var/www/html;|' /etc/nginx/nginx.conf && \
    # 2. 注入 Docker 日志、epoll 和哈希桶配置
    sed -i \
        -e '/events {/a \    use epoll;' \
        -e '/http {/a \    server_names_hash_bucket_size 64;' \
        -e 's|access_log  /var/log/nginx/access.log;|access_log /dev/stdout;|' \
        -e 's|error_log   /var/log/nginx/error.log;|error_log /dev/stderr;|' \
        /etc/nginx/nginx.conf && \
    # 3. 在顶部加载动态模块
    sed -i \
        -e '1i load_module modules/ngx_http_js_module.so;' \
        -e '1i load_module modules/ngx_http_geoip_module.so;' \
        -e '1i load_module modules/ngx_http_image_filter_module.so;' \
        -e '1i load_module modules/ngx_http_xslt_filter_module.so;' \
        /etc/nginx/nginx.conf

#
# <- 核心修改点 5: 为所有 nginx 需要写入的目录设置权限 ->
#
RUN chown -R nginx:nginx /etc/nginx /var/log/nginx /var/cache/nginx /var/www/html /var/run

# 暴露端口
EXPOSE 80 443

# 切换到非 root 用户启动
USER nginx

#
# <- 核心修改点 6: 使用新的二进制文件路径启动 ->
#
CMD ["/usr/sbin/nginx", "-g", "daemon off;"]
