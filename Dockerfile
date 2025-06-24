FROM alpine:3.20 AS builder

# 安装构建依赖
RUN apk add --no-cache \
    build-base \
    openssl-dev \
    pcre-dev \
    zlib-dev \
    curl

# 获取最新版本号
ARG NGINX_VERSION=1.27.5

# 下载并静态编译 Nginx
RUN curl -sSL https://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz -o nginx.tar.gz && \
    tar xzf nginx.tar.gz && \
    cd nginx-${NGINX_VERSION} && \
    ./configure \
        --prefix=/opt/nginx \
        --with-cc-opt="-static -static-libgcc" \
        --with-ld-opt="-static" \
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
    make install

# ===== FINAL STAGE =====
FROM scratch

# 复制静态编译后的 nginx 文件
COPY --from=builder /opt/nginx /opt/nginx

# 暴露端口
EXPOSE 80 443

# 设置工作目录
WORKDIR /opt/nginx

# 启动 nginx（必须静态编译才能在 scratch 运行）
CMD ["./sbin/nginx", "-g", "daemon off;"]
