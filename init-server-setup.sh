#!/bin/bash

# Update and upgrade the system
sudo apt update && sudo apt upgrade -y

# Install necessary tools
sudo apt install -y software-properties-common curl git unzip ufw ncdu

# Add PHP PPA repository
sudo add-apt-repository ppa:ondrej/php -y
sudo apt update

# Install PHP versions and necessary extensions
PHP_VERSIONS=("7.2" "7.4" "8.2" "8.3")
PHP_EXTENSIONS=("mysql" "xml" "curl" "gd" "mbstring" "zip" "bcmath" "imagick")

for version in "${PHP_VERSIONS[@]}"; do
    sudo apt install -y php$version php$version-fpm
    for ext in "${PHP_EXTENSIONS[@]}"; do
        sudo apt install -y php$version-$ext
    done
done

# Install Nginx
sudo apt install -y nginx

# Install MariaDB
sudo apt install -y mariadb-server
sudo mysql_secure_installation

# Install Composer
curl -sS https://getcomposer.org/installer | php
sudo mv composer.phar /usr/local/bin/composer

# Install Node.js and npm (20.x LTS)
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt install -y nodejs

# Install Certbot for SSL
sudo apt install -y certbot python3-certbot-nginx

# Install phpMyAdmin
sudo apt install -y phpmyadmin

# Setup UFW
sudo ufw allow OpenSSH
sudo ufw allow 'Nginx Full'
sudo ufw --force enable

# Provide instructions for switching PHP versions
echo -e "\nPHP 7.2, 7.4, 8.2, and 8.3 installed. To switch between versions, use the following commands:\n"
for version in "${PHP_VERSIONS[@]}"; do
    echo -e "\nFor PHP $version:"
    echo "sudo update-alternatives --set php /usr/bin/php$version"
    echo "sudo update-alternatives --set phpize /usr/bin/phpize$version"
    echo "sudo update-alternatives --set php-config /usr/bin/php-config$version"
    echo "sudo systemctl restart php$version-fpm"
done

echo -e "\nInitial server setup complete. You can now add websites using the 'add-website.sh' script."
