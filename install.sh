#!/bin/bash
# ติดตั้ง Web Admin Panel
# ใช้หลังจาก main.sh เสร็จ

REPO="https://raw.githubusercontent.com/EkromSSH/UDP/main"
ADMIN_PASS="admin123"

# Install PHP
apt install -y php php-fpm php-mysqli php-gd php-xml php-mbstring php-curl php-zip 2>/dev/null

# Create admin directory
mkdir -p /var/www/admin

# Download admin panel
wget -q -O /var/www/admin/index.php "${REPO}/admin/index.php" 2>/dev/null

# Create nginx admin config
cat > /etc/nginx/conf.d/admin.conf << 'EOF'
server {
    listen 8888;
    root /var/www/admin;
    index index.php index.html;
    server_name _;

    location / {
        try_files $uri $uri/ /index.php?$args;
    }

    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php-fpm.sock;
    }
}
EOF

# Restart nginx
systemctl restart nginx 2>/dev/null

echo "✅ Web Admin: http://$(curl -s ipv4.icanhazip.com):8888/"
echo "   Password: $ADMIN_PASS"
