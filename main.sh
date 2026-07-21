#!/bin/bash
# =============================================
# EkromSSH UDP - IP 239 Reference Installer
# =============================================
# รองรับ: Ubuntu 20.04+ / Debian 10+
# =============================================

PURPLE='\033[1;35m'
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

IP=$(curl -s ipv4.icanhazip.com)
REPO="https://raw.githubusercontent.com/EkromSSH/UDP/main"
TANGGAL=$(date '+%Y-%m-%d')

# Root check
[[ $EUID -ne 0 ]] && { echo -e "${RED}❌ รันด้วย root เท่านั้น${NC}"; exit 1; }

clear
echo -e "${PURPLE}"
echo ""
echo "  ╔══════════════════════════════════════╗"
echo "  ║         EKROM SSH UDP               ║"
echo "  ║      IP 239 Reference Installer     ║"
echo "  ╚══════════════════════════════════════╝"
echo ""

# ============================================
# ฟังก์ชัน
# ============================================
print_ok() { echo -e "  ${GREEN}[✓]${NC} $1"; }
print_info() { echo -e "  ${YELLOW}[i]${NC} $1"; }
print_error() { echo -e "  ${RED}[✗]${NC} $1"; }

# ============================================
# 1. ติดตั้ง Packages พื้นฐาน
# ============================================
install_packages() {
    print_info "กำลังติดตั้งแพ็กเกจ..."
    
    apt update -y
    apt upgrade -y
    apt install -y wget curl screen git unzip zip 7zip python3 python3-pip \\
        nginx haproxy apache2-utils squid dropbear fail2ban \\
        openssl net-tools iptables-persistent netfilter-persistent \\
        cron socat cmake make gcc build-essential libssl-dev \\
        lsof dnsutils bc jq
    apt autoremove -y
    
    print_ok "แพ็กเกจพื้นฐานพร้อม"
}

# ============================================
# 2. ตั้งค่าเวลามาเลเซีย
# ============================================
setup_timezone() {
    timedatectl set-timezone Asia/Kuala_Lumpur
    print_ok "เขตเวลา: Asia/Kuala_Lumpur"
}

# ============================================
# 3. ขอโดเมน
# ============================================
setup_domain() {
    if [[ -f /root/domain && -n "$(cat /root/domain 2>/dev/null)" ]]; then
        print_ok "โดเมนปัจจุบัน: $(cat /root/domain)"
    else
        echo ""
        read -p "  ➜ ใส่โดเมน (เช่น app.idavpn.win): " SUB_DOMAIN
        [[ -z "$SUB_DOMAIN" ]] && { print_error "ไม่ได้ใส่โดเมน"; exit 1; }
        echo "$SUB_DOMAIN" > /root/domain
        print_ok "โดเมน: $SUB_DOMAIN"
    fi
    cp /root/domain /etc/xray/domain 2>/dev/null
}

# ============================================
# 4. สร้าง SSL
# ============================================
setup_ssl() {
    print_info "สร้าง SSL ..."
    domain=$(cat /root/domain)
    mkdir -p /etc/xray
    
    openssl req -x509 -nodes -days 3650 -newkey rsa:2048 \
        -keyout /etc/xray/xray.key \
        -out /etc/xray/xray.crt \
        -subj "/CN=${domain}" 2>/dev/null
    
    chmod 644 /etc/xray/xray.crt /etc/xray/xray.key
    cat /etc/xray/xray.crt /etc/xray/xray.key > /etc/haproxy/xray.pem
    chmod 644 /etc/haproxy/xray.pem
    
    print_ok "SSL สร้างเรียบร้อย (10 ปี)"
}

