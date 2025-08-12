# FROM alpine:3.20 AS builder
FROM alpine:latest AS builder

# WORKDIR /build
WORKDIR /tmp

# 安装构建依赖
RUN set -eux && \
    apk add --no-cache \
    build-base \
    curl \
    # pcre-dev \
    # zlib-dev \
    linux-headers \
    perl \
    sed \
    grep \
    tar \
    bash \
    jq && \
    NGINX_VERSION=$(wget -q -O - https://nginx.org/en/download.html | grep -oE 'nginx-[0-9]+\.[0-9]+\.[0-9]+' | head -n1 | cut -d'-' -f2) \
    && \
    OPENSSL_VERSION=$(wget -q -O - https://www.openssl.org/source/ | grep -oE 'openssl-[0-9]+\.[0-9]+\.[0-9]+' | head -n1 | cut -d'-' -f2) \
    && \
    ZLIB_VERSION=$(wget -q -O - https://zlib.net/ | grep -oE 'zlib-[0-9]+\.[0-9]+\.[0-9]+' | head -n1 | cut -d'-' -f2) \
    && \
    ZSTD_VERSION=$(curl -Ls https://github.com/facebook/zstd/releases/latest | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' | head -n1 | cut -c2-) \
    && \
    CORERULESET_VERSION=$(curl -s https://api.github.com/repos/coreruleset/coreruleset/releases/latest | grep -oE '"tag_name": "[^"]+' | cut -d'"' -f4 | sed 's/v//') \
    && \
    # PCRE_VERSION=$(curl -sL https://sourceforge.net/projects/pcre/files/pcre/ | grep -oE 'pcre-[0-9]+\.[0-9]+' | cut -d'-' -f2 | sort -Vr | head -n1) \
    PCRE2_VERSION=$(curl -sL https://github.com/PCRE2Project/pcre2/releases/ | grep -ioE 'pcre2-[0-9]+\.[0-9]+' | grep -v RC | cut -d'-' -f2 | sort -Vr | head -n1) \
    && \
    \
    echo "=============版本号=============" && \
    echo "NGINX_VERSION=${NGINX_VERSION}" && \
    echo "OPENSSL_VERSION=${OPENSSL_VERSION}" && \
    echo "ZLIB_VERSION=${ZLIB_VERSION}" && \
    echo "ZSTD_VERSION=${ZSTD_VERSION}" && \
    echo "CORERULESET_VERSION=${CORERULESET_VERSION}" && \
    # echo "PCRE_VERSION=${PCRE_VERSION}" && \
    echo "PCRE2_VERSION=${PCRE2_VERSION}" && \
    \
    # # fallback 以防 curl/grep 失败
    # NGINX_VERSION="${NGINX_VERSION:-1.29.0}" && \
    # OPENSSL_VERSION="${OPENSSL_VERSION:-3.3.0}" && \
    # ZLIB_VERSION="${ZLIB_VERSION:-1.3.1}" && \
    # ZSTD_VERSION="${ZSTD_VERSION:-1.5.7}" && \
    # CORERULESET_VERSION="${CORERULESET_VERSION}" && \
    # \
    # echo "==> Using versions: nginx-${NGINX_VERSION}, openssl-${OPENSSL_VERSION}, zlib-${ZLIB_VERSION}" && \
    # \
    curl -fSL https://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz -o nginx.tar.gz && \
    tar xzf nginx.tar.gz && \
    \
    curl -fSL https://www.openssl.org/source/openssl-${OPENSSL_VERSION}.tar.gz -o openssl.tar.gz && \
    tar xzf openssl.tar.gz && \
    \
    curl -fSL https://fossies.org/linux/misc/zlib-${ZLIB_VERSION}.tar.gz -o zlib.tar.gz && \
    tar xzf zlib.tar.gz && \
    \
    # curl -fSL https://downloads.sourceforge.net/project/pcre/pcre/${PCRE_VERSION}/pcre-${PCRE_VERSION}.tar.gz -o pcre.tar.gz && \
    # tar xzf pcre.tar.gz && \
    # \
    curl -fSL https://github.com/PCRE2Project/pcre2/releases/download/pcre2-${PCRE2_VERSION}/pcre2-${PCRE2_VERSION}.tar.gz -o pcre2.tar.gz && \
    tar xzf pcre2.tar.gz && \
    \
    cd nginx-${NGINX_VERSION} && \
    ./configure \
    --user=root \
    --group=root \
    # --prefix=/etc/nginx \
    --sbin-path=/usr/sbin/nginx \
    --conf-path=/etc/nginx/nginx.conf \
    --pid-path=/var/log/nginx/nginx.pid \
    --error-log-path=/var/log/nginx/error.log \
    --http-log-path=/var/log/nginx/access.log \
    --http-client-body-temp-path=/var/cache/nginx/client_body_temp \
    --http-proxy-temp-path=/var/cache/nginx/proxy_temp \
    --http-fastcgi-temp-path=/var/cache/nginx/fastcgi_temp \
    --http-uwsgi-temp-path=/var/cache/nginx/uwsgi_temp \
    --http-scgi-temp-path=/var/cache/nginx/scgi_temp \
    --with-compat \
    # --with-cc-opt="-static -static-libgcc" \
    # --with-ld-opt="-static" \
    --with-openssl=../openssl-${OPENSSL_VERSION} \
    --with-zlib=../zlib-${ZLIB_VERSION} \
    # --with-pcre \
    # --with-pcre=../pcre-${PCRE_VERSION} \
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
    # strip /etc/nginx/sbin/nginx
    # strip /usr/local/nginx/sbin/nginx
    strip /usr/sbin/nginx # <-- 修改点 2: 更新 strip 命令的路径


# 最小运行时镜像
# FROM busybox:1.35-uclibc
# FROM alpine:3.20
FROM alpine:latest
# FROM gcr.io/distroless/static

# 混合式编译的话就不用了
# RUN apk add --no-cache pcre

# 拷贝构建产物
# COPY --from=builder /etc/nginx /etc/nginx
# COPY --from=builder /usr/local/nginx /usr/local/nginx
# <-- 修改点 3: 拷贝分散的构建产物
# 复制所有需要的文件和目录，并确保属主正确
COPY --from=builder /usr/sbin/nginx /usr/sbin/nginx
COPY --from=builder /etc/nginx/nginx.conf /etc/nginx/nginx.conf
COPY --from=builder /etc/nginx/mime.types /etc/nginx/mime.types
COPY --from=builder /etc/nginx/html /etc/nginx/html
COPY --from=builder /var/cache/nginx /var/cache/nginx
COPY --from=builder /var/log/nginx /var/log/nginx

# <-- 修改点 4: 创建 Nginx 运行时需要的目录
# Nginx 需要这些目录来写入 pid, logs, 和 cache 文件
# 必须手动创建，因为它们在运行时才会用到，并且 make install 不会把它们打包到最终镜像
RUN mkdir -p /var/log/nginx && \
    mkdir -p /var/cache/nginx

# 暴露端口
EXPOSE 80 443

# # WORKDIR /etc/nginx
# WORKDIR /usr/local/nginx

# # 启动 nginx
# # CMD ["/etc/nginx/sbin/nginx", "-g", "daemon off;"]
# CMD ["/usr/local/nginx/sbin/nginx", "-g", "daemon off;"]

# 设置工作目录 (可选，但 /etc/nginx 是个不错的选择)
WORKDIR /etc/nginx
# <-- 修改点 5: 更新 CMD 命令以使用新的二进制文件路径
CMD ["/usr/sbin/nginx", "-g", "daemon off;"]
