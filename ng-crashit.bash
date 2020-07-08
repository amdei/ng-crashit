#!/bin/bash

set -e # fail on any error
set -u # treat unset variables as errors

# store the current dir
CUR_DIR=$(pwd)

apt-get install -y --force-yes --no-install-recommends git build-essential wget tar valgrind
apt-get install -y --force-yes --no-install-recommends --reinstall libluajit-5.1-dev

mkdir -p /var/log/nginx/
mkdir -p /var/spool/nginx/proxy_temp
mkdir -p /var/spool/nginx/client_body_temp
mkdir -p /var/spool/nginx/uwsgi_temp


rm -r nginx-1.18.0 || true
rm nginx-1.18.0.tar.gz  || true

rm -rf ngx-libs
mkdir -p ngx-libs
cd ngx-libs

wget https://www.openssl.org/source/openssl-1.1.1g.tar.gz
wget https://ftp.pcre.org/pub/pcre/pcre-8.44.tar.gz
wget https://zlib.net/zlib-1.2.11.tar.gz

tar xzf pcre-8.44.tar.gz
tar xzf zlib-1.2.11.tar.gz
tar xzf openssl-1.1.1g.tar.gz


cd $CUR_DIR

rm -rf 3rd-party-ngx-modules
mkdir -p 3rd-party-ngx-modules
cd 3rd-party-ngx-modules

git clone https://github.com/simpl/ngx_devel_kit.git
git clone https://github.com/openresty/lua-nginx-module.git

cd ngx_devel_kit
git checkout v0.3.1
cd -

cd lua-nginx-module
git checkout v0.10.15
cd -


cd $CUR_DIR
wget https://nginx.org/download/nginx-1.18.0.tar.gz
tar xzf nginx-1.18.0.tar.gz

cd nginx-1.18.0
wget https://raw.githubusercontent.com/openresty/lua-nginx-module/master/valgrind.suppress
wget https://raw.githubusercontent.com/openresty/no-pool-nginx/master/nginx-1.17.8-no_pool.patch

cp nginx-1.17.8-no_pool.patch nginx-1.18.0-no_pool.patch

sed -i 's/1017008/1018000/' nginx-1.18.0-no_pool.patch
sed -i 's/1.17.8/1.18.0/' nginx-1.18.0-no_pool.patch


patch -p1 < nginx-1.18.0-no_pool.patch

export LUAJIT_INC=/usr/include/luajit-2.1/
export LUAJIT_LIB=/usr/lib/x86_64-linux-gnu/

./configure --user=nginx --group=nginx \
 --with-cc-opt='-DNGX_LUA_USE_ASSERT -DNGX_LUA_ABORT_AT_PANIC -g -ggdb3 -O0 -DDEBUG -DDDEBUG  -fsanitize-address-use-after-scope -fsanitize=leak -fsanitize=undefined -fstack-protector -fstack-protector-strong -fstack-protector-all --param=ssp-buffer-size=4 -Wformat -Werror=format-security -Werror=implicit-function-declaration -Werror -Winit-self -Wp,-D_FORTIFY_SOURCE=2 -fPIC' \
 --with-ld-opt='-Wl,-z,relro -Wl,-z,now -Wl,--as-needed -pie -g -fstack-protector-all -fsanitize=undefined -Wl,-rpath,'$LUAJIT_LIB \
 --prefix=/opt/nginx \
 --conf-path=/etc/opt/nginx/nginx.conf \
 --error-log-path=/var/log/nginx/error.log \
 --http-log-path=/var/log/nginx/access.log \
 --lock-path=/var/run/lock/nginx.lock \
 --pid-path=/var/run/nginx.pid \
 --with-pcre=../ngx-libs/pcre-8.44 --with-pcre-jit \
 --with-zlib=../ngx-libs/zlib-1.2.11 \
 --with-debug \
 --with-http_ssl_module \
 --with-http_stub_status_module \
 --with-openssl=../ngx-libs/openssl-1.1.1g \
 --with-openssl-opt="no-gost no-comp no-dtls no-deprecated no-dynamic-engine no-engine no-hw-padlock no-nextprotoneg no-psk no-tests no-ts no-ui-console --debug -ggdb3 -DPURIFY" \
 --without-http_autoindex_module \
 --without-http_fastcgi_module \
 --without-http_ssi_module \
 --without-http_scgi_module \
 --add-module=../3rd-party-ngx-modules/ngx_devel_kit \
 --add-module=../3rd-party-ngx-modules/lua-nginx-module
 
 
make -j


valgrind --trace-children=yes  --track-origins=yes --num-callers=50 --suppressions=valgrind.suppress ./objs/nginx -p ../t/servroot/ -c conf/nginx.conf
valgrind --trace-children=yes  --track-origins=yes --num-callers=50 --suppressions=valgrind.suppress ./objs/nginx -p ../t/servroot/ -c conf/nginx.conf -s reload
valgrind --trace-children=yes  --track-origins=yes --num-callers=50 --suppressions=valgrind.suppress ./objs/nginx -p ../t/servroot/ -c conf/nginx.conf -s reload
valgrind --trace-children=yes  --track-origins=yes --num-callers=50 --suppressions=valgrind.suppress ./objs/nginx -p ../t/servroot/ -c conf/nginx.conf -s reload

cd $CUR_DIR
