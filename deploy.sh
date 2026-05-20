#!/bin/bash

# Перевірка на запуск від імені root
if [ "$EUID" -ne 0 ]; then
  echo "Будь ласка, запустіть скрипт з sudo"
  exit 1
fi

echo "1. Оновлення пакетів та встановлення залежностей..."
apt-get update
apt-get install -y postgresql postgresql-contrib nginx git python3 python3-venv python3-pip

echo "2. Створення бази даних та користувача БД..."
sudo -u postgres psql -c "CREATE DATABASE mywebapp_db;" || true
sudo -u postgres psql -c "CREATE USER app WITH ENCRYPTED PASSWORD '12345678';" || true
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE mywebapp_db TO app;"
sudo -u postgres psql -d mywebapp_db -c "GRANT ALL ON SCHEMA public TO app;"

echo "3. Налаштування системних користувачів..."
id -u app &>/dev/null || useradd -r -s /bin/false app

id -u student &>/dev/null || useradd -m -s /bin/bash student
echo "student:12345678" | chpasswd
usermod -aG sudo student

id -u teacher &>/dev/null || useradd -m -s /bin/bash teacher
echo "teacher:12345678" | chpasswd
usermod -aG sudo teacher
chage -d 0 teacher

id -u operator &>/dev/null || useradd -m -s /bin/bash -g operator operator || useradd -m -s /bin/bash operator
echo "operator:12345678" | chpasswd
chage -d 0 operator

cat << 'SUDOERS' > /etc/sudoers.d/operator
operator ALL=(ALL) NOPASSWD: /usr/bin/systemctl start mywebapp.service, /usr/bin/systemctl stop mywebapp.service, /usr/bin/systemctl restart mywebapp.service, /usr/bin/systemctl status mywebapp.service, /usr/bin/systemctl reload nginx
SUDOERS
chmod 0440 /etc/sudoers.d/operator

echo "4. Налаштування файлу gradebook..."
echo "17" > /home/student/gradebook
chown student:student /home/student/gradebook

echo "5. Розгортання коду застосунку..."
mkdir -p /etc/mywebapp
cp /home/$SUDO_USER/mywebapp/config.json /etc/mywebapp/config.json
cp -r /home/$SUDO_USER/mywebapp /opt/
chown -R app:app /opt/mywebapp

echo "6. Налаштування Systemd Сервісу..."
cat << 'UNIT' > /etc/systemd/system/mywebapp.service
[Unit]
Description=My Web App Simple Inventory
After=network.target postgresql.service

[Service]
User=app
Group=app
WorkingDirectory=/opt/mywebapp
Environment="PATH=/opt/mywebapp/venv/bin"
ExecStartPre=/opt/mywebapp/venv/bin/python migrate.py
ExecStart=/opt/mywebapp/venv/bin/python -m uvicorn main:app --host 127.0.0.1 --port 3000
Restart=always

[Install]
WantedBy=multi-user.target
UNIT

systemctl daemon-reload
systemctl enable mywebapp.service
systemctl restart mywebapp.service

echo "7. Налаштування Nginx..."
cat << 'NGINX' > /etc/nginx/sites-available/mywebapp
server {
    listen 80;
    server_name _;
    access_log /var/log/nginx/mywebapp_access.log;

    location = / { proxy_pass http://127.0.0.1:3000; }
    location /items { proxy_pass http://127.0.0.1:3000/items; }
    location /health { return 403; }
}
NGINX

ln -sf /etc/nginx/sites-available/mywebapp /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default
systemctl restart nginx

echo "8. Блокування дефолтного користувача ($SUDO_USER)..."
usermod -L $SUDO_USER || true

echo "Автоматичне розгортання успішно завершено!"
