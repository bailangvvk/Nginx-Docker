FROM alpine:3.20 as builder

ARG NGINX_VERSION=1.27.5
ARG OPENSSL_VERSION=3.3.0
ARG ZLIB_VERSION=1.3

# 安装构建依赖
RUN apk add --no-cache \
    build-base \
    curl \
    pcre-dev \
    zlib-dev \
    linux-headers

# 下载源码
WORKDIR /build

RUN curl -sSL https://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz -o nginx.tar.gz && \
    curl -sSL https://www.openssl.org/source/openssl-${OPENSSL_VERSION}.tar.gz -o openssl.tar.gz && \
    curl -sSL https://zlib.net/zlib-${ZLIB_VERSION}.tar.gz -o zlib.tar.gz && \
    tar xzf nginx.tar.gz && \
    tar xzf openssl.tar.gz && \
    tar xzf zlib.tar.gz


WORKDIR /build/nginx-${NGINX_VERSION}

RUN ./configure \
    --prefix=/opt/nginx \
    --with-cc-opt="-static -static-libgcc" \
    --with-ld-opt="-static" \
    --with-openssl=../openssl-3.3.0
    --with-zlib=../zlib-1.3
    --with-http_ssl_module \
    --with-http_v2_module \
    --with-http_gzip_static_module \
    --with-http_stub_status_module \
    --with-threads \
    --with-pcre \
    --with-pcre-jit \
    --without-http_rewrite_module \
    --without-http_auth_basic_module && \
    make -j$(nproc) && \
    make install && \
    strip /opt/nginx/sbin/nginx

# =====================
FROM scratch

COPY --from=builder /opt/nginx /opt/nginx

EXPOSE 80 443
WORKDIR /opt/nginx
CMD ["./sbin/nginx", "-g", "daemon off;"]
