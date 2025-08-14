#!/bin/bash
set -euo pipefail

# Usage:
# ./run.sh DESTINATION PORT CHAT PORT8069 PORT8072 SUBNET GATEWAY ODOO_IP DB_IP [NETWORK_NAME] [IP_RANGE]
# NETWORK_NAME افتراضي: ${DESTINATION}_net6
# IP_RANGE افتراضي: نفس SUBNET

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

# فحص البورتات على الهوست
for p in "$PORT" "$CHAT"; do
  if ss -ltn | awk '{print $4}' | grep -q ":${p}$"; then
    echo "ERROR: Port ${p} is already in use on host. اختر بورت مختلف."
    exit 1
  fi
done

# استنساخ الريبو
git clone --depth=1 https://github.com/mahmoudhashemm/odoo-17-test.git "$DESTINATION"
rm -rf "$DESTINATION/.git"

# إنشاء مجلدات وصلاحيات
mkdir -p "$DESTINATION/postgresql" "$DESTINATION/enterprise"
chmod +x "$DESTINATION/entrypoint.sh" 2>/dev/null || true
sudo chmod -R 777 "$DESTINATION"

# inotify
if ! grep -qF "fs.inotify.max_user_watches" /etc/sysctl.conf; then
  echo "fs.inotify.max_user_watches = 524288" | sudo tee -a /etc/sysctl.conf
  sudo sysctl -p
fi

# نسخ ملف yml
cp docker-compose.yml "$DESTINATION/docker-compose.yml"

# تعديل البورتات في yml
sed -i "s/10019/${PORT}/g"  "$DESTINATION/docker-compose.yml"
sed -i "s/20014/${CHAT}/g"  "$DESTINATION/docker-compose.yml"
sed -i "s/:8069\"/:${PORT8069}\"/g" "$DESTINATION/docker-compose.yml"
sed -i "s/:8072\"/:${PORT8072}\"/g" "$DESTINATION/docker-compose.yml"

# تعديل odoo.conf
sed -i "s/8069/${PORT8069}/g" "$DESTINATION/etc/odoo.conf"
sed -i "s/8072/${PORT8072}/g" "$DESTINATION/etc/odoo.conf"

# تعديل الشبكة والـ IPات في yml حتى لو فيه تعليقات
sed -i "s#\(name:\s*\).*odoo-net6#\1${NETWORK_NAME}#g" "$DESTINATION/docker-compose.yml"
sed -i "s#\(subnet:\s*\).*172\.28\.10\.0/29#\1${SUBNET}#g" "$DESTINATION/docker-compose.yml"
sed -i "s#\(gateway:\s*\).*172\.28\.10\.1#\1${GATEWAY}#g" "$DESTINATION/docker-compose.yml"
sed -i "s#\(ip_range:\s*\).*172\.28\.10\.0/29#\1${IP_RANGE}#g" "$DESTINATION/docker-compose.yml"
sed -i "s#\(ipv4_address:\s*\).*172\.28\.10\.2#\1${ODOO_IP}#g" "$DESTINATION/docker-compose.yml"
sed -i "s#\(ipv4_address:\s*\).*172\.28\.10\.3#\1${DB_IP}#g" "$DESTINATION/docker-compose.yml"

# تنزيل enterprise
if git ls-remote git@github.com:mahmoudhashemm/odoo17pro >/dev/null 2>&1; then
  git clone --depth 1 --branch main git@github.com:mahmoudhashemm/odoo17pro "$DESTINATION/enterprise"
else
  git clone --depth 1 --branch main https://github.com/mahmoudhashemm/odoo17pro "$DESTINATION/enterprise" || true
fi

# تشغيل Odoo
cd "$DESTINATION"
if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
  docker compose up -d
else
  docker-compose up -d
fi

echo "✅ Started Odoo @ http://localhost:${PORT}"
echo "🔑 Master Password: Omar@012 | 💬 Live chat: ${CHAT}"
echo "🌐 Network: ${NETWORK_NAME} | Subnet: ${SUBNET} | IP Range: ${IP_RANGE}"
echo "📦 Odoo IP: ${ODOO_IP} | DB IP: ${DB_IP}"
