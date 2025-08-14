#!/bin/bash
DESTINATION=$1
PORT=$2
CHAT=$3
PORT8069=$4
PORT8072=$5
SUBNET=$6
GATEWAY=$7
ODOO_IP=$8
DB_IP=$9

# clone Odoo directory
git clone --depth=1 https://github.com/mahmoudhashemm/Hello-odoo17.git $DESTINATION
rm -rf $DESTINATION/.git

# set permissions
mkdir -p $DESTINATION/postgresql
mkdir -p $DESTINATION/enterprise
chmod +x $DESTINATION/entrypoint.sh
sudo chmod -R 777 $DESTINATION

# config inotify
if ! grep -qF "fs.inotify.max_user_watches" /etc/sysctl.conf; then
    echo "fs.inotify.max_user_watches = 524288" | sudo tee -a /etc/sysctl.conf
    sudo sysctl -p
fi

# نسخ ملف yml
cp docker-compose.yml $DESTINATION/docker-compose.yml

# تعديل المنافذ
sed -i "s/10019/${PORT}/g" $DESTINATION/docker-compose.yml
sed -i "s/20014/${CHAT}/g" $DESTINATION/docker-compose.yml
sed -i "s/8069/${PORT8069}/g" $DESTINATION/etc/odoo.conf
sed -i "s/8072/${PORT8072}/g" $DESTINATION/etc/odoo.conf

# تعديل الشبكة والـ IPات
sed -i "s|172.28.10.0/29|${SUBNET}|g" $DESTINATION/docker-compose.yml
sed -i "s|172.28.10.1|${GATEWAY}|g" $DESTINATION/docker-compose.yml
sed -i "s|172.28.10.2|${ODOO_IP}|g" $DESTINATION/docker-compose.yml
sed -i "s|172.28.10.3|${DB_IP}|g" $DESTINATION/docker-compose.yml

# تحميل الـ enterprise
git clone --depth 1 --branch main git@github.com:mahmoudhashemm/odoo17pro "$DESTINATION/enterprise"

# تشغيل Odoo
docker-compose -f $DESTINATION/docker-compose.yml up -d

echo "Started Odoo @ http://localhost:${PORT} | Master Password: Omar@012 | Live chat port: ${CHAT}"
echo "Network: ${SUBNET}  Odoo IP: ${ODOO_IP}  DB IP: ${DB_IP}"
