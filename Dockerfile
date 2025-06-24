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

RUN curl -sSL https://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz | tar xz && \
    curl -sSL https://www.openssl.org/source/openssl-${OPENSSL_VERSION}.tar.gz | tar xz \
    curl -sSL https://zlib.net/zlib-${ZLIB_VERSION}.tar.gz | tar xz

WORKDIR /build/nginx-${NGINX_VERSION}

RUN ./configure \
    --prefix=/opt/nginx \
    --with-cc-opt="-static -static-libgcc" \
    --with-ld-opt="-static" \
    --with-openssl=../openssl-${OPENSSL_VERSION} \
    --with-zlib=../zlib-${ZLIB_VERSION} \
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
