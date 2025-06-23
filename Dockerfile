# ---- 构建阶段 ----
FROM alpine:3.21 AS builder

ARG NGINX_VERSION=1.27.5
ARG PKG_RELEASE=1
ARG DYNPKG_RELEASE=1
ARG NJS_VERSION=0.8.10
ARG NJS_RELEASE=1

# 安装构建依赖
RUN apk add --no-cache --virtual .build-deps \
    build-base \
    pcre2-dev \
    zlib-dev \
    openssl-dev \
    libxslt-dev \
    gd-dev \
    geoip-dev \
    libedit-dev \
    linux-headers \
    bash \
    curl \
    gnupg \
    findutils

# 新建 nginx 用户和组，避免 root 运行
RUN addgroup -g 101 -S nginx && \
    adduser -u 101 -S -G nginx -h /var/cache/nginx -s /sbin/nologin nginx

WORKDIR /tmp

# 下载并校验 nginx 源码包
RUN curl -fSL -o nginx.tar.gz https://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz && \
    curl -fSL -o nginx.tar.gz.asc https://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz.asc && \
    # 导入 nginx 官方公钥验证（这里示意，实际公钥需更新）
    gpg --keyserver hkps://keyserver.ubuntu.com --recv-keys ABF5BD827BD9BF62 && \
    gpg --verify nginx.tar.gz.asc nginx.tar.gz

# 解压源码
RUN tar zxvf nginx.tar.gz

WORKDIR /tmp/nginx-${NGINX_VERSION}

# 编译 Nginx，启用常用模块和动态模块支持
RUN ./configure \
    --prefix=/etc/nginx \
    --sbin-path=/usr/sbin/nginx \
    --modules-path=/etc/nginx/modules \
    --conf-path=/etc/nginx/nginx.conf \
    --error-log-path=/var/log/nginx/error.log \
    --http-log-path=/var/log/nginx/access.log \
    --pid-path=/var/run/nginx.pid \
    --lock-path=/var/run/nginx.lock \
    --with-http_ssl_module \
    --with-http_v2_module \
    --with-http_realip_module \
    --with-http_stub_status_module \
    --with-http_gzip_static_module \
    --with-http_auth_request_module \
    --with-threads \
    --with-stream \
    --with-stream_ssl_module \
    --with-http_slice_module \
    --with-file-aio \
    --with-http_secure_link_module \
    --with-http_sub_module \
    --with-stream_realip_module \
    --with-http_addition_module \
    --with-http_xslt_module=dynamic \
    --with-http_image_filter_module=dynamic \
    --with-http_geoip_module=dynamic \
    --with-http_perl_module=dynamic \
    --with-http_fancyindex_module=dynamic \
    --with-http_njs_module=dynamic

RUN make && make install

# ---- 运行阶段 ----
FROM alpine:3.21

LABEL maintainer="YourName <youremail@example.com>"

ENV NGINX_VERSION=${NGINX_VERSION}

ENV TAG=${TAG}

# 安装运行时依赖
RUN apk add --no-cache \
    ca-certificates \
    tzdata \
    gettext \
    libxslt \
    gd \
    geoip \
    libedit \
    openssl \
    pcre2 \
    zlib

# 创建 nginx 用户和组，确保权限安全
RUN addgroup -g 101 -S nginx && \
    adduser -u 101 -S -G nginx -h /var/cache/nginx -s /sbin/nologin nginx

# 复制编译好的 nginx 文件和模块
COPY --from=builder /usr/sbin/nginx /usr/sbin/nginx
COPY --from=builder /etc/nginx /etc/nginx
COPY --from=builder /var/log/nginx /var/log/nginx
COPY --from=builder /etc/nginx/modules /etc/nginx/modules

# 软链接日志到标准输出，方便 docker logs
RUN ln -sf /dev/stdout /var/log/nginx/access.log && \
    ln -sf /dev/stderr /var/log/nginx/error.log

# 暴露端口
EXPOSE 80 443

# 切换非 root 用户运行
USER nginx

# 启动命令，前台运行
CMD ["nginx", "-g", "daemon off;"]
