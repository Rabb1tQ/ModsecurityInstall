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

# 安装 ClickHouse
echo "-------------------------Installing ClickHouse-------------------------"
apt-get update
apt-get install -y apt-transport-https ca-certificates curl gnupg
curl -fsSL 'https://packages.clickhouse.com/rpm/lts/repodata/repomd.xml.key' | gpg --dearmor -o /usr/share/keyrings/clickhouse-keyring.gpg

echo "deb [signed-by=/usr/share/keyrings/clickhouse-keyring.gpg] https://packages.clickhouse.com/deb stable main" | tee \
    /etc/apt/sources.list.d/clickhouse.list
apt-get update
sudo apt-get install -y clickhouse-server clickhouse-client

rm -rf /etc/clickhouse-server/users.d

# 定义配置文件路径
CONFIG_XML="/etc/clickhouse-server/config.xml"
USERS_XML="/etc/clickhouse-server/users.xml"
DEFAULT_XML="/etc/clickhouse-server/default.xml"


# 设置 ClickHouse 默认用户密码
PASSWORD="your_password_here"

# 检查并处理配置文件组合情况
if [ -f "$USERS_XML" ] && [ ! -f "$DEFAULT_XML" ]; then
    echo "users.xml exists, default.xml does not exist."
    echo "Setting default user password in users.xml..."
    sed -i "/<default>/,/<\/default>/s|<password>.*</password>|<password>${PASSWORD}</password>|" "$USERS_XML"
elif [ ! -f "$USERS_XML" ] && [ -f "$DEFAULT_XML" ]; then
    echo "users.xml does not exist, default.xml exists."
    echo "Setting default user password in default.xml..."
    sed -i "/<default>/,/<\/default>/s|<password>.*</password>|<password>${PASSWORD}</password>|" "$DEFAULT_XML"
elif [ -f "$USERS_XML" ] && [ -f "$DEFAULT_XML" ]; then
    echo "Both users.xml and default.xml exist. Using users.xml to set the password."
    sed -i "/<default>/,/<\/default>/s|<password>.*</password>|<password>${PASSWORD}</password>|" "$USERS_XML"
elif [ ! -f "$USERS_XML" ] && [ ! -f "$DEFAULT_XML" ]; then
    echo "Neither users.xml nor default.xml exists. Creating users.xml and setting the password..."
    mkdir -p /etc/clickhouse-server
    cat > "$USERS_XML" << EOF
<yandex>
    <users>
        <default>
            <password>${PASSWORD}</password>
            <profile>default</profile>
            <quota>default</quota>
            <networks>
                <ip>::/0</ip>
            </networks>
        </default>
    </users>
    <profiles>
        <default/>
    </profiles>
    <quotas>
        <default/>
    </quotas>
</yandex>
EOF
fi

# 检查并补充 profiles 配置
if [ -f "$USERS_XML" ]; then
    echo "Checking users.xml configuration..."
    if ! grep -q "<profiles>" "$USERS_XML"; then
        echo "Adding missing <profiles> tag..."
        sed -i '/<\/users>/i\
    <profiles>\
        <default/>\
    </profiles>' "$USERS_XML"
    fi
fi

# 检查 config.xml 文件是否存在并补充 mark_cache_size
if [ ! -f "$CONFIG_XML" ]; then
    echo "Generating default config.xml..."
    mkdir -p /etc/clickhouse-server
    cat > "$CONFIG_XML" << EOF
<yandex>
    <logger>
        <level>information</level>
        <log>/var/log/clickhouse-server/clickhouse-server.log</log>
        <errorlog>/var/log/clickhouse-server/clickhouse-server.err.log</errorlog>
        <size>1000M</size>
        <count>10</count>
    </logger>
    <http_port>8123</http_port>
    <tcp_port>9000</tcp_port>
    <path>/var/lib/clickhouse/</path>
    <tmp_path>/var/lib/clickhouse/tmp/</tmp_path>
    <user_files_path>/var/lib/clickhouse/user_files/</user_files_path>
    <users_config>${USERS_XML}</users_config>
    <mark_cache_size>536870912</mark_cache_size> <!-- 512MB -->
