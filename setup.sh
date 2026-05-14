#!/bin/bash

clear

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${GREEN}"
echo "======================================"
echo "     Arturo Scriptas VPN sistema"
echo "======================================"
echo -e "${NC}"

if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}Paleisk kaip root!${NC}"
   exit 1
fi

echo -e "${YELLOW}Atnaujinami paketai...${NC}"
apt update -y
apt upgrade -y

echo -e "${YELLOW}Diegiami reikalingi paketai...${NC}"
apt install -y curl wget unzip sudo cron net-tools

echo -e "${YELLOW}Diegiamas Dropbear...${NC}"
apt install -y dropbear

echo -e "${YELLOW}Diegiamas Squid Proxy...${NC}"
apt install -y squid

echo -e "${YELLOW}Kuriami katalogai...${NC}"
mkdir -p /usr/local/arturo

echo -e "${YELLOW}Kuriama menu komanda...${NC}"

cat > /usr/local/bin/menu << 'EOF'
#!/bin/bash

clear

echo "======================================"
echo "      Arturo Scriptas VPN sistema"
echo "======================================"

echo ""
echo "1. Serverio informacija"
echo "2. Perkrauti servisus"
echo "3. Išeiti"
echo ""

read -p "Pasirinkimas: " opc

case $opc in
1)
    clear
    echo "Serverio IP:"
    curl -s ifconfig.me
    echo ""
    ;;
2)
    systemctl restart ssh
    systemctl restart dropbear
    systemctl restart squid
    echo "Servisai perkrauti!"
    ;;
3)
    exit
    ;;
*)
    echo "Neteisingas pasirinkimas!"
    ;;
esac
EOF

chmod +x /usr/local/bin/menu

echo -e "${GREEN}"
echo "======================================"
echo "Diegimas baigtas!"
echo "Komanda paleidimui: menu"
echo "======================================"
echo -e "${NC}"
