#!/bin/bash

# LAMP + WordPress Installation Script
# Database: MySQL (installed via lamp-server^ package)

# Mode selection
echo "Installation Mode:"
echo "1) Full Install (LAMP + WordPress + SSL + Landing Page)"
echo "2) Landing Page Only (add custom landing page to existing installation)"
echo "3) Encryption Only (add SSL/HTTPS to existing installation)"
read -p "Choose installation mode (1-3): " INSTALL_MODE

# Branch based on mode
if [ "$INSTALL_MODE" = "1" ]; then
    # Mode 1: Full Install
    # Collect inputs
    read -p "Enter domain name: " DOMAIN
read -p "Enter MySQL root password: " ROOT_PASSWORD
echo ""
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

# Ensure root can login with mysql_native_password
sudo mysql <<EOF
ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '$ROOT_PASSWORD';
FLUSH PRIVILEGES;
EOF

# Secure MySQL (remove anonymous users, test database, etc.)
sudo mysql -u root -p"$ROOT_PASSWORD" <<EOF
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
        Options Indexes FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>
</VirtualHost>
EOF

# Enable site and modules
a2ensite $DOMAIN
a2dissite 000-default
a2enmod rewrite

# Create database and user (MySQL)
sudo mysql -u root -p"$ROOT_PASSWORD" <<EOF
CREATE DATABASE $DB_NAME DEFAULT CHARACTER SET utf8 COLLATE utf8_unicode_ci;
CREATE USER '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASSWORD';
GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'localhost';
FLUSH PRIVILEGES;
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
# Ensure index.php is readable
chmod 640 /var/www/$DOMAIN/index.php

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
       Options Indexes FollowSymLinks
       AllowOverride All
       Require all granted
   </Directory>
</VirtualHost>
EOF

    # Add HTTP to HTTPS redirect (modify existing HTTP block only)
    sed -i "/<VirtualHost \*:80>/,/<\/VirtualHost>/{
        /ServerName $DOMAIN/ a\\
    Redirect / https://$DOMAIN/
    }" /etc/apache2/sites-available/$DOMAIN.conf
    
    ufw allow "Apache Full"
    
elif [ "$SSL_CHOICE" = "2" ]; then
    # Let's Encrypt
    a2enmod ssl
    apt update
    apt install -y certbot python3-certbot-apache
    certbot --apache -d $DOMAIN --non-interactive --agree-tos --email $EMAIL --redirect
    
    ufw allow "Apache Full"
fi

# Create custom landing page if requested (after WordPress and SSL setup)
if [ "$CUSTOM_PAGE" = "y" ] || [ "$CUSTOM_PAGE" = "Y" ]; then
    cat > /var/www/$DOMAIN/index.html <<EOF
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>$DOMAIN - LAMP Server Installed</title>
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

