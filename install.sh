#/bin/sh

echo "-------------------------Installing dependencies-------------------------"
apt-get update
apt-get install git g++ apt-utils autoconf automake build-essential libcurl4-openssl-dev libgeoip-dev liblmdb-dev libpcre2-dev libtool libxml2-dev libyajl-dev pkgconf zlib1g-dev
echo "-------------------------Dependencies installed-------------------------"

echo "-------------------------Installing ModSecurity-------------------------"
ModSecurityDIR="ModSecurity"

# 检查目录是否存在
if [ -d "$ModSecurityDIR" ]; then
  echo "[*]ModSecurity has been cloned."
else
  git clone https://github.com/owasp-modsecurity/ModSecurity
fi

cd ModSecurity/
git submodule init
git submodule update
sh build.sh
./configure --with-pcre2
make
make install
echo "-------------------------ModSecurity installed-------------------------"

cd ../

echo "-------------------------Installing Nginx-------------------------"
ModSecuritynginxDIR="ModSecurity-nginx"
# 检查目录是否存在
if [ -d "$ModSecuritynginxDIR" ]; then
  echo "[*]ModSecurity-nginx has been cloned."
else
  git clone https://github.com/owasp-modsecurity/ModSecurity-nginx
fi

nginxDIR="nginx-1.27.2"
# 检查目录是否存在
if [ -d "$nginxDIR" ]; then
  echo "[*]nginx has been download."
else
  wget https://nginx.org/download/nginx-1.27.2.tar.gz
  tar -xvzf nginx-1.27.2.tar.gz nginx-1.27.2/
fi

cd nginx-1.27.2/
./configure --add-module=../ModSecurity-nginx
make
make install
echo "-------------------------Nginx installed-------------------------"

cd ../

echo "-------------------------Configuring ModSecurity-------------------------"
mkdir /usr/local/nginx/conf/modsecurity/
cp modsecurity.conf /usr/local/nginx/conf/modsecurity/
cp ModSecurity/unicode.mapping /usr/local/nginx/conf/modsecurity/
echo "-------------------------ModSecurity configured-------------------------"

echo "-------------------------Installing ModSecurity rules-------------------------"

corerulesetDIR="coreruleset-4.7.0"
# 检查目录是否存在
if [ -d "$corerulesetDIR" ]; then
  echo "[*]corerule has been download."
else
  wget https://github.com/coreruleset/coreruleset/releases/download/v4.7.0/coreruleset-4.7.0-minimal.tar.gz
  tar -xvzf coreruleset-4.7.0-minimal.tar.gz
fi

cd coreruleset-4.7.0
cp rules/REQUEST-900-EXCLUSION-RULES-BEFORE-CRS.conf.example rules/REQUEST-900-EXCLUSION-RULES-BEFORE-CRS.conf
cp rules/RESPONSE-999-EXCLUSION-RULES-AFTER-CRS.conf.example rules/RESPONSE-999-EXCLUSION-RULES-AFTER-CRS.conf
cp crs-setup.conf.example /usr/local/nginx/conf/modsecurity/crs-setup.conf
cp -r rules /usr/local/nginx/conf/modsecurity/
echo "-------------------------ModSecurity rules installed-------------------------"

cd ../

echo "-------------------------Configuring Nginx-------------------------"
cp nginx.conf /usr/local/nginx/conf/
echo "-------------------------Nginx configured-------------------------"



echo "-------------------------Creating directories-------------------------"
mkdir -p /var/www/html
echo "-------------------------Directories created-------------------------"

echo "-------------------------Starting Nginx-------------------------"
/usr/local/nginx/sbin/nginx
echo "-------------------------Nginx started-------------------------"

echo "-------------------------Installation complete-------------------------"
