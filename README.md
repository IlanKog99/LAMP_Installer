# LAMP + WordPress Installation Script

Automated bash script to install and configure a LAMP stack (Linux, Apache, MySQL, PHP) with WordPress and optional SSL encryption.

## Features

- Installs LAMP stack using Ubuntu's `lamp-server^` task package
- Sets up Apache VirtualHost for your domain
- Installs and configures WordPress
- Optional SSL encryption (self-signed or Let's Encrypt)
- Automated MySQL security hardening
- Optional custom landing page
- Optional script self-removal after completion

## Prerequisites

- Ubuntu/Debian-based Linux system
- Root access (script must be run as root)
- Domain name (or use IP address)
- For Let's Encrypt: Valid domain name with DNS pointing to server

## Installation

**Quick one-liner (download and run):**
```bash
wget -O install_lamp.sh https://raw.githubusercontent.com/IlanKog99/LAMP_Installer/main/install_lamp.sh && chmod +x install_lamp.sh && sudo ./install_lamp.sh
```

**Or step by step:**

1. Download the script:
```bash
wget https://raw.githubusercontent.com/IlanKog99/LAMP_Installer/main/install_lamp.sh
```

Or clone the repository:
```bash
git clone https://github.com/IlanKog99/LAMP_Installer.git
cd LAMP_Installer
```

2. Make the script executable:
```bash
chmod +x install_lamp.sh
```

3. Run the script as root:
```bash
sudo ./install_lamp.sh
```

## Usage

The script will prompt you for:

1. **Domain name** - Your domain (e.g., `example.com`) or IP address
2. **MySQL database name** - Name for the WordPress database
3. **MySQL database user** - Username for WordPress database access
4. **MySQL database password** - Password for the database user
5. **SSL option**:
   - `1` - Self-signed certificate (for testing)
   - `2` - Let's Encrypt certificate (for production)
   - `3` - No encryption (HTTP only)
6. **Email address** - Required if choosing Let's Encrypt
7. **Custom landing page** - Replace default WordPress page with custom message (y/n)
8. **Remove script** - Delete script after successful installation (y/n)

## What Gets Installed

- **Apache** web server
- **MySQL** database server
- **PHP** and required extensions:
  - php-cli, php-curl, php-gd, php-mbstring
  - php-xml, php-xmlrpc, php-soap, php-intl, php-zip
- **WordPress** (latest version)
- **SSL certificates** (if selected)

## Configuration

The script automatically:
- Creates Apache VirtualHost configuration
- Sets up MySQL database and user
- Configures WordPress `wp-config.php`
- Sets proper file permissions
- Configures firewall rules
- Sets up HTTP to HTTPS redirect (if SSL enabled)

## Post-Installation

After installation completes:

1. Visit your domain:
   - With SSL: `https://your-domain.com`
   - Without SSL: `http://your-domain.com`

2. Complete WordPress setup:
   - Navigate to your domain
   - Follow WordPress installation wizard
   - Create admin account

3. If using custom landing page:
   - The custom page will be displayed instead of WordPress
   - To access WordPress, you may need to remove or rename `index.html`

## Notes

- The script assumes root execution (no `sudo` needed if running as root)
- MySQL is automatically secured (anonymous users removed, test database dropped)
- All apt commands run with `-y` flag (non-interactive)
- Apache is restarted once at the end of installation
- Script only removes itself on successful completion (not on errors)

## Troubleshooting

**Script doesn't remove itself:**
- Ensure you answered 'y' to the removal prompt
- Check file permissions
- Script only removes on successful completion

**WordPress installation errors:**
- Verify database credentials are correct
- Check file permissions: `/var/www/your-domain` should be owned by `www-data`
- Review Apache error logs: `/var/log/apache2/error.log`

**SSL certificate issues:**
- For Let's Encrypt: Ensure DNS points to your server
- For self-signed: Browser will show security warning (expected)

**Apache config errors:**
- Run `apache2ctl configtest` to check configuration
- Review `/etc/apache2/sites-available/your-domain.conf`

## License

This script is provided as-is for personal use.

## Author

IlanKog99 - [GitHub](https://github.com/IlanKog99/LAMP_Installer)

