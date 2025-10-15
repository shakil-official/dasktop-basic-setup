#!/bin/bash
# ============================================
# PHP Environment Manager with Nginx + PHP-FPM
# Supports PHP version listing, switching, installation
# Installs MySQL, PostgreSQL, and Adminer
# ============================================

set -e

GREEN="\033[0;32m"
YELLOW="\033[1;33m"
RED="\033[0;31m"
NC="\033[0m"

check_root() {
  if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Please run as root (use sudo).${NC}"
    exit 1
  fi
}

pause() {
  read -rp "Press Enter to continue..."
}

# ========================================
# List PHP versions
# ========================================
list_php_versions() {
  echo -e "${GREEN}Installed PHP versions:${NC}"
  update-alternatives --list php 2>/dev/null || echo "No multiple PHP versions found yet."
  php -v | head -n 1
}

# ========================================
# Switch PHP version
# ========================================
switch_php_version() {
  echo -e "${YELLOW}Available PHP versions to switch:${NC}"
  update-alternatives --list php || { echo "No alternatives found. Install PHP first."; return; }
  read -rp "Enter the full path of PHP version to use: " php_path
  update-alternatives --set php "$php_path"
  echo -e "${GREEN}Switched to: $(php -v | head -n 1)${NC}"
}

# ========================================
# Install PHP version and extensions
# ========================================
install_php_version() {
  read -rp "Enter PHP version to install (e.g. 7.4, 8.1, 8.2): " php_version
  add-apt-repository ppa:ondrej/php -y
  apt-get update -y

  apt-get install -y php${php_version}-fpm php${php_version}-cli php${php_version}-common php${php_version}-curl \
    php${php_version}-mbstring php${php_version}-xml php${php_version}-bcmath php${php_version}-zip \
    php${php_version}-pgsql php${php_version}-mysql

  update-alternatives --install /usr/bin/php php /usr/bin/php${php_version} ${php_version//./}
  systemctl enable php${php_version}-fpm
  systemctl start php${php_version}-fpm
  echo -e "${GREEN}PHP ${php_version} + FPM installed and started.${NC}"
}

# ========================================
# Install Nginx
# ========================================
install_nginx() {
  echo -e "${YELLOW}Installing Nginx...${NC}"
  apt-get install -y nginx
  systemctl enable nginx
  systemctl start nginx
  echo -e "${GREEN}Nginx installed and running.${NC}"
}

# ========================================
# Install MySQL
# ========================================
install_mysql() {
  echo -e "${YELLOW}Installing MySQL Server...${NC}"
  apt-get install -y mysql-server
  systemctl enable mysql
  systemctl start mysql
  echo -e "${GREEN}MySQL installed and running.${NC}"
}

# ========================================
# Install PostgreSQL
# ========================================
install_postgresql() {
  echo -e "${YELLOW}Installing PostgreSQL...${NC}"
  apt-get install -y postgresql postgresql-contrib
  systemctl enable postgresql
  systemctl start postgresql
  echo -e "${GREEN}PostgreSQL installed and running.${NC}"
}

# ========================================
# Install Adminer (Nginx)
# ========================================
install_adminer() {
  echo -e "${YELLOW}Installing Adminer...${NC}"
  read -rp "Enter port for Adminer (default 7070): " ADMINER_PORT
  ADMINER_PORT=${ADMINER_PORT:-7070}

  mkdir -p /var/www/adminer
  wget -q -O /var/www/adminer/index.php https://www.adminer.org/latest.php

  cat <<EOF > /etc/nginx/sites-available/adminer
server {
    listen ${ADMINER_PORT};
    server_name localhost;

    root /var/www/adminer;
    index index.php;

    location / {
        try_files \$uri \$uri/ =404;
    }

    location ~ \.php\$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/run/php/php$(php -r 'echo PHP_MAJOR_VERSION.".".PHP_MINOR_VERSION;')-fpm.sock;
    }
}
EOF

  ln -sf /etc/nginx/sites-available/adminer /etc/nginx/sites-enabled/adminer
  nginx -t && systemctl reload nginx
  echo -e "${GREEN}Adminer running at: http://localhost:${ADMINER_PORT}${NC}"
}

# ========================================
# Main Menu
# ========================================
main_menu() {
  clear
  echo -e "${GREEN}=== PHP Environment Manager (Nginx) ===${NC}"
  echo "1) List installed PHP versions"
  echo "2) Switch PHP version"
  echo "3) Install a new PHP version"
  echo "4) Install Nginx"
  echo "5) Install MySQL"
  echo "6) Install PostgreSQL"
  echo "7) Install Adminer (via Nginx)"
  echo "8) Install All (PHP + Nginx + MySQL + PostgreSQL + Adminer)"
  echo "0) Exit"
  echo ""

  read -rp "Choose an option: " choice
  case $choice in
    1) list_php_versions; pause ;;
    2) switch_php_version; pause ;;
    3) install_php_version; pause ;;
    4) install_nginx; pause ;;
    5) install_mysql; pause ;;
    6) install_postgresql; pause ;;
    7) install_adminer; pause ;;
    8) install_php_version; install_nginx; install_mysql; install_postgresql; install_adminer; pause ;;
    0) echo "Exiting..."; exit 0 ;;
    *) echo "Invalid option"; pause ;;
  esac
}

# ========================================
# Run Script
# ========================================
check_root
while true; do
  main_menu
done