elif [ "$INSTALL_MODE" = "2" ]; then
    # Mode 2: Landing Page Only
    echo ""
    echo "Mode 2: Landing Page Only - Assuming you have a working WordPress installation"
    echo ""
    
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
    
    # Auto-detect domain from existing VirtualHost configs
    ENABLED_SITES=$(ls /etc/apache2/sites-enabled/*.conf 2>/dev/null | grep -v "000-default")
    if [ -z "$ENABLED_SITES" ]; then
        # Fallback to sites-available if no enabled sites
        AVAILABLE_SITES=$(ls /etc/apache2/sites-available/*.conf 2>/dev/null | grep -v "000-default")
        if [ -z "$AVAILABLE_SITES" ]; then
            echo "Error: No VirtualHost configurations found."
            echo "Please ensure you have a working WordPress installation with Apache configured."
            exit 1
        fi
        SITES_LIST=($AVAILABLE_SITES)
    else
        SITES_LIST=($ENABLED_SITES)
    fi
    
    # If multiple sites found, prompt user to select
    if [ ${#SITES_LIST[@]} -gt 1 ]; then
        echo "Multiple VirtualHost configurations found:"
        for i in "${!SITES_LIST[@]}"; do
            echo "$((i+1))) $(basename ${SITES_LIST[$i]})"
        done
        while true; do
            read -p "Select site (1-${#SITES_LIST[@]}): " SITE_CHOICE
            # Validate input is numeric and in range
            if [[ "$SITE_CHOICE" =~ ^[0-9]+$ ]] && [ "$SITE_CHOICE" -ge 1 ] && [ "$SITE_CHOICE" -le ${#SITES_LIST[@]} ]; then
                break
            else
                echo "Invalid selection. Please enter a number between 1 and ${#SITES_LIST[@]}."
            fi
        done
        SELECTED_SITE="${SITES_LIST[$((SITE_CHOICE-1))]}"
    else
        SELECTED_SITE="${SITES_LIST[0]}"
    fi
    
    # Extract domain from VirtualHost config
    DOMAIN=$(grep -i "ServerName" "$SELECTED_SITE" | head -1 | sed -E 's/.*ServerName[[:space:]]+([^[:space:]]+).*/\1/' | tr -d ' ')
    
    if [ -z "$DOMAIN" ]; then
        echo "Error: Could not detect domain from VirtualHost configuration."
        exit 1
    fi
    
    echo "Detected domain: $DOMAIN"
    
    # Verify VirtualHost config exists
    if [ ! -f "/etc/apache2/sites-available/$DOMAIN.conf" ] && [ ! -f "/etc/apache2/sites-enabled/$DOMAIN.conf" ]; then
        echo "Error: VirtualHost configuration for $DOMAIN not found."
        exit 1
    fi
    
    # Check if webroot directory exists, create if not
    if [ ! -d "/var/www/$DOMAIN" ]; then
        echo "Warning: Directory /var/www/$DOMAIN does not exist. Creating it..."
        mkdir -p /var/www/$DOMAIN
        chown www-data:www-data /var/www/$DOMAIN
        chmod 755 /var/www/$DOMAIN
    fi
    
    # Create custom landing page HTML
    cat > /var/www/$DOMAIN/index.html <<EOF
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>$DOMAIN - LAMP Server Installed</title>
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
    
    # Add DirectoryIndex directive to VirtualHost config (per-VirtualHost, not global)
    VHOST_CONFIG="/etc/apache2/sites-available/$DOMAIN.conf"
    if [ ! -f "$VHOST_CONFIG" ]; then
        VHOST_CONFIG="/etc/apache2/sites-enabled/$DOMAIN.conf"
    fi
    
    # Check if DirectoryIndex already exists in HTTP VirtualHost block only, if not add it
    if ! sed -n "/<VirtualHost \*:80>/,/<\/VirtualHost>/p" "$VHOST_CONFIG" | grep -q "DirectoryIndex"; then
        # Add DirectoryIndex after DocumentRoot in the HTTP VirtualHost block
        sed -i "/<VirtualHost \*:80>/,/<\/VirtualHost>/{
            /DocumentRoot/a\\
    DirectoryIndex index.html index.php index.cgi index.pl index.xhtml index.htm
        }" "$VHOST_CONFIG"
    else
        # Update existing DirectoryIndex in HTTP VirtualHost block only
        sed -i "/<VirtualHost \*:80>/,/<\/VirtualHost>/{
            s/^[[:space:]]*DirectoryIndex.*/    DirectoryIndex index.html index.php index.cgi index.pl index.xhtml index.htm/
        }" "$VHOST_CONFIG"
    fi
    
    # Set proper permissions
    chown www-data:www-data /var/www/$DOMAIN/index.html
    chmod 640 /var/www/$DOMAIN/index.html
    
    # Test config and restart Apache
    apache2ctl configtest
    systemctl restart apache2
    
    echo ""
    echo "Landing page created successfully!"
    echo "Visit: http://$DOMAIN (or https://$DOMAIN if SSL is configured)"
    echo "WordPress admin is still accessible at: http://$DOMAIN/wp-admin"
    
    # Mark installation as successful
    INSTALL_SUCCESS=1
    
    # Cleanup will be called automatically by EXIT trap if REMOVE_SCRIPT was set
    # The trap fires when script exits (either normally or on error)

