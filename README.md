# EkromSSH UDP
## IP 239 Reference Installer

ระบบ VPN ครบวงจร — SSH, VMESS, VLESS, TROJAN, Shadowsocks

### ติดตั้ง

```bash
bash <(curl -s https://raw.githubusercontent.com/EkromSSH/UDP/main/one-click.sh)
```

### หรือทีละขั้นตอน

```bash
# main installer (จะถามโดเมน)
bash <(curl -s https://raw.githubusercontent.com/EkromSSH/UDP/main/main.sh)

# Web Admin (หรือกด menu 6 ใน SSH menu)
bash <(curl -s https://raw.githubusercontent.com/EkromSSH/UDP/main/install.sh)
```

### รายละเอียด

| Feature | Port |
|---------|------|
| SSH WS | 8080 |
| Web Admin | 8888 |
| OpenVPN | 1194 |
| Dropbear | 83, 169 |
| SSH | 22, 3369, 2269 |
| Nginx | 443 |
| Haproxy | 80 |

### Services
- nginx, xray, haproxy, websocket (ws)
- dropbear, openvpn, squid, fail2ban
- badvpn, slowdns

### ข้อมูลผู้ใช้
- Web Admin: http://IP:8888/
- Password: admin123

### อัปเดต Scripts
```bash
bash <(curl -s https://raw.githubusercontent.com/EkromSSH/UDP/main/update.sh)
```

© EkromSSH
