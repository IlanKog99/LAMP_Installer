#!/bin/bash

# LAMP + WordPress Installation Script
# Database: MySQL (installed via lamp-server^ package)

# Collect inputs
read -p "Enter domain name: " DOMAIN
read -p "Enter MySQL database name for WordPress: " DB_NAME
read -p "Enter MySQL database user for WordPress: " DB_USER
read -p "Enter MySQL database password: " DB_PASSWORD

echo ""
echo "SSL Options:"
echo "1) Self-signed certificate"
echo "2) Let's Encrypt certificate"
echo "3) No encryption"
read -p "Choose SSL option (1-3): " SSL_CHOICE

if [ "$SSL_CHOICE" = "2" ]; then
    read -p "Enter email for Let's Encrypt: " EMAIL
fi

read -p "Replace default WordPress page with custom landing page? (y/n): " CUSTOM_PAGE
read -p "Remove this script after installation completes? (y/n): " REMOVE_SCRIPT

# Set up cleanup trap if removal requested
INSTALL_SUCCESS=0
if [ "$REMOVE_SCRIPT" = "y" ] || [ "$REMOVE_SCRIPT" = "Y" ]; then
    SCRIPT_PATH="$(cd "$(dirname "$0")" && pwd)/$(basename "$0")"
    cleanup() {
        if [ $INSTALL_SUCCESS -eq 1 ]; then
            echo ""
            echo "Removing installation script..."
            # Use sh to delete in a separate process that outlives this script
            sh -c "sleep 1; rm -f '$SCRIPT_PATH' && echo 'Script removed successfully.' || echo 'Warning: Could not remove script file.'" &
        fi
    }
    trap cleanup EXIT
fi

# Update packages
apt update

# Install LAMP stack
apt install -y lamp-server^

# Install PHP core and Apache module
apt install -y php libapache2-mod-php php-mysql

# Install PHP extensions
apt install -y php-cli php-curl php-gd php-mbstring php-xml php-xmlrpc php-soap php-intl php-zip

# Secure MySQL (automated)
mysql <<EOF
DELETE FROM mysql.user WHERE User='';
DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';
FLUSH PRIVILEGES;
EOF

# Firewall
ufw allow "Apache"

# Configure Apache dir.conf to prioritize index.php
sed -i 's/DirectoryIndex.*/DirectoryIndex index.php index.html index.cgi index.pl index.xhtml index.htm/' /etc/apache2/mods-enabled/dir.conf

# Create webroot
mkdir -p /var/www/$DOMAIN
chown -R $USER:$USER /var/www/$DOMAIN

# Create VirtualHost config
cat > /etc/apache2/sites-available/$DOMAIN.conf <<EOF
<VirtualHost *:80>
    ServerName $DOMAIN
    ServerAlias www.$DOMAIN
    ServerAdmin webmaster@localhost
    DocumentRoot /var/www/$DOMAIN
    ErrorLog \${APACHE_LOG_DIR}/error.log
    CustomLog \${APACHE_LOG_DIR}/access.log combined

    <Directory /var/www/$DOMAIN/>
        AllowOverride All
    </Directory>
</VirtualHost>
EOF

# Enable site and modules
a2ensite $DOMAIN
a2dissite 000-default
a2enmod rewrite

# Create database and user (MySQL)
mysql <<EOF
CREATE DATABASE $DB_NAME DEFAULT CHARACTER SET utf8 COLLATE utf8_unicode_ci;
CREATE USER '$DB_USER'@'localhost' IDENTIFIED WITH mysql_native_password BY '$DB_PASSWORD';
GRANT ALL ON $DB_NAME.* TO '$DB_USER'@'localhost';
FLUSH PRIVILEGES;
EXIT;
EOF

# Download and setup WordPress
cd /tmp
curl -O https://wordpress.org/latest.tar.gz
tar xzvf latest.tar.gz
touch /tmp/wordpress/.htaccess
cp /tmp/wordpress/wp-config-sample.php /tmp/wordpress/wp-config.php
mkdir -p /tmp/wordpress/wp-content/upgrade

cp -a /tmp/wordpress/. /var/www/$DOMAIN
chown -R www-data:www-data /var/www/$DOMAIN

# Set permissions
find /var/www/$DOMAIN/ -type d -exec chmod 750 {} \;
find /var/www/$DOMAIN/ -type f -exec chmod 640 {} \;

