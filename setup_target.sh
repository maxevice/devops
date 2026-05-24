#!/bin/bash
echo "Налаштування Target Node..."
sudo apt update && sudo apt upgrade -y
sudo apt install -y nginx docker.io postgresql curl

echo "Запуск сервісів..."
sudo systemctl enable --now nginx
sudo systemctl enable --now docker
sudo systemctl enable --now postgresql

echo "Налаштування PostgreSQL..."
sudo -u postgres psql -c "CREATE USER app WITH PASSWORD '12345678';" || true
sudo -u postgres psql -c "CREATE DATABASE mywebapp_db OWNER app;" || true

echo "Налаштування Nginx..."
sudo bash -c 'cat > /etc/nginx/sites-available/default <<EOF
server {
    listen 80;
    server_name _;

    location / {
        proxy_pass http://127.0.0.1:3000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    }
}
EOF'

sudo systemctl restart nginx

sudo usermod -aG docker student

echo "✅ Середовище готове!"