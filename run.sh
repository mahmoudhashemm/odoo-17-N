#!/bin/bash
set -euo pipefail

# Usage:
# ./run.sh DESTINATION PORT CHAT PORT8069 PORT8072 SUBNET GATEWAY ODOO_IP DB_IP [NETWORK_NAME] [IP_RANGE]
if [ $# -lt 9 ]; then
  echo "Usage: $0 DESTINATION PORT CHAT PORT8069 PORT8072 SUBNET GATEWAY ODOO_IP DB_IP [NETWORK_NAME] [IP_RANGE]"
  exit 1
fi

DESTINATION="$1"
PORT="$2"
CHAT="$3"
PORT8069="$4"
PORT8072="$5"
SUBNET="$6"
GATEWAY="$7"
ODOO_IP="$8"
DB_IP="$9"
NETWORK_NAME="${10:-${DESTINATION}_net6}"
IP_RANGE="${11:-$SUBNET}"

# استنساخ الريبو
git clone --depth=1 https://github.com/mahmoudhashemm/odoo-17-test.git "$DESTINATION"
rm -rf "$DESTINATION/.git"

# إنشاء مجلدات
mkdir -p "$DESTINATION/postgresql" "$DESTINATION/enterprise"
sudo chmod -R 777 "$DESTINATION"

# نسخ yml
cp docker-compose.yml "$DESTINATION/docker-compose.yml"

# 1) إزالة التعليقات
sed -i 's/#.*$//' "$DESTINATION/docker-compose.yml"

# 2) تعديل القيم
sed -i "s/10019/${PORT}/g"  "$DESTINATION/docker-compose.yml"
sed -i "s/20014/${CHAT}/g"  "$DESTINATION/docker-compose.yml"
sed -i "s/:8069\"/:${PORT8069}\"/g" "$DESTINATION/docker-compose.yml"
sed -i "s/:8072\"/:${PORT8072}\"/g" "$DESTINATION/docker-compose.yml"

sed -i "s/172.28.10.0\/29/${SUBNET}/g" "$DESTINATION/docker-compose.yml"
sed -i "s/172.28.10.1/${GATEWAY}/g" "$DESTINATION/docker-compose.yml"
sed -i "s/172.28.10.2/${ODOO_IP}/g" "$DESTINATION/docker-compose.yml"
sed -i "s/172.28.10.3/${DB_IP}/g" "$DESTINATION/docker-compose.yml"
sed -i "s/odoo-net6/${NETWORK_NAME}/g" "$DESTINATION/docker-compose.yml"

# تعديل odoo.conf
sed -i "s/8069/${PORT8069}/g" "$DESTINATION/etc/odoo.conf"
sed -i "s/8072/${PORT8072}/g" "$DESTINATION/etc/odoo.conf"

# تنزيل enterprise
git clone --depth 1 --branch main https://github.com/mahmoudhashemm/odoo17pro "$DESTINATION/enterprise" || true

# تشغيل
cd "$DESTINATION"
docker compose up -d || docker-compose up -d

echo "✅ Started Odoo @ http://localhost:${PORT}"
echo "🔑 Master Password: Omar@012"
echo "📦 Network: ${NETWORK_NAME} | Subnet: ${SUBNET}"
