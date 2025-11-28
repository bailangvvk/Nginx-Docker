# FROM alpine:3.20 AS builder
FROM alpine:latest AS builder

WORKDIR /build

# 安装构建依赖
RUN set -eux && \
    apk add --no-cache \
    build-base \
    curl \
    linux-headers \
    perl \
    sed \
    grep \
    tar \
    git \
    jq && \
    NGINX_VERSION=$(curl -s https://api.github.com/repos/nginx/nginx/tags | jq -r '.[].name' | grep -E '^release-[0-9]+\.[0-9]+\.[0-9]+$' | head -1 | sed 's/release-//') \
    && \
    OPENSSL_VERSION=$(curl -s https://api.github.com/repos/openssl/openssl/tags | jq -r '.[].name' | grep -E '^openssl-[0-9]+\.[0-9]+\.[0-9]+[a-z]?$' | head -1 | sed 's/openssl-//') \
    && \
    ZLIB_VERSION=$(curl -s https://api.github.com/repos/madler/zlib/tags | jq -r '.[].name' | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' | head -1 | sed 's/^v//') \
    && \
    ZSTD_VERSION=$(curl -s https://api.github.com/repos/facebook/zstd/releases/latest | jq -r '.tag_name' | sed 's/^v//') \
    && \
    CORERULESET_VERSION=$(curl -s https://api.github.com/repos/coreruleset/coreruleset/releases/latest | jq -r '.tag_name' | sed 's/^v//') \
    && \
    PCRE2_VERSION=$(curl -s https://api.github.com/repos/PCRE2Project/pcre2/releases/latest | jq -r '.tag_name' | sed 's/^pcre2-//') \
    && \
    \
    echo "=============版本号=============" && \
    echo "NGINX_VERSION=${NGINX_VERSION}" && \
    echo "OPENSSL_VERSION=${OPENSSL_VERSION}" && \
    echo "ZLIB_VERSION=${ZLIB_VERSION}" && \
    echo "ZSTD_VERSION=${ZSTD_VERSION}" && \
    echo "CORERULESET_VERSION=${CORERULESET_VERSION}" && \
    echo "PCRE2_VERSION=${PCRE2_VERSION}" && \
    \
    # 使用 release 压缩包获取源码（包含 configure 脚本）
    curl -L -o nginx-${NGINX_VERSION}.tar.gz https://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz && \
    tar -xzf nginx-${NGINX_VERSION}.tar.gz && \
    \
    git clone --depth 1 https://github.com/openssl/openssl.git openssl-${OPENSSL_VERSION} && \
    \
    git clone --depth 1 https://github.com/madler/zlib.git zlib-${ZLIB_VERSION} && \
    \
    git clone --depth 1 https://github.com/facebook/zstd.git zstd-${ZSTD_VERSION} && \
    \
    git clone --depth 1 https://github.com/coreruleset/coreruleset.git coreruleset-${CORERULESET_VERSION} && \
    \
    git clone --depth 1 https://github.com/PCRE2Project/pcre2.git pcre2-${PCRE2_VERSION} && \
    \
    # 进入 nginx 目录
    cd nginx-${NGINX_VERSION} && \
    ./configure \
    # --prefix=/etc/nginx \
    # --sbin-path=/usr/sbin/nginx \
    # --conf-path=/etc/nginx/nginx.conf \
    # --pid-path=/var/log/nginx/nginx.pid \
    # --error-log-path=/var/log/nginx/error.log \
    # --http-log-path=/var/log/nginx/access.log \
    # --http-client-body-temp-path=/var/cache/nginx/client_body_temp \
    # --http-proxy-temp-path=/var/cache/nginx/proxy_temp \
    # --http-fastcgi-temp-path=/var/cache/nginx/fastcgi_temp \
    # --http-uwsgi-temp-path=/var/cache/nginx/uwsgi_temp \
    # --http-scgi-temp-path=/var/cache/nginx/scgi_temp \

    --prefix=/etc/nginx \
    --sbin-path=/usr/sbin/nginx \
    --modules-path=/usr/lib/nginx/modules \
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
    --user=nginx \
    --group=nginx \

    # --user=root \
    # --group=root \
    # 移除静态编译标志，开启混合编译
    #--with-ld-opt="-static" \
    # 使用更积极的静态编译和优化选项
    --with-cc-opt="-O3 -flto -static -static-libgcc" \
    --with-ld-opt="-flto -static" \
    # --with-cc-opt="-static -static-libgcc" \
    # --with-ld-opt="-static" \
    --with-openssl=../openssl-${OPENSSL_VERSION} \
    --with-zlib=../zlib-${ZLIB_VERSION} \
    # --with-pcre \
    --with-pcre=../pcre2-${PCRE2_VERSION} \
    --with-pcre-jit \
    --with-http_ssl_module \
    --with-http_v2_module \
    --with-http_gzip_static_module \
    --with-http_stub_status_module \
    # --without-http_rewrite_module \
    # --without-http_auth_basic_module \
    --with-threads && \
    make -j$(nproc) && \
    make install && \
    strip /usr/sbin/nginx && \
    # strip /etc/nginx/sbin/nginx && \
    \
    # --- 7. 创建并授权运行时目录 ---
    mkdir -p /var/cache/nginx && \
    mkdir -p /usr/lib/nginx/modules && \
    mkdir -p /var/run && \
    mkdir -p /var/log/nginx
    # && chown -R nginx:nginx /var/cache/nginx && \
    # chown -R nginx:nginx /var/log/nginx

# RUN ln -sf /dev/stdout /usr/local/nginx/logs/access.log                             && \
#    ln -sf /dev/stderr /usr/local/nginx/logs/error.log

# RUN ln -sf /dev/stdout /etc/nginx/logs/access.log                             && \
#     ln -sf /dev/stderr /etc/nginx/logs/error.log

RUN ln -sf /dev/stdout /var/log/nginx/error.log                             && \
     ln -sf /dev/stderr /var/log/nginx/error.log

# 最小运行时镜像
# 非常老牌的、为嵌入式系统设计的轻量级 C 库
# FROM busybox:1.35-uclibc
# 这是一个更现代的、同样轻量级的 C 库，以简洁、高效、标准兼容和安全著称。和 Alpine Linux 使用的完全相同的C 库。
# FROM busybox:musl
FROM alpine:latest
# FROM alpine:3.20
# FROM gcr.io/distroless/static

# 从构建器中找出并复制 nginx 所需的动态链接库
# COPY --from=builder /lib/ld-musl-x86_64.so.1 /lib/
# COPY --from=builder /lib/libc.musl-x86_64.so.1 /lib/
# COPY --from=builder /usr/lib/libcrypto.so.3 /usr/lib/
# COPY --from=builder /lib/libz.so.1 /lib/
# COPY --from=builder /usr/lib/libpcre2-8.so.0 /usr/lib/

# 拷贝构建产物
# COPY --from=builder /etc/nginx /etc/nginx

# 复制所有需要的文件和目录
COPY --from=builder /etc/nginx /etc/nginx
COPY --from=builder /usr/sbin/nginx /usr/sbin/nginx
COPY --from=builder /usr/lib/nginx/modules /usr/lib/nginx/modules
COPY --from=builder /var/log/nginx /var/log/nginx
COPY --from=builder /var/run /var/run
COPY --from=builder /var/cache /var/cache

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# 暴露端口
EXPOSE 80
WORKDIR /usr/sbin

# 如果有端口变量则修改
ENTRYPOINT ["/entrypoint.sh"]
# 启动 nginx
# CMD ["/etc/sbin/nginx", "-g", "daemon off;"]
CMD ["/usr/sbin/nginx", "-g", "daemon off;"]
