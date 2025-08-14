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

# فحص البورتات على الهوست قبل ما نبدأ
for p in "$PORT" "$CHAT"; do
  if ss -ltn | awk '{print $4}' | grep -q ":${p}$"; then
    echo "ERROR: Port ${p} is already in use on host. اختر بورت مختلف."
    exit 1
  fi
done

# clone Odoo directory
git clone --depth=1 https://github.com/mahmoudhashemm/odoo-17-test.git "$DESTINATION"
rm -rf "$DESTINATION/.git"

# مجلدات وصلاحيات
mkdir -p "$DESTINATION/postgresql" "$DESTINATION/enterprise"
chmod +x "$DESTINATION/entrypoint.sh" 2>/dev/null || true
sudo chmod -R 777 "$DESTINATION"

# inotify
if ! grep -qF "fs.inotify.max_user_watches" /etc/sysctl.conf; then
  echo "fs.inotify.max_user_watches = 524288" | sudo tee -a /etc/sysctl.conf
  sudo sysctl -p
fi

# نسخ الـ yml الجاهز للتعديل
cp docker-compose.yml "$DESTINATION/docker-compose.yml"

# تعديل البورتات في yml
sed -i "s/10019/${PORT}/g"  "$DESTINATION/docker-compose.yml"
sed -i "s/20014/${CHAT}/g"  "$DESTINATION/docker-compose.yml"
sed -i "s/:8069\"/:${PORT8069}\"/g" "$DESTINATION/docker-compose.yml"
sed -i "s/:8072\"/:${PORT8072}\"/g" "$DESTINATION/docker-compose.yml"

# تعديل odoo.conf داخل الريبو
sed -i "s/8069/${PORT8069}/g" "$DESTINATION/etc/odoo.conf"
sed -i "s/8072/${PORT8072}/g" "$DESTINATION/etc/odoo.conf"

# تعديل الشبكة والـ IPات
sed -i "s/odoo-net6/${NETWORK_NAME}/g"      "$DESTINATION/docker-compose.yml"
sed -i "s#172.28.10.0/29#${SUBNET}#g"       "$DESTINATION/docker-compose.yml"
sed -i "s#172.28.10.1#${GATEWAY}#g"         "$DESTINATION/docker-compose.yml"
sed -i "s#172.28.10.0/29#${IP_RANGE}#g"     "$DESTINATION/docker-compose.yml"  # ip_range
sed -i "s/172.28.10.2/${ODOO_IP}/g"         "$DESTINATION/docker-compose.yml"
sed -i "s/172.28.10.3/${DB_IP}/g"           "$DESTINATION/docker-compose.yml"

# تنزيل enterprise (SSH لو متاح، وإلا HTTPS)
if git ls-remote git@github.com:mahmoudhashemm/odoo17pro >/dev/null 2>&1; then
  git clone --depth 1 --branch main git@github.com:mahmoudhashemm/odoo17pro "$DESTINATION/enterprise"
else
  git clone --depth 1 --branch main https://github.com/mahmoudhashemm/odoo17pro "$DESTINATION/enterprise" || true
fi

# تشغيل عبر docker compose (أو docker-compose لو قديم)
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
