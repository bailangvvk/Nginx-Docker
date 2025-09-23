# 最新版本的Alpine镜像 减少攻击面
FROM alpine:latest AS builder

# 使用内存作为工作路径 加快读写速度
WORKDIR /tmp

# 安装构建依赖
# -e 如果任何命令执行失败（即返回非零退出状态码）
# -u 启用此选项后，当脚本尝试使用一个未定义的变量时，会将其视为一个错误并立即终止执行
# -x 启用此选项后，脚本在执行每一条命令之前，都会将其（包括参数）打印到标准错误输出
RUN set -eux \
    # 自动清理下载的包索引 编译依赖
    && \
    apk add --no-cache --virtual .build-deps \
    build-base \
    # gcc \
    # make \
    curl \
    # pcre-dev \
    # zlib-dev \
    linux-headers \
    perl \
    sed \
    grep \
    tar \
    # bash \
    jq \
    git \
    && \
    # --- Nginx ---
    NGINX_TAG=$(curl -s https://api.github.com/repos/nginx/nginx/releases/latest | jq -r '.tag_name') \
    && \
    NGINX_VERSION=$(echo "$NGINX_TAG" | sed -e 's/^release-//') \
    && \
    # git clone --depth 1 --branch ${NGINX_TAG} https://github.com/nginx/nginx.git nginx-${NGINX_VERSION} \
    curl -fSL https://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz -o nginx.tar.gz && \
    tar xzf nginx.tar.gz && \
    && \
    \
    # --- OpenSSL ---
    OPENSSL_TAG=$(curl -s https://api.github.com/repos/openssl/openssl/releases/latest | jq -r '.tag_name') \
    && \
    OPENSSL_VERSION=$(echo "$OPENSSL_TAG" | sed -e 's/^openssl-//') \
    && \
    git clone --depth 1 --branch ${OPENSSL_TAG} https://github.com/openssl/openssl.git openssl-${OPENSSL_VERSION} \
    && \
    \
    # --- Zlib ---
    ZLIB_TAG=$(curl -s https://api.github.com/repos/madler/zlib/releases/latest | jq -r '.tag_name') \
    && \
    ZLIB_VERSION=$(echo "$ZLIB_TAG" | sed -e 's/^v//') \
    && \
    git clone --depth 1 --branch ${ZLIB_TAG} https://github.com/madler/zlib.git zlib-${ZLIB_VERSION} \
    && \
    # --- PCRE2 ---
    PCRE2_TAG=$(curl -s https://api.github.com/repos/PCRE2Project/pcre2/releases/latest | jq -r '.tag_name') \
    && \
    PCRE2_VERSION=$(echo "$PCRE2_TAG" | sed -e 's/^v//' -e 's/^PCRE2-//') \
    && \
    git clone --depth 1 --branch ${PCRE2_TAG} https://github.com/PCRE2Project/pcre2.git pcre2-${PCRE2_VERSION} \
    && \
    # 编译步骤
    cd nginx-${NGINX_VERSION} \
    && \
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
    strip /usr/sbin/nginx

# 最新版本的Alpine镜像 减少攻击面
FROM alpine:latest

# 拷贝 Nginx 二进制文件
COPY --from=builder /usr/sbin/nginx /usr/sbin/nginx
# 拷贝 Nginx 默认配置文件目录
COPY --from=builder /etc/nginx /etc/nginx
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
