#!/usr/bin/env bash
set -Eeuo pipefail

LOG_FILE="/var/log/remnanode/access.log"
INSTALL_DIR="/opt/remnanode"
COMPOSE_FILE="${INSTALL_DIR}/docker-compose.yml"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

info() { echo -e "${GREEN}[INFO]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
err()  { echo -e "${RED}[ERR]${NC} $*" >&2; }

if [ "${EUID}" -ne 0 ]; then
  err "Запусти от root: sudo bash install.sh"
  exit 1
fi

export DEBIAN_FRONTEND=noninteractive

info "Обновляю пакеты"
apt update

info "Устанавливаю базовые зависимости"
apt install -y ca-certificates curl gnupg git jq iptables iptables-persistent

if ! command -v docker >/dev/null 2>&1; then
  info "Устанавливаю Docker"
  curl -fsSL https://get.docker.com | sh
else
  info "Docker уже установлен"
fi

systemctl enable docker
systemctl restart docker

mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR"

info "Готовлю логи"
rm -f /var/log/remnanode || true
mkdir -p /var/log/remnanode
touch /var/log/remnanode/access.log /var/log/remnanode/error.log
chmod 777 /var/log/remnanode
chmod 666 /var/log/remnanode/access.log /var/log/remnanode/error.log

info "Создаю docker-compose.yml"
cat > "$COMPOSE_FILE" <<'EOF'
services:
  remnanode:
    container_name: remnanode
    hostname: remnanode
    image: remnawave/node:latest
    network_mode: host
    restart: always
    volumes:
      - "/var/log/remnanode:/var/log/remnanode"
    ulimits:
      nofile:
        soft: 1048576
        hard: 1048576
    environment:
      NODE_PORT: "2222"
      SECRET_KEY: 'eyJub2RlQ2VydFBlbSI6Ii0tLS0tQkVHSU4gQ0VSVElGSUNBVEUtLS0tLVxuTUlJQmhUQ0NBU3VnQXdJQkFnSUhBWGNoZ1VKaE1UQUtCZ2dxaGtqT1BRUURBakFtTVNRd0lnWURWUVFERXh0SFxuV0hkTFZHaEJNRFk0ZWtKUmNuaFJUVEZtVGkxTE1XaFlTM2t3SGhjTk1qWXdNakkzTURnek56QTJXaGNOTWprd1xuTWpJM01EZ3pOekEyV2pBeU1UQXdMZ1lEVlFRREV5ZDBURXRFZUZBMVJWZG1iVzVOTlhsV2FraE9ZV2hSYXpoQ1xuYm1ZMlFXWk1aRXByTWtvd1dVSXdXVEFUQmdjcWhrak9QUUlCQmdncWhrak9QUU1CQndOQ0FBUy9oYW1Pd0ZRV1xucHRvU2YzUTRPTGdUVzVaeDNIRmM5NXpwSzVXZXZrWHBiZlJ4VW54S21WR3ZTeTVrNEJmY3FCd0lxWUxGRytuTVxuQ3MyUWRVNHRVVHpOb3pnd05qQU1CZ05WSFJNQkFmOEVBakFBTUE0R0ExVWREd0VCL3dRRUF3SUZvREFXQmdOVlxuSFNVQkFmOEVEREFLQmdnckJnRUZCUWNEQVRBS0JnZ3Foa2pPUFFRREFnTklBREJGQWlFQThQcVNzaU1xWmZUc1xuc3B1NnNPR3Z1U2FZdHA3aWliZUFVenNYekNacXFJc0NJRGZTOS9tSFRWVGVnWExoTFIzZ2JReGJrRDdud0R1YlxuUEt6UHJlaHVzNDhyXG4tLS0tLUVORCBDRVJUSUZJQ0FURS0tLS0tIiwibm9kZUtleVBlbSI6Ii0tLS0tQkVHSU4gUFJJVkFURSBLRVktLS0tLVxuTUlHSEFnRUFNQk1HQnlxR1NNNDlBZ0VHQ0NxR1NNNDlBd0VIQkcwd2F3SUJBUVFnMmJUWlh3ZlBwVEFJYStuZFxuY0NMd2pmb1BGSFN6TnhjUlk3bFlhN1U1R0syaFJBTkNBQVMvaGFtT3dGUVdwdG9TZjNRNE9MZ1RXNVp4M0hGY1xuOTV6cEs1V2V2a1hwYmZSeFVueEttVkd2U3k1azRCZmNxQndJcVlMRkcrbk1DczJRZFU0dFVUek5cbi0tLS0tRU5EIFBSSVZBVEUgS0VZLS0tLS0iLCJjYUNlcnRQZW0iOiItLS0tLUJFR0lOIENFUlRJRklDQVRFLS0tLS1cbk1JSUJYekNDQVFTZ0F3SUJBZ0lCQVRBS0JnZ3Foa2pPUFFRREFqQW1NU1F3SWdZRFZRUURFeHRIV0hkTFZHaEJcbk1EWTRla0pSY25oUlRURm1UaTFMTVdoWVMza3dIaGNOTWpZd01qRTRNVEF3TXpBMldoY05Nell3TWpFNE1UQXdcbk16QTJXakFtTVNRd0lnWURWUVFERXh0SFdIZExWR2hCTURZNGVrSlJjbmhSVFRGbVRpMUxNV2hZUzNrd1dUQVRcbkJnY3Foa2pPUFFJQkJnZ3Foa2pPUFFNQkJ3TkNBQVJCY2xvbitnSEtHOC9xUDFtRU9MZzAvRzJydzlMckJCK2NcblAxNW40d0t0UG1xUHM4QlJ5eHN3aUVzUmVxM1pGZDB5YU9HMzBxa3dIM3ZQTGdudGtST0NveU13SVRBUEJnTlZcbkhSTUJBZjhFQlRBREFRSC9NQTRHQTFVZER3RUIvd1FFQXdJQ2hEQUtCZ2dxaGtqT1BRUURBZ05KQURCR0FpRUFcbnBNS0Y1Rnh1NVhCY3F6anFCUTg4V1RVdWFCczBGMkF3bVhuaFBveWtTNVVDSVFEaXBLcFZqMTJmanlPRDRSaEpcbndleFQxZlVNdTVkaHdYUjA5c3phQzkydUZ3PT1cbi0tLS0tRU5EIENFUlRJRklDQVRFLS0tLS0iLCJqd3RQdWJsaWNLZXkiOiItLS0tLUJFR0lOIFBVQkxJQyBLRVktLS0tLVxuTUlJQklqQU5CZ2txaGtpRzl3MEJBUUVGQUFPQ0FROEFNSUlCQ2dLQ0FRRUFwaWZ5RktKODdoWllMUjBUL2hncFxuS29WWDNQVG81eHhGMWU3S0pCcE1tQUpyQ0J6QUpGWXFzS0RTeGtvMlBhOHlpa25Udm9IcEJBemhTOUZOU0RadFxuL0x4MmF5OUVYL1VWVGFMTExKOXZ6SnVRVEJPRzFva3dkdit1TEVrTG9zNHBTdXl3bFl6N0RQOEhkcW5wN25oM1xuekQrRzVHU1JBTlduUmNYc0NvVGdwcmxxdHVVM2h6amhTLy9rdEEzTEFGMzEvRCtZSWFUalY4SUNoWFo2d1h1R1xuMHhuVVNFcUNpd09xRFMyQUdaNzk4R1dUMjJRTU9KMTJEa1VIMHp6TlFDd1piMy92TW1GQUs2emdRdU9nWi9YMVxuZUM0MEN6NmRXMGFyQzZPbDZRK1MwQjl6TXBRV3FBSUxVM2syallUNS9EUW5GeEJjMlBVeGpLbDNIMk95TU5rMVxuUFFJREFRQUJcbi0tLS0tRU5EIFBVQkxJQyBLRVktLS0tLVxuIn0='
EOF

info "Запускаю remnanode"
docker compose -f "$COMPOSE_FILE" up -d

info "Ставлю blocker"
touch "$LOG_FILE"
printf '%s\n%s\n' "$LOG_FILE" "1" | bash <(curl -fsSL git.new/install) || true

# info "Пишу sysctl anti-ddos"
# cat >/etc/sysctl.d/99-ddos.conf <<'EOF'
# net.ipv4.tcp_syncookies=1
# net.ipv4.tcp_max_syn_backlog=8192
# net.core.somaxconn=4096
# net.ipv4.tcp_synack_retries=3
# net.ipv4.tcp_fin_timeout=15
# EOF

# sysctl --system

# info "Применяю iptables защиту"

# iptables -C INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT 2>/dev/null || \
# iptables -I INPUT 1 -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# iptables -C INPUT -m conntrack --ctstate INVALID -j DROP 2>/dev/null || \
# iptables -I INPUT 2 -m conntrack --ctstate INVALID -j DROP

# iptables -C INPUT -p tcp --syn --dport 443 -m connlimit --connlimit-above 80 --connlimit-mask 32 -j DROP 2>/dev/null || \
# iptables -I INPUT 3 -p tcp --syn --dport 443 -m connlimit --connlimit-above 80 --connlimit-mask 32 -j DROP

# iptables -C INPUT -p tcp --syn --dport 443 -m hashlimit \
#   --hashlimit-name remna443 \
#   --hashlimit-mode srcip \
#   --hashlimit-upto 120/minute \
#   --hashlimit-burst 80 \
#   -j ACCEPT 2>/dev/null || \
# iptables -I INPUT 4 -p tcp --syn --dport 443 -m hashlimit \
#   --hashlimit-name remna443 \
#   --hashlimit-mode srcip \
#   --hashlimit-upto 120/minute \
#   --hashlimit-burst 80 \
#   -j ACCEPT

# iptables -C INPUT -p tcp --syn --dport 443 -j DROP 2>/dev/null || \
# iptables -I INPUT 5 -p tcp --syn --dport 443 -j DROP

# info "Сохраняю правила"
# netfilter-persistent save

# echo
# info "Готово"
# echo "Проверка:"
# echo "docker ps"
# echo "docker compose -f $COMPOSE_FILE ps"
# echo "docker compose -f $COMPOSE_FILE logs --tail=100"
# echo "iptables -L INPUT -n --line-numbers"