# Configure wp-config.php
SALTS=$(curl -s https://api.wordpress.org/secret-key/1.1/salt/)

# Replace salts (find line numbers and replace the range)
START_LINE=$(grep -n "define( 'AUTH_KEY'" /var/www/$DOMAIN/wp-config.php | cut -d: -f1)
END_LINE=$(grep -n "define( 'NONCE_SALT'" /var/www/$DOMAIN/wp-config.php | cut -d: -f1)
if [ -n "$START_LINE" ] && [ -n "$END_LINE" ]; then
    # Create temp file with salts
    SALTS_FILE=$(mktemp)
    echo "$SALTS" > "$SALTS_FILE"
    # Replace the range
    sed -i "${START_LINE},${END_LINE}d" /var/www/$DOMAIN/wp-config.php
    sed -i "$((START_LINE-1))r $SALTS_FILE" /var/www/$DOMAIN/wp-config.php
    rm -f "$SALTS_FILE"
fi

# Replace DB values
sed -i "s/define( 'DB_NAME', 'database_name_here' );/define( 'DB_NAME', '$DB_NAME' );/" /var/www/$DOMAIN/wp-config.php
sed -i "s/define( 'DB_USER', 'username_here' );/define( 'DB_USER', '$DB_USER' );/" /var/www/$DOMAIN/wp-config.php
sed -i "s/define( 'DB_PASSWORD', 'password_here' );/define( 'DB_PASSWORD', '$DB_PASSWORD' );/" /var/www/$DOMAIN/wp-config.php

# Add FS_METHOD
if ! grep -q "FS_METHOD" /var/www/$DOMAIN/wp-config.php; then
    sed -i "/\/\* Add any custom values between this line and the \"stop editing\" comment. \*\//a define('FS_METHOD', 'direct');" /var/www/$DOMAIN/wp-config.php
fi

# Create custom landing page if requested
if [ "$CUSTOM_PAGE" = "y" ] || [ "$CUSTOM_PAGE" = "Y" ]; then
    cat > /var/www/$DOMAIN/index.html <<EOF
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>LAMP Server Installed</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            display: flex;
            justify-content: center;
            align-items: center;
            height: 100vh;
            margin: 0;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
        }
        .container {
            text-align: center;
            padding: 2rem;
            background: rgba(255, 255, 255, 0.1);
            border-radius: 10px;
            backdrop-filter: blur(10px);
        }
        h1 { margin-top: 0; }
        a {
            color: #fff;
            text-decoration: underline;
        }
        a:hover { text-decoration: none; }
    </style>
</head>
<body>
    <div class="container">
        <h1>LAMP Server Successfully Installed!</h1>
        <p>This server was installed and configured using IlanKog99's script.</p>
        <p>Available at: <a href="https://github.com/IlanKog99/LAMP_Installer" target="_blank">IlanKog99/LAMP_Installer</a> on GitHub</p>
    </div>
</body>
</html>
EOF
    # Change DirectoryIndex to prioritize index.html
    sed -i 's/DirectoryIndex.*/DirectoryIndex index.html index.php index.cgi index.pl index.xhtml index.htm/' /etc/apache2/mods-enabled/dir.conf
    chown www-data:www-data /var/www/$DOMAIN/index.html
    chmod 640 /var/www/$DOMAIN/index.html
fi

# SSL setup
if [ "$SSL_CHOICE" = "1" ]; then
    # Self-signed certificate
    a2enmod ssl
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout /etc/ssl/private/apache-selfsigned.key \
        -out /etc/ssl/certs/apache-selfsigned.crt \
        -subj "/C=US/ST=State/L=City/O=Organization/CN=$DOMAIN"
    
    # Add HTTPS VirtualHost
    cat >> /etc/apache2/sites-available/$DOMAIN.conf <<EOF

<VirtualHost *:443>
   ServerName $DOMAIN
   DocumentRoot /var/www/$DOMAIN

   SSLEngine on
   SSLCertificateFile /etc/ssl/certs/apache-selfsigned.crt
   SSLCertificateKeyFile /etc/ssl/private/apache-selfsigned.key

   <Directory /var/www/$DOMAIN/>
       AllowOverride All
   </Directory>
</VirtualHost>
EOF

    # Add HTTP to HTTPS redirect
    sed -i "/ServerName $DOMAIN/a\    Redirect / https://$DOMAIN/" /etc/apache2/sites-available/$DOMAIN.conf
    
    ufw allow "Apache Full"
    
elif [ "$SSL_CHOICE" = "2" ]; then
    # Let's Encrypt
    a2enmod ssl
    apt update
    apt install -y certbot python3-certbot-apache
    certbot --apache -d $DOMAIN --non-interactive --agree-tos --email $EMAIL --redirect
    
    ufw allow "Apache Full"
fi

# Test config and restart Apache (single restart at end)
apache2ctl configtest
systemctl restart apache2

echo ""
echo "Installation complete!"
if [ "$SSL_CHOICE" != "3" ]; then
    echo "Visit: https://$DOMAIN"
else
    echo "Visit: http://$DOMAIN"
fi

# Mark installation as successful
INSTALL_SUCCESS=1

# Cleanup will be called automatically by EXIT trap if REMOVE_SCRIPT was set
# The trap fires when script exits (either normally or on error)


