# 第 1 阶段：构建 Nginx
FROM alpine:3.20 AS builder

RUN apk add --no-cache \
    build-base \
    pcre-dev \
    zlib-dev \
    openssl-dev \
    linux-headers \
    curl

ENV NGINX_VERSION=1.26.0
ENV ZLIB_VERSION=1.2.11

# 下载并编译 zlib
RUN curl -sSL https://zlib.net/zlib-${ZLIB_VERSION}.tar.gz | tar xz && \
    cd zlib-${ZLIB_VERSION} && \
    ./configure --static && \
    make -j$(nproc) && \
    make install

# 下载并编译 Nginx
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
        --with-pcre-jit \
        --with-openssl \
        --with-zlib=/zlib-${ZLIB_VERSION} \
        --enable-static  # 使能静态链接

RUN make -j$(nproc) && make install

# 第 2 阶段：生成极小镜像
FROM alpine:3.20

LABEL maintainer="you@example.com"

RUN addgroup -S nginx && adduser -S nginx -G nginx

# 将静态编译的 Nginx 复制到最终镜像
COPY --from=builder /opt/nginx /opt/nginx
# COPY nginx.conf /opt/nginx/conf/nginx.conf

EXPOSE 80 443
WORKDIR /opt/nginx
CMD ["./sbin/nginx", "-g", "daemon off;"]
