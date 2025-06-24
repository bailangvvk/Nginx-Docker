# syntax=docker/dockerfile:1

FROM alpine:3.20 AS builder

ARG NGINX_VERSION=1.27.5
ARG OPENSSL_VERSION=3.3.0
ARG ZLIB_VERSION=1.3.1

WORKDIR /build

# 安装构建依赖
RUN apk add --no-cache \
    build-base \
    curl \
    pcre-dev \
    zlib-dev \
    linux-headers \
    perl \
    sed

# 下载源码
RUN curl -fSL https://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz -o nginx.tar.gz && \
    tar xzf nginx.tar.gz && \
    curl -fSL https://www.openssl.org/source/openssl-${OPENSSL_VERSION}.tar.gz -o openssl.tar.gz && \
    tar xzf openssl.tar.gz && \
    curl -fSL https://fossies.org/linux/misc/zlib-${ZLIB_VERSION}.tar.gz -o zlib.tar.gz && \
    tar xzf zlib.tar.gz

WORKDIR /build/nginx-${NGINX_VERSION}

# 我先投个毒 注释掉 user nobody;
# RUN sed -i 's/^user nobody;/#user nobody;/' conf/nginx.conf
# RUN sed -i 's/^user nobody;/#user nobody;/' conf/nginx.conf && ls -l conf/nginx.conf && cat conf/nginx.conf


# 静态编译 Nginx，链接 openssl/zlib
RUN ./configure \
    --user=root \
    --group=root \
    # --prefix=/opt/nginx \
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

# RUN cat /opt/nginx/conf/nginx.conf

# # Final scratch image
# FROM scratch

# COPY --from=builder /opt/nginx /opt/nginx

# EXPOSE 80 443
# WORKDIR /opt/nginx
# CMD ["./sbin/nginx", "-g", "daemon off;"]
# # CMD ["./sbin/nginx", "-c", "/opt/nginx/conf/nginx.conf", "-g", "daemon off;"]

FROM gcr.io/distroless/static

# 从构建镜像复制整个 nginx 到 /usr/local/nginx
COPY --from=builder /usr/local/nginx /usr/local/nginx

# 曝露 80 和 443 端口
EXPOSE 80 443

# 设置工作目录
WORKDIR /usr/local/nginx

# 启动 Nginx
CMD ["./sbin/nginx", "-g", "daemon off;"]