# ============================================
# 5. ตั้งค่า Services
# ============================================
setup_services() {
    # --- SSH ---
    print_info "ตั้งค่า SSH ..."
    sed -i 's/#PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
    sed -i 's/PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
    echo "Port 22" >> /etc/ssh/sshd_config
    echo "Port 3369" >> /etc/ssh/sshd_config
    echo "Port 2269" >> /etc/ssh/sshd_config
    
    # --- Dropbear ---
    print_info "ตั้งค่า Dropbear ..."
    apt install -y dropbear 2>/dev/null
    cat > /etc/default/dropbear << 'EOF'
NO_START=0
DROPBEAR_PORT=83
DROPBEAR_EXTRA_ARGS="-p 169"
DROPBEAR_BANNER="/etc/banner"
EOF
    
    # --- Nginx ---
    print_info "ตั้งค่า Nginx ..."
    mkdir -p /etc/nginx/conf.d
    wget -q -O /etc/nginx/conf.d/xray.conf "${REPO}/config/xray.conf" 2>/dev/null
    wget -q -O /etc/nginx/nginx.conf "${REPO}/config/nginx.conf" 2>/dev/null
    
    # --- Haproxy ---
    print_info "ตั้งค่า Haproxy ..."
    wget -q -O /etc/haproxy/haproxy.cfg "${REPO}/admin/haproxy.cfg" 2>/dev/null
    mkdir -p /etc/haproxy/errors
    for code in 400 403 404 405 408 410 411 413 414 417 429 500 501 502 503 504; do
        case $code in
            400) msg="Bad Request" ;; 403) msg="Forbidden" ;;
            404) msg="Not Found" ;; 405) msg="Method Not Allowed" ;;
            408) msg="Request Timeout" ;; 410) msg="Gone" ;;
            411) msg="Length Required" ;; 413) msg="Payload Too Large" ;;
            414) msg="URI Too Long" ;; 417) msg="Expectation Failed" ;;
            429) msg="Too Many Requests" ;; 500) msg="Internal Server Error" ;;
            501) msg="Not Implemented" ;; 502) msg="Bad Gateway" ;;
            503) msg="Service Unavailable" ;; 504) msg="Gateway Timeout" ;;
        esac
        printf "HTTP/1.0 %d %s\r\n" $code "$msg" > /etc/haproxy/errors/${code}.http
        printf "Cache-Control: no-cache\r\n" >> /etc/haproxy/errors/${code}.http
        printf "Connection: close\r\n" >> /etc/haproxy/errors/${code}.http
        printf "Content-Type: text/html\r\n" >> /etc/haproxy/errors/${code}.http
        printf "\r\n" >> /etc/haproxy/errors/${code}.http
        printf "<html><body><h1>%d %s</h1></body></html>\n" $code "$msg" >> /etc/haproxy/errors/${code}.http
    done
    
    # --- Xray ---
    print_info "ตั้งค่า Xray ..."
    curl -s ipinfo.io/city >> /etc/xray/city 2>/dev/null
    curl -s ipinfo.io/org | cut -d " " -f 2-10 >> /etc/xray/isp 2>/dev/null
    wget -q -O /tmp/xray.zip "https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-64.zip"
    unzip -o -q /tmp/xray.zip -d /tmp/xray_extract 2>/dev/null
    cp /tmp/xray_extract/xray /usr/sbin/xray
    chmod +x /usr/sbin/xray
    rm -rf /tmp/xray.zip /tmp/xray_extract
    wget -q -O /etc/xray/config.json "${REPO}/config/xray-config.json" 2>/dev/null
    
    # --- Xray Systemd ---
    cat > /etc/systemd/system/xray.service << 'EOF'
[Unit]
Description=Xray Service
After=network.target nss-lookup.target

[Service]
User=www-data
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
NoNewPrivileges=true
ExecStart=/usr/sbin/xray run -config /etc/xray/config.json
Restart=on-failure
RestartPreventExitStatus=23
LimitNPROC=10000
LimitNOFILE=1000000

[Install]
WantedBy=multi-user.target
EOF
    
    # --- WebSocket (ws.service) ---
    print_info "ตั้งค่า WebSocket ..."
    wget -q -O /usr/sbin/websocket "${REPO}/config/ws-binary" 2>/dev/null || true
    if [ ! -f /usr/sbin/websocket ]; then
        # Fallback: compile from source or use ws-python
        wget -q -O /usr/local/bin/ws-ssh.py "${REPO}/admin/ws-ssh.py"
        chmod +x /usr/local/bin/ws-ssh.py
        cat > /etc/systemd/system/ws-ssh.service << 'EOF'
[Unit]
Description=SSH WebSocket Handler
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/python3 /usr/local/bin/ws-ssh.py
Restart=always
RestartSec=3
LimitNOFILE=100000
LimitNPROC=10000

