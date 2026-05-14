cat > /usr/local/bin/menu << 'EOF'
#!/bin/bash

clear

OS=$(lsb_release -ds | tr -d '"')
RAM_TOTAL=$(free -h | awk '/Mem:/ {print $2}')
RAM_USED=$(free | awk '/Mem:/ {printf("%.1f"), $3/$2 * 100}')
CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}')
TIME=$(date +"%H:%M:%S")

SSH_PORT=$(grep Port /etc/ssh/sshd_config | head -1 | awk '{print $2}')

echo -e "\033[1;34m====================================================\033[0m"
echo -e "\033[1;37;41m   SSHPLUS MANAGER ⇌   by @Rolka ✩ @Arturas   \033[0m"
echo -e "\033[1;34m====================================================\033[0m"

echo ""
echo -e "\033[1;32mSISTEMA\033[0m"
echo -e "OS: $OS"
echo -e "Laikas: $TIME"

echo ""
echo -e "\033[1;32mATMINTIS RAM\033[0m"
echo -e "Iš viso: $RAM_TOTAL"
echo -e "Naudoja: ${RAM_USED}%"

echo ""
echo -e "\033[1;32mPROCESORIUS\033[0m"
echo -e "Naudoja: ${CPU_USAGE}%"

echo ""
echo -e "\033[1;34m====================================================\033[0m"

echo -e "sshd: ${SSH_PORT:-22}"
echo -e "dropbear: 443"
echo -e "squid: 3128"
echo -e "badvpn-udpgw: 7300"

echo -e "\033[1;34m====================================================\033[0m"

echo -e "\033[1;36m[01]\033[0m • SUKURTI VARTOTOJĄ"
echo -e "\033[1;36m[02]\033[0m • PAŠALINTI VARTOTOJĄ"
echo -e "\033[1;36m[03]\033[0m • PRISIJUNGĘ VARTOTOJAI"
echo -e "\033[1;36m[04]\033[0m • SERVERIO INFORMACIJA"
echo -e "\033[1;36m[05]\033[0m • PERKRAUTI SERVISUS"
echo -e "\033[1;36m[06]\033[0m • SPEEDTEST"
echo -e "\033[1;36m[07]\033[0m • BACKUP"
echo -e "\033[1;36m[08]\033[0m • BAD VPN"
echo -e "\033[1;36m[09]\033[0m • INFO VPS"
echo -e "\033[1;36m[10]\033[0m • AUTO-REBOOT"

echo ""
echo -e "\033[1;31m[00]\033[0m • IŠEITI"

echo ""
read -p "KĄ NORITE DARYTI ?? : " opc

case $opc in

1)
clear
read -p "Vartotojas: " user
read -p "Slaptažodis: " pass
read -p "Dienų skaičius: " days
read -p "Prisijungimų limitas: " limit

useradd -e $(date -d "$days days" +"%Y-%m-%d") -M -s /bin/false $user
mkdir -p /etc/arturo
echo "$user $limit" >> /etc/arturo/limitai.db

echo ""
echo ""
echo "==============="
echo "Vartotojas sukurtas!"
echo "User: $user"
echo "Pass: $pass"
echo "Galioja: $days dienų"
echo "Limitas: $limit"
echo "==============="
;;

2)
clear

echo "======================"
echo " ESAMI VARTOTOJAI"
echo "======================"
echo ""

cut -d: -f1 /etc/passwd | grep -E '^[a-zA-Z0-9]' | tail -n +1

echo ""
read -p "Vartotojas ištrynimui: " user

userdel --force $user 2>/dev/null

sed -i "/^$user /d" /etc/arturo/limitai.db 2>/dev/null

echo ""
echo "======================"
echo "Vartotojas pašalintas!"
echo "User: $user"
echo "======================"

read -p "Spausk ENTER..."
menu
;;
;;
;;

3)
clear
who
;;

4)
clear
neofetch
;;

5)
systemctl restart ssh
systemctl restart dropbear
systemctl restart squid
echo "Servisai perkrauti!"
;;

6)
speedtest
;;

0)
exit
;;

*)
echo "Neteisingas pasirinkimas!"
;;

esac

EOF
