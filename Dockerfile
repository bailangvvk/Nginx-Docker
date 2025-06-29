FROM alpine:3.20 AS builder

# WORKDIR /build

# 安装构建依赖
RUN \
    build_pkgs="build-base linux-headers openssl-dev pcre-dev wget zlib-dev" && \
    runtime_pkgs="ca-certificates openssl pcre zlib tzdata git" && \
    apk --no-cache add ${build_pkgs} ${runtime_pkgs} \
    && \
    cd /tmp \
    && \
    NGINX_VERSION=$(wget -q -O - https://nginx.org/en/download.html | grep -oE 'nginx-[0-9]+\.[0-9]+\.[0-9]+' | head -n1 | cut -d'-' -f2) \
    && \
    OPENSSL_VERSION=$(wget -q -O - https://www.openssl.org/source/ | grep -oE 'openssl-[0-9]+\.[0-9]+\.[0-9]+' | head -n1 | cut -d'-' -f2) \
    && \
    ZLIB_VERSION=$(wget -q -O - https://zlib.net/ | grep -oE 'zlib-[0-9]+\.[0-9]+\.[0-9]+' | head -n1 | cut -d'-' -f2) \
    && \
    ZSTD_VERSION=$(curl -Ls https://github.com/facebook/zstd/releases/latest | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' | head -n1 | cut -c2-) \
    && \
    CORERULESET_VERSION=$(curl -s https://api.github.com/repos/coreruleset/coreruleset/releases/latest | grep -oE '"tag_name": "[^"]+' | cut -d'"' -f4 | sed 's/v//') \
    && \
    PCRE_VERSION=$(curl -sL https://sourceforge.net/projects/pcre/files/pcre/ | grep -oE 'pcre-[0-9]+\.[0-9]+' | cut -d'-' -f2 | sort -Vr | head -n1) \
    && \
    \
    echo "=============版本号=============" && \
    echo "NGINX_VERSION=${NGINX_VERSION}" && \
    echo "OPENSSL_VERSION=${OPENSSL_VERSION}" && \
    echo "ZLIB_VERSION=${ZLIB_VERSION}" && \
    echo "ZSTD_VERSION=${ZSTD_VERSION}" && \
    echo "CORERULESET_VERSION=${CORERULESET_VERSION}" && \
    echo "PCRE_VERSION=${PCRE_VERSION}" && \
    \
    # # fallback 以防 curl/grep 失败
    # NGINX_VERSION="${NGINX_VERSION:-1.29.0}" && \
    # OPENSSL_VERSION="${OPENSSL_VERSION:-3.3.0}" && \
    # ZLIB_VERSION="${ZLIB_VERSION:-1.3.1}" && \
    # ZSTD_VERSION="${ZSTD_VERSION:-1.5.7}" && \
    # CORERULESET_VERSION="${CORERULESET_VERSION}" && \
    # \
    # echo "==> Using versions: nginx-${NGINX_VERSION}, openssl-${OPENSSL_VERSION}, zlib-${ZLIB_VERSION}" && \
    # \
    curl -fSL https://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz -o nginx.tar.gz && \
    tar xzf nginx.tar.gz && \
    \
    curl -fSL https://www.openssl.org/source/openssl-${OPENSSL_VERSION}.tar.gz -o openssl.tar.gz && \
    tar xzf openssl.tar.gz && \
    \
    curl -fSL https://fossies.org/linux/misc/zlib-${ZLIB_VERSION}.tar.gz -o zlib.tar.gz && \
    tar xzf zlib.tar.gz && \
    \
    curl -fSL https://downloads.sourceforge.net/project/pcre/pcre/${PCRE_VERSION}/pcre-${PCRE_VERSION}.tar.gz -o pcre.tar.gz && \
    tar xzf pcre.tar.gz && \
    \
    cd nginx-${NGINX_VERSION} && \
    ./configure \
        # --prefix=/etc/nginx \
        # --user=root \
        # --group=root \
        # --with-compat \
        # # --with-cc-opt="-static -static-libgcc" \
        # # --with-ld-opt="-static" \
        # --with-openssl=../openssl-${OPENSSL_VERSION} \
        # --with-zlib=../zlib-${ZLIB_VERSION} \
        # --with-pcre \
        # # --with-pcre=../pcre-${PCRE_VERSION} \
        # --with-pcre-jit \
        # --with-http_ssl_module \
        # --with-http_v2_module \
        # --with-http_gzip_static_module \
        # --with-http_stub_status_module \
        # --without-http_rewrite_module \
        # --without-http_auth_basic_module \
        # --with-threads && \
        --prefix=/etc/nginx \
        --sbin-path=/usr/sbin/nginx \
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
        --user=root \
        --group=root \
        --with-compat \
        --with-openssl=../openssl-${OPENSSL_VERSION} \
        --with-zlib=../zlib-${ZLIB_VERSION} \
        --with-http_ssl_module \
        --with-http_realip_module \
        --with-http_addition_module \
        --with-http_sub_module \
        --with-http_dav_module \
        --with-http_flv_module \
        --with-http_mp4_module \
        --with-http_gunzip_module \
        --with-http_gzip_static_module \
        --with-http_random_index_module \
        --with-http_secure_link_module \
        --with-http_stub_status_module \
        --with-http_auth_request_module \
        --with-mail \
        --with-mail_ssl_module \
        --with-file-aio \
        --with-threads \
        --with-stream \
        --with-stream_ssl_module \
        --with-stream_realip_module \
        --with-http_slice_module \
        --with-http_v2_module && \
    make -j$(nproc) && \
    make install && \
    rm -rf /tmp/* && \
    apk del ${build_pkgs} && \
    rm -rf /var/cache/apk/* && \
    # strip /etc/nginx/sbin/nginx
    strip /usr/sbin/nginx


# 最小运行时镜像
# FROM busybox:1.35-uclibc
# FROM alpine:3.20
FROM alpine:latest
# FROM gcr.io/distroless/static

RUN apk add --no-cache pcre

# 拷贝构建产物
# COPY --from=builder /etc/nginx /etc/nginx

# 拷贝编译后的 Nginx 可执行文件
COPY /usr/sbin/nginx /usr/sbin/nginx
# 拷贝 Nginx 配置文件
COPY /etc/nginx/nginx.conf /etc/nginx/nginx.conf
# 拷贝日志目录
COPY /var/log/nginx/access.log /var/log/nginx/access.log
COPY /var/log/nginx/error.log /var/log/nginx/error.log
# 拷贝缓存目录
COPY /var/cache/nginx/client_temp /var/cache/nginx/client_temp
COPY /var/cache/nginx/proxy_temp /var/cache/nginx/proxy_temp
COPY /var/cache/nginx/fastcgi_temp /var/cache/nginx/fastcgi_temp
COPY /var/cache/nginx/uwsgi_temp /var/cache/nginx/uwsgi_temp
COPY /var/cache/nginx/scgi_temp /var/cache/nginx/scgi_temp

# 拷贝运行时目录（PID 和锁文件等）
COPY /var/run/nginx.pid /var/run/nginx.pid
COPY /var/run/nginx.lock /var/run/nginx.lock

# 暴露端口
EXPOSE 80 443

WORKDIR /etc/nginx

# 启动 nginx
CMD ["./sbin/nginx", "-g", "daemon off;"]
