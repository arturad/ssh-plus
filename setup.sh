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
echo -e "\033[1;31m   SSHPLUS MANAGER\033[0m  \033[1;37mby @Arturas\033[0m"
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

echo -e "\033[1;34m====================================================\033[0m"

echo ""
echo "[01] • SUKURTI VARTOTOJĄ"
echo "[02] • PAŠALINTI VARTOTOJĄ"
echo "[03] • PRISIJUNGĘ VARTOTOJAI"
echo "[04] • SERVERIO INFORMACIJA"
echo "[05] • PERKRAUTI SERVISUS"
echo "[06] • SPEEDTEST"
echo "[07] • BACKUP"
echo "[08] • BAD VPN"
echo "[09] • INFO VPS"
echo "[10] • AUTO-REBOOT"
echo "[00] • IŠEITI"
echo ""

read -p "KĄ NORITE DARYTI ?: " opc

case $opc in

1)
echo "Ruošiama..."
;;

2)
echo "Ruošiama..."
;;

3)
echo "Ruošiama..."
;;

4)
clear
echo "Serverio IP:"
curl -s ifconfig.me
echo ""
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

7)
echo "Ruošiama..."
;;

8)
echo "Ruošiama..."
;;

9)
neofetch
;;

10)
echo "Ruošiama..."
;;

0)
exit
;;

*)
echo "Neteisingas pasirinkimas!"
;;

esac

EOF
