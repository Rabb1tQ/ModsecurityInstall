#!/bin/bash

echo "-------------------------Stopping services-------------------------"
# 停止 ClickHouse 服务
if systemctl is-active --quiet clickhouse-server; then
    echo "Stopping ClickHouse service..."
    sudo systemctl stop clickhouse-server
    echo "ClickHouse service stopped."
else
    echo "ClickHouse service is not running."
fi

# 停止 Vector 服务
if systemctl is-active --quiet vector; then
    echo "Stopping Vector service..."
    sudo systemctl stop vector
    echo "Vector service stopped."
else
    echo "Vector service is not running."
fi

# 停止 OpenResty 服务（如果存在）
if [ -f "/opt/openresty/nginx/sbin/nginx" ]; then
    echo "Stopping OpenResty..."
    /opt/openresty/nginx/sbin/nginx -s stop
    echo "OpenResty stopped."
else
    echo "OpenResty is not installed or already stopped."
fi

echo "-------------------------Removing installed files-------------------------"
# 删除 ClickHouse
if dpkg -l | grep -q clickhouse; then
    echo "Removing ClickHouse packages..."
    sudo apt-get remove --purge -y clickhouse-server clickhouse-client
    echo "ClickHouse packages removed."
else
    echo "ClickHouse is not installed."
fi
echo "Removing ClickHouse files..."
sudo rm -rf /etc/clickhouse-server /var/lib/clickhouse /var/log/clickhouse-server
echo "ClickHouse files removed."

# 删除 Vector
if dpkg -l | grep -q vector; then
    echo "Removing Vector package..."
    sudo apt-get remove --purge -y vector
    echo "Vector package removed."
else
    echo "Vector is not installed."
fi
echo "Removing Vector files..."
sudo rm -rf /etc/vector /usr/bin/vector /var/lib/vector /var/log/vector
echo "Vector files removed."

# 删除 OpenResty 和 ModSecurity
echo "Removing OpenResty and ModSecurity..."
sudo rm -rf /opt/openresty
sudo rm -rf ModSecurity ModSecurity-nginx openresty-1.25.3.2 openresty-1.25.3.2.tar.gz
echo "OpenResty and ModSecurity removed."

# 删除 ModSecurity 规则
echo "Removing ModSecurity rules..."
sudo rm -rf coreruleset-4.7.0 coreruleset-4.7.0-minimal.tar.gz
echo "ModSecurity rules removed."

# 删除 Nginx 相关残留配置
if [ -d "/etc/nginx" ] && grep -q "modsecurity" /etc/nginx/nginx.conf; then
    echo "Removing Nginx configuration with ModSecurity..."
    sudo rm -rf /etc/nginx/nginx.conf /etc/nginx/modsecurity
    echo "Nginx configuration with ModSecurity removed."
else
    echo "No Nginx configuration with ModSecurity found."
fi

echo "-------------------------Cleaning dependencies-------------------------"
# 删除安装的依赖项（仅当没有其他包依赖时）
DEPENDENCIES="git g++ apt-utils autoconf automake build-essential libcurl4-openssl-dev libgeoip-dev liblmdb-dev libpcre2-dev libtool libxml2-dev libyajl-dev pkgconf zlib1g-dev libssl-dev perl make curl libpcre3-dev libxml2 libxslt1-dev"
for package in $DEPENDENCIES; do
    if dpkg -l | grep -q "^ii\s*$package"; then
        # 检查是否有其他包依赖该依赖项
        echo "Checking dependency: $package..."
        if apt-cache rdepends --installed "$package" | grep -qv "^ $package$"; then
            echo "Dependency $package is required by other packages. Skipping removal."
        else
            echo "Removing unused dependency: $package..."
            sudo apt-get remove --purge -y "$package"
            echo "Dependency $package removed."
        fi
    else
        echo "Dependency $package is not installed."
    fi
done


# 自动清理不需要的包
echo "Cleaning up unnecessary packages..."
sudo apt-get autoremove -y
sudo apt-get clean
echo "Dependency cleanup completed."

echo "-------------------------Removing logs and temporary files-------------------------"
# 删除特定应用的日志和临时文件
echo "Removing logs and temporary files..."
sudo rm -rf /var/log/nginx /var/log/openresty /var/log/modsecurity /var/log/vector /var/log/clickhouse-server
sudo rm -rf /tmp/* /var/tmp/*
echo "Logs and temporary files removed."

echo "-------------------------Clearing systemd services (if applicable)-------------------------"
# 删除 Vector 和 ClickHouse 的 systemd 服务配置文件
if [ -f "/etc/systemd/system/vector.service" ]; then
    echo "Removing Vector service file..."
    sudo rm -f /etc/systemd/system/vector.service
    echo "Vector service file removed."
else
    echo "No Vector service file found."
fi

if [ -f "/etc/systemd/system/clickhouse-server.service" ]; then
    echo "Removing ClickHouse service file..."
    sudo rm -f /etc/systemd/system/clickhouse-server.service
    echo "ClickHouse service file removed."
else
    echo "No ClickHouse service file found."
fi

sudo systemctl daemon-reload
echo "Systemd services cleanup completed."

echo "-------------------------Verifying uninstallation-------------------------"
# 检查是否有残留服务
SERVICES=("clickhouse-server" "vector" "nginx" "openresty")
for service in "${SERVICES[@]}"; do
    echo "Checking for remaining service: $service..."
    if systemctl is-active --quiet "$service"; then
        echo "Warning: Service $service is still running or exists. Manual intervention may be required."
    else
        echo "Service $service is not running."
    fi
done

echo "-------------------------Uninstallation complete-------------------------"
