#!/bin/bash

GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[1;34m'
NC='\033[0m'

apt update -y
apt install -y curl wget sudo cron net-tools lsb-release dropbear squid neofetch

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

SSH_PORT=$(grep -i "^Port" /etc/ssh/sshd_config | head -1 | awk '{print $2}')
[ -z "$SSH_PORT" ] && SSH_PORT="22"

echo -e "\033[1;34m==================================================\033[0m"
echo -e "\033[1;37;41m  SSHPLUS MANAGER ⇌   by @Rolka ✩ @Arturas  \033[0m"
echo -e "\033[1;34m==================================================\033[0m"

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
echo -e "\033[1;34m==================================================\033[0m"
echo "sshd: $SSH_PORT"
echo "dropbear: 443"
echo "squid: 3128"
echo "badvpn-udpgw: 7300"
echo -e "\033[1;34m==================================================\033[0m"

echo -e "\033[1;36m[01]\033[0m • SUKURTI VARTOTOJĄ        \033[1;36m[09]\033[0m • BACKUP"
echo -e "\033[1;36m[02]\033[0m • PAŠALINTI VARTOTOJĄ      \033[1;36m[10]\033[0m • PERKRAUTI SERVISUS"
echo -e "\033[1;36m[03]\033[0m • PRISIJUNGĘ VARTOTOJAI    \033[1;36m[11]\033[0m • PERKRAUTI SISTEMĄ"
echo -e "\033[1;36m[04]\033[0m • KEISTI DATĄ              \033[1;36m[12]\033[0m • AUTO PALEISTIS MENU"
echo -e "\033[1;36m[05]\033[0m • KEISTI LIMITĄ            \033[1;36m[13]\033[0m • ATNAUJINTI SKRIPTĄ"
echo -e "\033[1;36m[06]\033[0m • KEISTI SLAPTAŽODĮ        \033[1;36m[14]\033[0m • BLOKUOTI TORRENTUS"
echo -e "\033[1;36m[07]\033[0m • DUOMENŲ MONITORIUS       \033[1;36m[15]\033[0m • BADVPN"
echo -e "\033[1;36m[08]\033[0m • SPEEDTEST                \033[1;36m[16]\033[0m • TELEGRAM BOT"

echo ""
echo -e "\033[1;31m[00]\033[0m • IŠEITI <<<"

echo ""
read -p "KĄ NORITE DARYTI ?? : " opc

case "$opc" in

1|01)
clear
read -p "Vartotojas: " user
read -p "Slaptažodis: " pass
read -p "Dienų skaičius: " days
read -p "Prisijungimų limitas: " limit

useradd -e $(date -d "$days days" +"%Y-%m-%d") -M -s /bin/false $user
echo "$user:$pass" | chpasswd

grep -v "^$user " /etc/arturo/limitai.db > /tmp/limitai
mv /tmp/limitai /etc/arturo/limitai.db
echo "$user $limit" >> /etc/arturo/limitai.db

echo ""
echo "========================"
echo "Vartotojas sukurtas!"
echo "User: $user"
echo "Pass: $pass"
echo "Galioja: $days dienų"
echo "Limitas: $limit"
echo "========================"

read -p "Spausk ENTER..." pause
menu
;;
2|02)
clear

echo "========================"
echo " VPN VARTOTOJAI"
echo "========================"

if [ -s /etc/arturo/limitai.db ]; then
while read user limit; do
exp=$(chage -l "$user" 2>/dev/null | grep "Account expires" | cut -d: -f2)

echo "Vartotojas : $user"
echo "Limitas    : $limit"
echo "Galioja iki:$exp"
echo "------------------------"

done < /etc/arturo/limitai.db
else
echo "Vartotojų nėra."
fi

echo ""
read -p "Vartotojas ištrynimui: " user

if id "$user" >/dev/null 2>&1; then
userdel --force "$user"
sed -i "/^$user /d" /etc/arturo/limitai.db

