#!/bin/bash
echo "Налаштування Target Node..."
sudo apt update && sudo apt upgrade -y
sudo apt install -y nginx docker.io postgresql

echo "Запуск сервісів..."
sudo systemctl enable --now nginx
sudo systemctl enable --now docker
sudo systemctl enable --now postgresql
echo "Середовище готове!"