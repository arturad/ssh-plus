#!/bin/bash

clear

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}Paleisk kaip root!${NC}"
    exit 1
fi

echo -e "${GREEN}=== Arturo Scriptas VPN sistema ===${NC}"

apt update -y
apt install -y curl wget sudo cron net-tools lsb-release dropbear squid

mkdir -p /etc/arturo
touch /etc/arturo/limitai.db

cat > /usr/local/bin/menu << 'EOF'
#!/bin/bash

clear

OS=$(lsb_release -ds | tr -d '"')
RAM_TOTAL=$(free -h | awk '/Mem:/ {print $2}')
RAM_USED=$(free | awk '/Mem:/ {printf("%.1f"), $3/$2 * 100}')
CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}')
TIME=$(date +"%H:%M:%S")
SSH_PORT=$(grep -E "^Port " /etc/ssh/sshd_config | head -1 | awk '{print $2}')
[ -z "$SSH_PORT" ] && SSH_PORT="22"

echo -e "\033[1;34m====================================================\033[0m"
echo -e "\033[1;37;41m   SSHPLUS MANAGER ⇌   by @Rolka ✩ @Arturas   \033[0m"
echo -e "\033[1;34m====================================================\033[0m"

echo ""
echo -e "\033[1;32mSISTEMA\033[0m"
echo "OS: $OS"
echo "Laikas: $TIME"

echo ""
echo -e "\033[1;32mATMINTIS RAM\033[0m"
echo "Iš viso: $RAM_TOTAL"
echo "Naudoja: ${RAM_USED}%"

echo ""
echo -e "\033[1;32mPROCESORIUS\033[0m"
echo "Naudoja: ${CPU_USAGE}%"

echo ""
echo -e "\033[1;34m====================================================\033[0m"
echo "sshd: $SSH_PORT"
echo "dropbear: 443"
echo "squid: 3128"
echo "badvpn-udpgw: 7300"
echo -e "\033[1;34m====================================================\033[0m"

echo -e "\033[1;36m[01]\033[0m • SUKURTI VARTOTOJĄ"
echo -e "\033[1;36m[02]\033[0m • PAŠALINTI VARTOTOJĄ"
echo -e "\033[1;36m[03]\033[0m • PRISIJUNGĘ VARTOTOJAI"
echo -e "\033[1;36m[04]\033[0m • SERVERIO INFORMACIJA"
echo -e "\033[1;36m[05]\033[0m • PERKRAUTI SERVISUS"
echo -e "\033[1;36m[06]\033[0m • SPEEDTEST"
echo -e "\033[1;31m[00]\033[0m • IŠEITI"

echo ""
read -p "KĄ NORITE DARYTI ?? : " opc

case "$opc" in

1|01)
clear
read -p "Vartotojas: " user
read -p "Slaptažodis: " pass
read -p "Dienų skaičius: " days
read -p "Prisijungimų limitas: " limit

useradd -e "$(date -d "$days days" +"%Y-%m-%d")" -M -s /bin/false "$user"
echo "$user:$pass" | chpasswd

mkdir -p /etc/arturo
touch /etc/arturo/limitai.db
grep -v "^$user " /etc/arturo/limitai.db > /tmp/limitai 2>/dev/null
mv /tmp/limitai /etc/arturo/limitai.db 2>/dev/null
echo "$user $limit" >> /etc/arturo/limitai.db

echo ""
echo "======================"
echo "Vartotojas sukurtas!"
echo "User: $user"
echo "Pass: $pass"
echo "Galioja: $days dienų"
echo "Limitas: $limit"
echo "======================"
read -p "Spausk ENTER..." pause
menu
;;

2|02)
clear
echo "======================"
echo " ESAMI VPN VARTOTOJAI"
echo "======================"
echo ""

if [ -s /etc/arturo/limitai.db ]; then
    awk '{print $1 " | limitas: " $2}' /etc/arturo/limitai.db
else
    echo "Vartotojų nėra."
fi

echo ""
read -p "Vartotojas ištrynimui: " user

if id "$user" >/dev/null 2>&1; then
    userdel --force "$user"
    sed -i "/^$user /d" /etc/arturo/limitai.db 2>/dev/null
    echo ""
    echo "Vartotojas pašalintas: $user"
else
    echo ""
    echo "Toks vartotojas nerastas!"
fi

read -p "Spausk ENTER..." pause
menu
;;

3|03)
clear

echo "=============================="
echo "      VPN VARTOTOJAI"
echo "=============================="
echo ""

if [ -s /etc/arturo/limitai.db ]; then

while read user limit; do

exp=$(chage -l "$user" 2>/dev/null | grep "Account expires" | cut -d: -f2)

echo "Vartotojas : $user"
echo "Limitas    : $limit"
echo "Galioja iki:$exp"
echo "------------------------------"

done < /etc/arturo/limitai.db

else
    echo "Vartotojų nėra."
fi

echo ""
read -p "Spausk ENTER..." pause
menu
;;

4|04)
clear

IP=$(curl -s ipv4.icanhazip.com)
RAM=$(free -h | awk '/Mem:/ {print $3 "/" $2}')
DISK=$(df -h / | awk 'NR==2 {print $3 "/" $2}')
UPTIME=$(uptime -p)
CPU=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}')
OS=$(lsb_release -ds)

echo "=============================="
echo " SERVERIO INFORMACIJA"
echo "=============================="
echo ""
echo "IP adresas : $IP"
echo "OS         : $OS"
echo "RAM        : $RAM"
echo "DISKAS     : $DISK"
echo "CPU LOAD   : $CPU%"
echo "UPTIME     : $UPTIME"
echo ""
echo "=============================="

read -p "Spausk ENTER..." pause
clear
bash /usr/local/bin/menu
exit
;;

5|05)
clear

echo "=============================="
echo " SERVISŲ PERKROVIMAS"
echo "=============================="
echo ""

systemctl restart ssh
systemctl restart dropbear
systemctl restart squid

echo "SSH      : PERKRAUTA"
echo "DROPBEAR : PERKRAUTA"
echo "SQUID    : PERKRAUTA"

if systemctl is-active --quiet badvpn; then
    systemctl restart badvpn
    echo "BADVPN   : PERKRAUTA"
fi

echo ""
echo "=============================="

read -p "Spausk ENTER..." pause
clear
bash /usr/local/bin/menu
exit
;;

6|06)
clear
echo "Speedtest funkciją pridėsim kitame žingsnyje."
read -p "Spausk ENTER..." pause
menu
;;

0|00)
exit
;;

*)
echo "Neteisingas pasirinkimas!"
read -p "Spausk ENTER..." pause
menu
;;

esac
EOF

chmod +x /usr/local/bin/menu

echo -e "${GREEN}Diegimas baigtas! Paleisk: menu${NC}"
menu
