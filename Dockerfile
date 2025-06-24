FROM alpine:3.20 AS builder

RUN apk add --no-cache \
    build-base \
    pcre-dev \
    zlib-dev \
    openssl-dev \
    linux-headers \
    curl

ENV NGINX_VERSION=1.26.0

RUN curl -sSL http://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz | tar xz && \
    cd nginx-${NGINX_VERSION} && \
    ./configure \
        --prefix=/opt/nginx \
        --with-http_ssl_module \
        --with-http_v2_module \
        --with-http_gzip_static_module \
        --with-threads \
        --with-file-aio \
        --without-http_rewrite_module \
        --without-http_auth_basic_module \
        --with-pcre \
        --with-pcre-jit && \
    make -j$(nproc) && \
    make install


FROM alpine:3.20

RUN addgroup -S nginx && adduser -S nginx -G nginx

COPY --from=builder /opt/nginx /opt/nginx
# COPY nginx.conf /opt/nginx/conf/nginx.conf

EXPOSE 80 443
WORKDIR /opt/nginx
CMD ["./sbin/nginx", "-g", "daemon off;"]
