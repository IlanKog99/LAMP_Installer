# LAMP + WordPress Installation Script

Automated bash script to install and configure a LAMP stack (Linux, Apache, MySQL, PHP) with WordPress and optional SSL encryption.

## Features

- **Three installation modes:**
  - **Mode 1: Full Install** - Complete LAMP + WordPress setup from scratch
  - **Mode 2: Landing Page Only** - Add custom landing page to existing WordPress installation
  - **Mode 3: Encryption Only** - Add SSL/HTTPS to existing WordPress installation
- Installs LAMP stack using Ubuntu's `lamp-server^` task package
- Sets up Apache VirtualHost for your domain
- Installs and configures WordPress
- Optional SSL encryption (self-signed or Let's Encrypt)
- Automated MySQL security hardening
- Optional custom landing page
- Optional script self-removal after completion
- Safe to run on existing installations (modes 2 & 3)

## Prerequisites

- Ubuntu/Debian-based Linux system
- Root access (script must be run as root)
- **Mode 1 (Full Install):**
  - Domain name (or use IP address)
  - For Let's Encrypt: Valid domain name with DNS pointing to server
- **Mode 2 (Landing Page Only):**
  - Existing WordPress installation
  - Apache VirtualHost configuration already set up
- **Mode 3 (Encryption Only):**
  - Existing WordPress installation
  - Apache VirtualHost configuration already set up
  - No existing SSL configuration
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

When you run the script, you'll first be prompted to choose an installation mode:

### Mode Selection

1. **Full Install (Mode 1)** - Complete LAMP + WordPress setup
2. **Landing Page Only (Mode 2)** - Add custom landing page to existing installation
3. **Encryption Only (Mode 3)** - Add SSL/HTTPS to existing installation

---

### Mode 1: Full Install

The script will prompt you for:

1. **Domain name** - Your domain (e.g., `example.com`) or IP address
2. **MySQL root password** - Password for MySQL root user
3. **MySQL database name** - Name for the WordPress database
4. **MySQL database user** - Username for WordPress database access
5. **MySQL database password** - Password for the database user
6. **SSL option**:
   - `1` - Self-signed certificate (for testing)
   - `2` - Let's Encrypt certificate (for production)
   - `3` - No encryption (HTTP only)
7. **Email address** - Required if choosing Let's Encrypt
8. **Custom landing page** - Replace default WordPress page with custom message (y/n)
9. **Remove script** - Delete script after successful installation (y/n)

### Mode 2: Landing Page Only

This mode assumes you already have a working WordPress installation. The script will:

1. **Auto-detect domain** from existing Apache VirtualHost configurations
   - If multiple sites are found, you'll be prompted to select one
2. **Verify** that the VirtualHost configuration exists
3. **Create** a custom landing page at `/var/www/your-domain/index.html`
4. **Update** DirectoryIndex to prioritize the landing page (WordPress admin remains accessible at `/wp-admin`)

**Note:** This mode preserves your existing WordPress installation and only adds the landing page.

### Mode 3: Encryption Only

This mode assumes you already have a working WordPress installation. The script will:

1. **Prompt** for your domain name
2. **Verify** that the VirtualHost configuration exists
3. **Check** if SSL is already configured (exits if found to avoid conflicts)
4. **Offer SSL options**:
   - `1` - Self-signed certificate (for testing)
   - `2` - Let's Encrypt certificate (for production)
5. **Configure HTTPS** by appending an HTTPS VirtualHost block to your existing config
6. **Add HTTP to HTTPS redirect** (modifies existing HTTP block safely)

**Note:** This mode preserves your existing WordPress installation and only adds SSL encryption. WordPress admin remains accessible at `/wp-admin`.

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

### Mode 1: Full Install

After installation completes:

1. Visit your domain:
   - With SSL: `https://your-domain.com`
   - Without SSL: `http://your-domain.com`

2. Complete WordPress setup:
   - Navigate to your domain
   - Follow WordPress installation wizard
   - Create admin account

3. If using custom landing page:
   - The custom page will be displayed at the root URL
   - WordPress admin is still accessible at `/wp-admin`

### Mode 2: Landing Page Only

After the landing page is created:

1. Visit your domain to see the custom landing page
2. WordPress admin remains accessible at `/wp-admin` (or `/wp-login.php`)
3. The landing page only affects the root URL (`/`), not WordPress paths

### Mode 3: Encryption Only

After SSL is configured:

1. Visit your domain using HTTPS: `https://your-domain.com`
2. HTTP will automatically redirect to HTTPS
3. WordPress admin is accessible at `https://your-domain.com/wp-admin`

## Notes

- The script assumes root execution (no `sudo` needed if running as root)
- **Mode 1:** MySQL root password is set using `mysql_native_password` authentication
- **Mode 1:** MySQL is automatically secured
- All apt commands run with `-y` flag (non-interactive)
- Apache is restarted once at the end of installation
- Script only removes itself on successful completion (not on errors)
- **Mode 2 & 3:** These modes are safe to run on existing installations and will not break WordPress functionality
- **Mode 2 & 3:** The script verifies that VirtualHost configurations exist before proceeding
- **Mode 3:** The script checks for existing SSL configuration and exits if found to avoid conflicts

## Troubleshooting

**Script doesn't remove itself:**
- Ensure you answered 'y' to the removal prompt
- Check file permissions
- Script only removes on successful completion

**WordPress installation errors (Mode 1):**
- Verify database credentials are correct
- Check file permissions: `/var/www/your-domain` should be owned by `www-data`
- Review Apache error logs: `/var/log/apache2/error.log`
- Ensure MySQL root password is set correctly

**Mode 2 errors:**
- **"No VirtualHost configurations found"**: Ensure Apache is installed and configured
- **"Could not detect domain"**: Check that your VirtualHost config has a `ServerName` directive
- **"VirtualHost configuration not found"**: Verify the domain matches your VirtualHost config filename

**Mode 3 errors:**
- **"VirtualHost configuration not found"**: Verify the domain matches your VirtualHost config filename
- **"HTTPS VirtualHost already exists"**: SSL is already configured for this domain
- **"Could not detect domain"**: Check that your VirtualHost config has a `ServerName` directive

**SSL certificate issues:**
- For Let's Encrypt: Ensure DNS points to your server
- For self-signed: Browser will show security warning (expected)
- If redirect doesn't work: Check that the HTTP VirtualHost block was modified correctly

**Apache config errors:**
- Run `apache2ctl configtest` to check configuration
- Review `/etc/apache2/sites-available/your-domain.conf`
- For Mode 3: Ensure the HTTPS VirtualHost block was appended correctly

**WordPress admin not accessible:**
- **Mode 2:** WordPress admin should still work at `/wp-admin` - the landing page only affects the root URL
- **Mode 3:** Ensure you're using HTTPS: `https://your-domain.com/wp-admin`
- Check file permissions: `/var/www/your-domain` should be owned by `www-data`
- Verify Apache Directory directives include `Require all granted`

## License

This script is provided as-is for personal use.

## Author

IlanKog99 - [GitHub](https://github.com/IlanKog99/LAMP_Installer)

