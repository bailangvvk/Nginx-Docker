FROM alpine:3.20 AS builder

RUN apk add --no-cache \
    build-base \
    pcre-dev \
    zlib-dev \
    openssl-dev \
    linux-headers \
    curl \
    sed

# 获取 NGINX 最新版本并编译安装
# RUN NGINX_VERSION=$( \
#         curl -s https://nginx.org/en/download.html | \
#         grep -Eo 'nginx-[0-9]+\.[0-9]+\.[0-9]+\.tar\.gz' | \
#         cut -d'-' -f2 | cut -d'.' -f1-3 | head -n1 \
#     ) && \
#     echo "Downloading nginx version $NGINX_VERSION..." && \
#     curl -sSL https://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz | tar xz && \
#     cd nginx-${NGINX_VERSION} && \
#     ./configure \
#         --prefix=/opt/nginx \
#         --with-http_ssl_module \
#         --with-http_v2_module \
#         --with-http_gzip_static_module \
#         --with-threads \
#         --with-file-aio \
#         --without-http_rewrite_module \
#         --without-http_auth_basic_module \
#         --with-pcre \
#         --with-pcre-jit && \
#     make -j$(nproc) && \
#     make install

RUN NGINX_VERSION=$( \
        curl -s https://nginx.org/en/download.html | \
        grep -Eo 'nginx-[0-9]+\.[0-9]+\.[0-9]+\.tar\.gz' | \
        cut -d'-' -f2 | cut -d'.' -f1-3 | head -n1 \
    ) && \
    echo "Downloading nginx version $NGINX_VERSION..." && \
    curl -sSL https://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz | tar xz && \
    cd nginx-${NGINX_VERSION} && \
    ./configure && \
    --prefix=/opt/nginx \
      --with-http_ssl_module \
      --with-http_v2_module \
      --with-http_gzip_static_module \
      --with-http_stub_status_module \
      --with-http_realip_module \
      --with-http_auth_request_module \
      --with-http_addition_module \
      --with-http_sub_module \
      --with-http_dav_module \
      --with-http_flv_module \
      --with-http_mp4_module \
      --with-http_secure_link_module \
      --with-http_slice_module \
      --with-http_xslt_module=dynamic \
      --with-http_image_filter_module=dynamic \
      --with-http_geoip_module=dynamic \
      --with-http_perl_module=dynamic \
      --with-threads \
      --with-stream \
      --with-stream_ssl_module \
      --with-stream_realip_module \
      --with-stream_ssl_preread_module \
      --with-pcre \
      --with-pcre-jit \
      --with-file-aio $$ \
    make -j$(nproc) && \
    make install

FROM alpine:3.20

RUN apk add --no-cache pcre openssl zlib

RUN addgroup -S nginx && adduser -S nginx -G nginx

COPY --from=builder /opt/nginx /opt/nginx
# COPY nginx.conf /opt/nginx/conf/nginx.conf

EXPOSE 80 443
WORKDIR /opt/nginx
CMD ["./sbin/nginx", "-g", "daemon off;"]