</yandex>
EOF
else
    echo "Checking config.xml configuration..."
    if ! grep -q "<mark_cache_size>" "$CONFIG_XML"; then
        echo "Adding missing mark_cache_size configuration..."
        sed -i '/<\/yandex>/i\    <mark_cache_size>536870912</mark_cache_size>' "$CONFIG_XML"
    fi
fi

# 启动 ClickHouse 服务
echo "-------------------------Starting ClickHouse Service-------------------------"
service clickhouse-server start

# 检查服务状态并打印日志
echo "-------------------------Checking ClickHouse Service Status-------------------------"
service clickhouse-server status || { echo "ClickHouse service failed to start. Please check the logs!"; exit 1; }

# 重启 ClickHouse 服务以应用配置更改
echo "-------------------------Restarting ClickHouse Service-------------------------"
mkdir -p /var/lib/clickhouse /var/lib/clickhouse/tmp /var/lib/clickhouse/user_files
chown -R clickhouse:clickhouse /var/lib/clickhouse
chmod -R 750 /var/lib/clickhouse

service clickhouse-server restart

# 等待 ClickHouse 服务完全启动
echo "-------------------------Waiting for ClickHouse Service to Start-------------------------"
for i in {1..10}; do
    if clickhouse-client --query="SELECT 1" --password="${PASSWORD}" > /dev/null 2>&1; then
        echo "ClickHouse service is ready."
        break
    fi
    echo "Waiting... (${i}/10)"
    sleep 2
done

if ! clickhouse-client --query="SELECT 1" --password="${PASSWORD}" > /dev/null 2>&1; then
    echo "ClickHouse service did not start within the expected time. Please check the logs!"
    exit 1
fi

# 执行 SQL 语句创建表
echo "-------------------------Executing SQL to Create Tables-------------------------"
# 执行第一个 SQL 语句：创建数据库
echo "-------------------------Creating Database-------------------------"
clickhouse-client --password="${PASSWORD}" --query="CREATE DATABASE IF NOT EXISTS security_logs;"

# 执行第二个 SQL 语句：创建 modsecurity_logs 表
echo "-------------------------Creating modsecurity_logs Table-------------------------"
clickhouse-client --password="${PASSWORD}" --query="CREATE TABLE IF NOT EXISTS security_logs.modsecurity_logs (
    client_ip String,
    timestamp DateTime,
    server_id String,
    client_port UInt16,
    host_ip String,
    host_port UInt16,
    unique_id String,
    method String,
    http_version Float32,
    uri String,
    headers String,
    response_body String,
    http_code UInt16,
    response_headers String,
    modsecurity_version String,
    connector_version String,
    secrules_engine String,
    messages String
) ENGINE = MergeTree()
ORDER BY timestamp;"

# 执行第三个 SQL 语句：创建 nginx_log 表
echo "-------------------------Creating nginx_log Table-------------------------"
clickhouse-client --password="${PASSWORD}" --query="CREATE TABLE IF NOT EXISTS security_logs.nginx_log (
    ip String,
    time DateTime,
    url String,
    status UInt8,
    size UInt32,
    agent String
) ENGINE = MergeTree()
ORDER BY time;"

echo "-------------------------ClickHouse Installation and Table Creation Completed-------------------------"

# 安装 Vector
echo "-------------------------Installing Vector-------------------------"
bash -c "$(curl -L https://setup.vector.dev)"
apt install vector
cp /etc/vector/vector.yaml /etc/vector/vector.yaml.bak
cp vector.yaml /etc/vector/
# 替换 vector.yaml 并更新其中的 ClickHouse 密码
echo "-------------------------Updating vector.yaml with ClickHouse Password-------------------------"
VECTOR_CONFIG="/etc/vector/vector.yaml"

if [ -f "$VECTOR_CONFIG" ]; then
    sed -i "s/kali/${PASSWORD}/g" "$VECTOR_CONFIG"
else
    echo "vector.yaml file not found. Please check the path."
    exit 1
fi

# 启动 Vector 服务
echo "-------------------------Starting Vector Service-------------------------"
service vector start

echo "-------------------------Vector Installation Completed-------------------------"

echo "-------------------------Installation complete-------------------------"