[Install]
WantedBy=multi-user.target
EOF
    fi
    wget -q -O /etc/websocket/tun.conf "${REPO}/admin/tun.conf" 2>/dev/null
    
    # --- OpenVPN ---
    print_info "ตั้งค่า OpenVPN ..."
    wget -q -O /tmp/openvpn.sh "${REPO}/config/openvpn-setup.sh" 2>/dev/null || source <(curl -sL https://raw.githubusercontent.com/NevermoreSSH/Vergil/main/openvpn/openvpn) 2>/dev/null
    
    # --- BadVPN ---
    print_info "ตั้งค่า BadVPN ..."
    wget -q -O /usr/sbin/badvpn "${REPO}/config/badvpn" 2>/dev/null || true
    chmod +x /usr/sbin/badvpn 2>/dev/null
    
    # --- Squid ---
    print_info "ตั้งค่า Squid ..."
    cat > /etc/squid/squid.conf << 'EOF'
http_port 3128
acl localhost src 127.0.0.1/32
acl all src all
http_access allow all
visible_hostname EkromSSH
EOF
    
    # --- Banner ---
    echo "EKROM SSH VPN" > /etc/banner
    echo "พัฒนาโดย EkromSSH" >> /etc/banner
    
    print_ok "บริการทั้งหมดพร้อม"
}

# ============================================
# 6. ดาวน์โหลด Scripts
# ============================================
download_scripts() {
    print_info "ดาวน์โหลด Scripts ..."
    mkdir -p /usr/local/bin
    
    for f in menu ssh add-ssh del-ssh renew-ssh cek-ssh change-port; do
        wget -q -O /usr/sbin/$f "${REPO}/admin/$f" 2>/dev/null
        chmod +x /usr/sbin/$f 2>/dev/null
        print_ok "$f"
    done
    
    wget -q -O /usr/local/bin/ssh-admin "${REPO}/admin/ssh-admin" 2>/dev/null
    chmod +x /usr/local/bin/ssh-admin 2>/dev/null
    print_ok "ssh-admin"
    
    print_ok "Scripts พร้อม"
}

# ============================================
# 7. ตั้งค่า Auto-Reboot
# ============================================
setup_cron() {
    cat > /etc/cron.d/xp_all << 'EOF'
SHELL=/bin/sh
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
2 0 * * * root /usr/bin/xp
EOF
    cat > /etc/cron.d/daily_reboot << 'EOF'
SHELL=/bin/sh
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
0 5 * * * root /sbin/reboot
EOF
    echo "*/1 * * * * root echo -n > /var/log/nginx/access.log" > /etc/cron.d/log.nginx
    echo "*/1 * * * * root echo -n > /var/log/xray/access.log" >> /etc/cron.d/log.xray
    service cron restart 2>/dev/null
    print_ok "Cron jobs พร้อม"
}

# ============================================
# 8. รีสตาร์ทบริการทั้งหมด
# ============================================
restart_services() {
    print_info "รีสตาร์ทบริการ ..."
    systemctl daemon-reload
    
    for svc in ssh dropbear nginx xray haproxy ws-ssh ws squid fail2ban cron; do
        systemctl enable $svc 2>/dev/null
        systemctl restart $svc 2>/dev/null
        sleep 0.5
    done
    
    print_ok "บริการทั้งหมดกำลังทำงาน"
}

# ============================================
# 9. profile / menu อัตโนมัติ
# ============================================
setup_profile() {
    cat > /root/.profile << 'EOF'
if [ "$BASH" ]; then
    if [ -f ~/.bashrc ]; then
        . ~/.bashrc
    fi
fi
mesg n || true
menu
EOF
    chmod 644 /root/.profile
}

# ============================================
# MAIN
# ============================================
install_packages
setup_timezone
setup_domain
setup_ssl
setup_services
download_scripts
setup_cron
setup_profile
restart_services

echo ""
echo -e "${PURPLE}"
echo "  ╔══════════════════════════════════════╗"
echo "  ║       ติดตั้งเสร็จสมบูรณ์!            ║"
echo "  ╚══════════════════════════════════════╝"
echo -e "${NC}"
echo "  IP: $IP"
echo "  Domain: $(cat /root/domain 2>/dev/null)"
echo "  Web Admin: http://$IP:8888/"
echo "  User: admin123"
echo ""

rm -f ~/.bash_history
sleep 5
reboot
