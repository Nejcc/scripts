#!/bin/bash

# Update and upgrade the system
sudo apt update && sudo apt upgrade -y

# Install necessary tools
sudo apt install -y software-properties-common curl git unzip

# Add PHP PPA repository
sudo add-apt-repository ppa:ondrej/php -y
sudo apt update

# Install PHP 8.2 and PHP 8.3 along with necessary extensions
PHP_VERSIONS=("8.2" "8.3")

for version in "${PHP_VERSIONS[@]}"; do
    sudo apt install -y php$version php$version-fpm php$version-mysql php$version-xml php$version-curl php$version-gd php$version-mbstring php$version-zip php$version-bcmath
done

# Install Nginx
sudo apt install -y nginx

# Install MySQL
sudo apt install -y mysql-server
sudo mysql_secure_installation

# Install Composer
curl -sS https://getcomposer.org/installer | php
sudo mv composer.phar /usr/local/bin/composer

# Install Node.js and npm
curl -fsSL https://deb.nodesource.com/setup_16.x | sudo -E bash -
sudo apt install -y nodejs

# Setup Nginx for Laravel
sudo tee /etc/nginx/sites-available/laravel <<EOF
server {
    listen 80;
    server_name your_domain_or_ip;

    root /var/www/laravel/public;
    index index.php index.html index.htm;

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php8.3-fpm.sock; # Change this to php8.2-fpm.sock for PHP 8.2
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        include fastcgi_params;
    }

    location ~ /\.ht {
        deny all;
    }
}
EOF

# Enable Laravel site and disable default site
sudo ln -s /etc/nginx/sites-available/laravel /etc/nginx/sites-enabled/
sudo unlink /etc/nginx/sites-enabled/default

# Restart Nginx to apply changes
sudo systemctl restart nginx

# Provide instructions for switching PHP versions
echo -e "\nPHP 8.2 and PHP 8.3 installed. To switch between versions, use the following commands:\n"
echo "For PHP 8.3:"
echo "sudo update-alternatives --set php /usr/bin/php8.3"
echo "sudo update-alternatives --set phpize /usr/bin/phpize8.3"
echo "sudo update-alternatives --set php-config /usr/bin/php-config8.3"
echo "sudo systemctl restart php8.3-fpm"

echo -e "\nFor PHP 8.2:"
echo "sudo update-alternatives --set php /usr/bin/php8.2"
echo "sudo update-alternatives --set phpize /usr/bin/phpize8.2"
echo "sudo update-alternatives --set php-config /usr/bin/php-config8.2"
echo "sudo systemctl restart php8.2-fpm"

echo -e "\nSetup complete. Please configure your Laravel project in /var/www/laravel."
