FROM alpine:3.20 AS builder

WORKDIR /build

RUN apk add --no-cache \
    build-base \
    curl \
    pcre-dev \
    zlib-dev \
    linux-headers \
    perl \
    sed

# 获取最新版本号
RUN export NGINX_VERSION=$(curl -s https://nginx.org/en/download.html | grep -Eo 'nginx-[0-9]+\.[0-9]+\.[0-9]+\.tar\.gz' | head -n1 | sed 's/nginx-\(.*\)\.tar\.gz/\1/') && \
    export OPENSSL_VERSION=$(curl -s https://www.openssl.org/source/ | grep -Eo 'openssl-[0-9]+\.[0-9]+\.[0-9]+[a-z]*\.tar\.gz' | grep -v fips | head -n1 | sed 's/openssl-\(.*\)\.tar\.gz/\1/') && \
    export ZLIB_VERSION=$(curl -s https://zlib.net/ | grep -Eo 'zlib-[0-9]+\.[0-9]+\.[0-9]+\.tar\.gz' | head -n1 | sed 's/zlib-\(.*\)\.tar\.gz/\1/') && \
    echo "==> NGINX_VERSION=${NGINX_VERSION}, OPENSSL_VERSION=${OPENSSL_VERSION}, ZLIB_VERSION=${ZLIB_VERSION}" && \
    curl -fSL https://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz -o nginx.tar.gz && \
    tar xzf nginx.tar.gz && \
    curl -fSL https://www.openssl.org/source/openssl-${OPENSSL_VERSION}.tar.gz -o openssl.tar.gz && \
    tar xzf openssl.tar.gz && \
    curl -fSL https://fossies.org/linux/misc/zlib-${ZLIB_VERSION}.tar.gz -o zlib.tar.gz && \
    tar xzf zlib.tar.gz && \
    cd nginx-${NGINX_VERSION} && \
    ./configure \
        --user=root \
        --group=root \
        --with-cc-opt="-static -static-libgcc" \
        --with-ld-opt="-static" \
        --with-openssl=../openssl-${OPENSSL_VERSION} \
        --with-zlib=../zlib-${ZLIB_VERSION} \
        --with-pcre \
        --with-pcre-jit \
        --with-http_ssl_module \
        --with-http_v2_module \
        --with-http_gzip_static_module \
        --with-http_stub_status_module \
        --without-http_rewrite_module \
        --without-http_auth_basic_module \
        --with-threads && \
    make -j$(nproc) && \
    make install && \
    strip /usr/local/nginx/sbin/nginx


# FROM gcr.io/distroless/static
FROM busybox:1.35-uclibc

# 从构建镜像复制整个 nginx 到 /usr/local/nginx
COPY --from=builder /usr/local/nginx /usr/local/nginx
# COPY --from=builder /usr/local/nginx/conf /etc/nginx

# 曝露 80 和 443 端口
EXPOSE 80 443

# 设置工作目录
WORKDIR /usr/local/nginx

# 启动 Nginx
CMD ["./sbin/nginx", "-g", "daemon off;"]
