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
    # --prefix=/etc/nginx \  <-- 修改点 1: 移除此行，使用默认的 /usr/local/nginx
    --user=root \
    --group=root \
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
    strip /usr/local/nginx/sbin/nginx # <-- 修改点 2: 更新 strip 命令的路径


# 最小运行时镜像
# FROM busybox:1.35-uclibc
# FROM alpine:3.20
FROM alpine:latest
# FROM gcr.io/distroless/static

# 混合式编译的话就不用了
# RUN apk add --no-cache pcre

# 拷贝构建产物
# COPY --from=builder /etc/nginx /etc/nginx
COPY --from=builder /usr/local/nginx /usr/local/nginx # <-- 修改点 3: 更新 COPY 命令的源和目标路径

# 暴露端口
EXPOSE 80 443

# WORKDIR /etc/nginx
WORKDIR /usr/local/nginx # <-- 修改点 4: 更新工作目录

# 启动 nginx
# CMD ["/etc/nginx/sbin/nginx", "-g", "daemon off;"]
CMD ["/usr/local/nginx/sbin/nginx", "-g", "daemon off;"] # <-- 修改点 5: 更新 CMD 命令的路径