echo ""
echo "Vartotojas pašalintas!"
else
echo ""
echo "Toks vartotojas nerastas!"
fi

read -p "Spausk ENTER..." pause
menu
;;
3|03)
clear
who
read -p "Spausk ENTER..." pause
menu
;;
4|04)
clear
read -p "Įveskite vartotoją: " user
read -p "Kiek dienų pridėti: " extra

if chage -l "$user" >/dev/null 2>&1; then

current=$(chage -l "$user" | grep "Account expires" | cut -d: -f2)

if [[ "$current" == " never" ]]; then
newdate=$(date -d "+$extra days" +"%Y-%m-%d")
else
newdate=$(date -d "$current +$extra days" +"%Y-%m-%d")
fi

chage -E "$newdate" "$user"

echo ""
echo "========================"
echo "Data pakeista!"
echo "Vartotojas: $user"
echo "Galioja iki: $newdate"
echo "========================"

else
echo "Toks vartotojas nerastas!"
fi

read -p "Spausk ENTER..." pause
menu
;;
5|05)
clear

echo "========================"
echo " VPN VARTOTOJAI"
echo "========================"

if [ -s /etc/arturo/limitai.db ]; then
awk '{print $1 " | limitas: " $2}' /etc/arturo/limitai.db
else
echo "Vartotojų nėra."
fi

echo ""
read -p "Įveskite vartotoją: " user
read -p "Naujas limitas: " limit

if id "$user" >/dev/null 2>&1; then

sed -i "/^$user /d" /etc/arturo/limitai.db
echo "$user $limit" >> /etc/arturo/limitai.db

echo ""
echo "========================"
echo "Limitas pakeistas!"
echo "Vartotojas: $user"
echo "Naujas limitas: $limit"
echo "========================"

else
echo "Toks vartotojas nerastas!"
fi

read -p "Spausk ENTER..." pause
menu
;;
6|06)
clear
read -p "Vartotojas: " user
read -p "Naujas slaptažodis: " pass

echo "$user:$pass" | chpasswd

echo ""
echo "Slaptažodis pakeistas!"

read -p "Spausk ENTER..." pause
menu
;;
7|07)
clear
vnstat
read -p "Spausk ENTER..." pause
menu
;;
8|08)
clear
speedtest
read -p "Spausk ENTER..." pause
menu
;;
9|09)
clear
tar -czf /root/backup.tar.gz /etc/arturo
echo "Backup sukurtas: /root/backup.tar.gz"
read -p "Spausk ENTER..." pause
menu
;;
10|10)
clear
systemctl restart ssh
systemctl restart dropbear
systemctl restart squid

echo "Servisai perkrauti!"
read -p "Spausk ENTER..." pause
menu
;;
11|11)
reboot
;;
12|12)
clear
echo "@reboot root menu" > /etc/cron.d/menu
echo "Auto paleidimas įjungtas!"
read -p "Spausk ENTER..." pause
menu
;;
13|13)
clear
wget -O /root/setup.sh https://raw.githubusercontent.com/arturad/ssh-plus/main/setup.sh
bash /root/setup.sh
;;
14|14)
clear
iptables -A FORWARD -m string --string "torrent" --algo bm -j DROP
echo "Torrentai blokuoti!"
read -p "Spausk ENTER..." pause
menu
;;
15|15)
clear
screen -dmS badvpn badvpn-udpgw --listen-addr 127.0.0.1:7300
echo "BADVPN paleistas!"
read -p "Spausk ENTER..." pause
menu
;;
16|16)
clear
echo "Telegram botas bus pridėtas vėliau."
read -p "Spausk ENTER..." pause
menu
;;
0|00)
exit
;;
*)
echo "Neteisingas pasirinkimas!"
sleep 2
menu
;;
esac
EOF

chmod +x /usr/local/bin/menu

echo -e "${GREEN}Diegimas baigtas! Paleisk: menu${NC}"

menu
