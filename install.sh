#/bin/sh
echo "-------------------------Installing dependencies-------------------------"
apt-get update && apt-get install -y git g++ apt-utils autoconf automake build-essential libcurl4-openssl-dev libgeoip-dev liblmdb-dev libpcre2-dev libtool libxml2-dev libyajl-dev pkgconf zlib1g-dev libssl-dev perl make curl libpcre3-dev libxml2 libxslt1-dev
echo "-------------------------Dependencies installed-------------------------"

echo "-------------------------Installing ModSecurity-------------------------"
ModSecurityDIR="ModSecurity"

# 检查目录是否存在
if [ -d "${ModSecurityDIR}" ]; then
  echo "[*]ModSecurity has been cloned."
else
  git clone https://github.com/owasp-modsecurity/ModSecurity "${ModSecurityDIR}" || { echo "Failed to clone ModSecurity"; exit 1; }
fi

cd "${ModSecurityDIR}" || { echo "Failed to enter directory${ModSecurityDIR}"; exit 1; }
git submodule init
git submodule update
sh build.sh
./configure --with-pcre2
# 检查父目录中是否存在ltmain.sh文件
if [ -f "../ltmain.sh" ]; then
    echo "ltmain.sh found in the parent directory. Moving it to the current directory."
    rm -rf ../ltmain.sh
    # 重新执行configure脚本
    echo "Re-running configure script."
    sh build.sh
    ./configure --with-pcre2
fi
make
make install
echo "-------------------------ModSecurity installed-------------------------"

cd ..

echo "-------------------------Installing Openresty-------------------------"
ModSecuritynginxDIR="ModSecurity-nginx"
# 检查目录是否存在
if [ -d "${ModSecuritynginxDIR}" ]; then
  echo "[*]ModSecurity-nginx has been cloned."
else
  git clone https://github.com/owasp-modsecurity/ModSecurity-nginx "${ModSecuritynginxDIR}" || { echo "Failed to clone ModSecurity-nginx"; exit 1; }
fi

OpenrestyDIR="openresty-1.25.3.2"
# 检查目录是否存在
if [ -d "${OpenrestyDIR}" ]; then
  echo "[*]Openresty has been download."
else
  wget https://github.com/openresty/openresty/releases/download/v1.25.3.2/openresty-1.25.3.2.tar.gz || { echo "Failed to download Openresty"; exit 1; }
  tar -xvzf openresty-1.25.3.2.tar.gz openresty-1.25.3.2/ || { echo "Failed to extract Openresty"; exit 1; }
fi

cd "${OpenrestyDIR}" || { echo "Failed to enter directory${OpenrestyDIR}"; exit 1; }
./configure --add-dynamic-module=../ModSecurity-nginx --prefix=/opt/openresty --with-http_ssl_module --with-http_ssl_module --with-http_v2_module --with-http_gzip_static_module --with-http_sub_module --with-http_realip_module --with-http_stub_status_module --with-http_auth_request_module --with-luajit --with-compat --with-http_geoip_module --with-stream --with-stream_ssl_module --with-mail --with-mail_ssl_module --with-threads --with-file-aio --with-http_dav_module --with-http_xslt_module --with-http_addition_module 
gmake
gmake install
echo "-------------------------Openresty installed-------------------------"

cd ../

echo "-------------------------Configuring ModSecurity-------------------------"
mkdir -p /opt/openresty/nginx/conf/modsecurity/ || { echo "Failed to create modsecurity directory"; exit 1; }
cp modsecurity.conf /opt/openresty/nginx/conf/modsecurity/ || { echo "Failed to copy modsecurity.conf"; exit 1; }
cp "${ModSecurityDIR}"/unicode.mapping /opt/openresty/nginx/conf/modsecurity/ || { echo "Failed to copy unicode.mapping"; exit 1; }
echo "-------------------------ModSecurity configured-------------------------"

echo "-------------------------Installing ModSecurity rules-------------------------"

corerulesetDIR="coreruleset-4.7.0"
# 检查目录是否存在
corerulesetDIR="coreruleset-4.7.0"
# 检查目录是否存在
if [ -d "${corerulesetDIR}" ]; then
  echo "[*]corerule has been download."
else
  wget https://github.com/coreruleset/coreruleset/releases/download/v4.7.0/coreruleset-4.7.0-minimal.tar.gz || { echo "Failed to download corerule"; exit 1; }
  tar -xvzf coreruleset-4.7.0-minimal.tar.gz || { echo "Failed to extract corerule"; exit 1; }
fi

cd coreruleset-4.7.0
cp rules/REQUEST-900-EXCLUSION-RULES-BEFORE-CRS.conf.example rules/REQUEST-900-EXCLUSION-RULES-BEFORE-CRS.conf
cp rules/RESPONSE-999-EXCLUSION-RULES-AFTER-CRS.conf.example rules/RESPONSE-999-EXCLUSION-RULES-AFTER-CRS.conf
cp crs-setup.conf.example /opt/openresty/nginx/conf/modsecurity/crs-setup.conf
cp -r rules /opt/openresty/nginx/conf/modsecurity/
echo "-------------------------ModSecurity rules installed-------------------------"

cd ../

echo "-------------------------Configuring Nginx-------------------------"
cp nginx.conf /opt/openresty/nginx/conf/
echo "-------------------------Nginx configured-------------------------"



echo "-------------------------Creating directories-------------------------"
mkdir -p /var/www/html
echo "-------------------------Directories created-------------------------"

echo "-------------------------Starting Nginx-------------------------"
/opt/openresty/nginx/sbin/nginx
echo "-------------------------Nginx started-------------------------"

echo "-------------------------Installation complete-------------------------"