elif [ "$INSTALL_MODE" = "3" ]; then
    # Mode 3: Encryption Only
    echo ""
    echo "Mode 3: Encryption Only - Assuming you have a working WordPress installation"
    echo ""
    
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
    
    # Collect inputs
    read -p "Enter domain name: " DOMAIN
    
    # Verify VirtualHost config exists and determine correct path
    VHOST_CONFIG="/etc/apache2/sites-available/$DOMAIN.conf"
    if [ ! -f "$VHOST_CONFIG" ]; then
        if [ -f "/etc/apache2/sites-enabled/$DOMAIN.conf" ]; then
            VHOST_CONFIG="/etc/apache2/sites-enabled/$DOMAIN.conf"
        else
            echo "Error: VirtualHost configuration for $DOMAIN not found."
            echo "Please ensure you have a working WordPress installation with Apache configured."
            exit 1
        fi
    fi
    
    # Check if HTTPS VirtualHost already exists
    if grep -q "<VirtualHost \*:443>" "$VHOST_CONFIG" 2>/dev/null; then
        echo "Error: HTTPS VirtualHost already exists for $DOMAIN."
        echo "SSL is already configured. Exiting to avoid conflicts."
        exit 1
    fi
    
    # SSL options
    echo ""
    echo "SSL Options:"
    echo "1) Self-signed certificate"
    echo "2) Let's Encrypt certificate"
    read -p "Choose SSL option (1-2): " SSL_CHOICE
    
    if [ "$SSL_CHOICE" = "2" ]; then
        read -p "Enter email for Let's Encrypt: " EMAIL
    fi
    
    # Enable SSL module
    a2enmod ssl
    
    if [ "$SSL_CHOICE" = "1" ]; then
        # Self-signed certificate
        openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
            -keyout /etc/ssl/private/apache-selfsigned.key \
            -out /etc/ssl/certs/apache-selfsigned.crt \
            -subj "/C=US/ST=State/L=City/O=Organization/CN=$DOMAIN"
        
        # Append HTTPS VirtualHost to existing config
        cat >> "$VHOST_CONFIG" <<EOF

<VirtualHost *:443>
   ServerName $DOMAIN
   DocumentRoot /var/www/$DOMAIN

   SSLEngine on
   SSLCertificateFile /etc/ssl/certs/apache-selfsigned.crt
   SSLCertificateKeyFile /etc/ssl/private/apache-selfsigned.key

   <Directory /var/www/$DOMAIN/>
       Options Indexes FollowSymLinks
       AllowOverride All
       Require all granted
   </Directory>
</VirtualHost>
EOF
        
        # Add HTTP to HTTPS redirect (modify existing HTTP block)
        # Insert redirect directive after ServerName in HTTP VirtualHost block
        sed -i "/<VirtualHost \*:80>/,/<\/VirtualHost>/{
            /ServerName $DOMAIN/ a\\
    Redirect / https://$DOMAIN/
        }" "$VHOST_CONFIG"
        
        ufw allow "Apache Full"
        
    elif [ "$SSL_CHOICE" = "2" ]; then
        # Let's Encrypt
        apt update
        apt install -y certbot python3-certbot-apache
        certbot --apache -d $DOMAIN --non-interactive --agree-tos --email $EMAIL --redirect
        
        ufw allow "Apache Full"
    else
        echo "Invalid SSL option selected."
        exit 1
    fi
    
    # Test config and restart Apache
    apache2ctl configtest
    systemctl restart apache2
    
    echo ""
    echo "SSL encryption configured successfully!"
    echo "Visit: https://$DOMAIN"
    echo "WordPress admin is still accessible at: https://$DOMAIN/wp-admin"
    
    # Mark installation as successful
    INSTALL_SUCCESS=1
    
    # Cleanup will be called automatically by EXIT trap if REMOVE_SCRIPT was set
    # The trap fires when script exits (either normally or on error)

else
    echo "Invalid installation mode selected."
    exit 1
fi


