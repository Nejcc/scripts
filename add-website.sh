#!/bin/bash

# Prompt user for domain name
read -p "Enter your domain name (e.g., example.com): " DOMAIN

# Prompt user for PHP version
echo "Select PHP version:"
options=("7.2" "7.4" "8.2" "8.3")
select PHP_VERSION in "${options[@]}"; do
    case $PHP_VERSION in
        7.2|7.4|8.2|8.3)
            break
            ;;
        *)
            echo "Invalid option $REPLY. Please select a valid PHP version."
            ;;
    esac
done

# Create Laravel project directory
sudo mkdir -p /var/www/$DOMAIN
sudo chown -R $USER:$USER /var/www/$DOMAIN

# Setup Nginx for Laravel
sudo tee /etc/nginx/sites-available/$DOMAIN <<EOF
server {
    listen 80;
    server_name $DOMAIN;

    root /var/www/$DOMAIN/public;
    index index.php index.html index.htm;

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php$PHP_VERSION-fpm.sock;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        include fastcgi_params;
    }

    location ~ /\.ht {
        deny all;
    }
}
EOF

# Enable Laravel site and reload Nginx
sudo ln -s /etc/nginx/sites-available/$DOMAIN /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl reload nginx

# Obtain SSL certificate from Let's Encrypt
sudo certbot --nginx -d $DOMAIN

echo -e "\nWebsite setup complete for domain $DOMAIN with PHP $PHP_VERSION. Please configure your Laravel project in /var/www/$DOMAIN."
