# syntax=docker/dockerfile:1

FROM alpine:3.20 AS builder

ARG NGINX_VERSION=1.27.5
ARG OPENSSL_VERSION=3.3.0
ARG ZLIB_VERSION=1.3

WORKDIR /build

# 安装构建依赖
RUN apk add --no-cache \
    build-base \
    curl \
    pcre-dev \
    zlib-dev \
    linux-headers

# 下载源码
RUN curl -sSL https://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz -o nginx.tar.gz && \
    tar xzf nginx.tar.gz && \
    curl -sSL https://www.openssl.org/source/openssl-${OPENSSL_VERSION}.tar.gz -o openssl.tar.gz && \
    tar xzf openssl.tar.gz && \
    # 若 zlib.net 不稳定，也可以替换成：
    # ENV ZLIB_URL=https://fossies.org/linux/misc/zlib-${ZLIB_VERSION}.tar.gz
    curl -sSL https://fossies.org/linux/misc/zlib-${ZLIB_VERSION}.tar.gz && \
    tar xzf zlib.tar.gz

WORKDIR /build/nginx-${NGINX_VERSION}

# 静态编译 Nginx，链接 openssl/zlib
RUN ./configure \
    --prefix=/opt/nginx \
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
    strip /opt/nginx/sbin/nginx

# Final scratch image
FROM scratch

COPY --from=builder /opt/nginx /opt/nginx

EXPOSE 80 443
WORKDIR /opt/nginx
CMD ["./sbin/nginx", "-g", "daemon off;"]
