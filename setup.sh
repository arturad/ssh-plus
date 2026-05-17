#!/bin/bash

GREEN='\033[0;32m'
RED='\033[0;31m'89
BLUE='\033[1;34m'
NC='\033[0m'

apt update -y

apt install -y \
curl \
wget \
sudo \
cron \
net-tools \
lsb-release \
dropbear \
squid \
apache2 \
stunnel4 \
neofetch \
vnstat \
screen \
git \
build-essential \
cmake \
python3 \
python3-pip \
nodejs \
nginx

mkdir -p /etc/arturo

cat > /etc/arturo/sh.js << 'EOF'
const net = require('net');

const server = net.createServer((socket) => {
    socket.once('data', (buffer) => {
        const data = buffer.toString();

        // Jeigu tai tikra WS užklausa
        if (data.includes('Upgrade: websocket')) {
            socket.write(
                "HTTP/1.1 101 Switching Protocols\r\n" +
                "Upgrade: websocket\r\n" +
                "Connection: Upgrade\r\n\r\n"
            );
            
            const ssh = net.connect(22, '127.0.0.1', () => {
                socket.pipe(ssh);
                ssh.pipe(socket);
            });

            ssh.setKeepAlive(true);
            ssh.setNoDelay(true);
            socket.setKeepAlive(true);
            socket.setNoDelay(true);

            ssh.on('error', () => socket.destroy());
            socket.on('error', () => ssh.destroy());
        } else {
            // Jei tai paprastas srautas, šitas skriptas pasitraukia
            socket.destroy();
        }
    });
});

server.listen(8088, () => {
    console.log('WS bridge started');
});
EOF




rm -f /etc/nginx/sites-enabled/default

apt install -y squid

cat > /etc/squid/squid.conf << 'EOF'
acl localhost src 127.0.0.1/32 ::1
acl all src 0.0.0.0/0

acl Safe_ports port 80
acl Safe_ports port 443
acl Safe_ports port 22
acl Safe_ports port 110
acl Safe_ports port 8080
acl CONNECT method CONNECT

http_access allow localhost
http_access allow Safe_ports
http_access allow CONNECT
http_reply_access allow all
http_access allow all

http_port 0.0.0.0:8080

visible_hostname VPSMANAGER
via off
forwarded_for off
pipeline_prefetch off
EOF





systemctl stop squid 2>/dev/null
systemctl disable squid 2>/dev/null
systemctl enable squid
systemctl restart squid
mkdir -p /etc/systemd/system/squid.service.d
cat > /etc/systemd/system/squid.service.d/override.conf << 'EOF'
[Service]
LimitNOFILE=65535
EOF
systemctl daemon-reload
systemctl restart squid

sed -i 's/^Listen .*/Listen 8888/g' /etc/apache2/ports.conf
sed -i 's/<VirtualHost \*:80>/<VirtualHost *:8888>/g' /etc/apache2/sites-enabled/000-default.conf
sed -i 's/ENABLED=0/ENABLED=1/g' /etc/default/stunnel4

systemctl enable apache2
systemctl restart apache2

systemctl enable stunnel4
systemctl restart stunnel4
systemctl start stunnel4
systemctl daemon-reload
systemctl enable nodews
systemctl restart nodews
systemctl restart nginx

mkdir -p /etc/stunnel

openssl req -new -x509 -days 3650 -nodes \
-out /etc/stunnel/stunnel.pem \
-keyout /etc/stunnel/stunnel.pem \
-subj "/CN=localhost"

cat > /etc/stunnel/stunnel.conf << 'EOFSSL'
cert = /etc/stunnel/stunnel.pem
client = no
socket = a:SO_REUSEADDR=1
socket = l:TCP_NODELAY=1
socket = r:TCP_NODELAY=1

[ssh-ssl]
accept = 443
connect = 127.0.0.1:22

[ws-ssl]
accept = 6443
connect = 127.0.0.1:80
EOFSSL

echo 'ENABLED=1' > /etc/default/stunnel4

pkill stunnel4
killall stunnel 2>/dev/null

systemctl enable stunnel4
systemctl restart stunnel4
mkdir -p /etc/arturo
touch /etc/arturo/limitai.db

systemctl enable vnstat 2>/dev/null
systemctl restart vnstat 2>/dev/null

apt purge -y speedtest-cli 2>/dev/null
dpkg -r --force-all speedtest-cli 2>/dev/null
rm -f /usr/bin/speedtest

curl -s https://packagecloud.io/install/repositories/ookla/speedtest-cli/script.deb.sh | bash

apt install -y speedtest
cd /usr/local/src
rm 
systemctl enable dropbear 2>/dev/null
systemctl restart dropbear 2>/dev/null

systemctl enable squid 2>/dev/null
systemctl restart squid 2>/dev/null

sed -i 's/Listen 80/Listen 8888/g' /etc/apache2/ports.conf
systemctl enable apache2 2>/dev/null
systemctl restart apache2 2>/dev/null
mkdir -p /etc/arturo

mkdir -p /etc/arturo

# Sukuriame švarų /etc/issue.net su HTML formatavimu
echo "<font color='#33b5e5'>" > /etc/issue.net
echo "=========================================<br/>" >> /etc/issue.net
echo "        WELCOME TO ARTURO VPN<br/>" >> /etc/issue.net
echo "=========================================<br/>" >> /etc/issue.net
echo "         PREMIUM SERVER RULES<br/>" >> /etc/issue.net
echo "=========================================<br/>" >> /etc/issue.net
echo "- NO DDOS<br/>" >> /etc/issue.net
echo "- NO HACKING<br/>" >> /etc/issue.net
echo "- NO DOWNLOAD FILE TORRENT<br/>" >> /etc/issue.net
echo "- MAX LOGIN 2 DEVICE<br/>" >> /etc/issue.net
echo "- VIOLATION = PERMANENT BAN<br/>" >> /etc/issue.net
echo "=========================================<br/>" >> /etc/issue.net
echo "THANK YOU FOR USING ARTURO VPN<br/>" >> /etc/issue.net
echo "=========================================<br/>" >> /etc/issue.net
echo "</font>" >> /etc/issue.net




grep -q "^Banner /etc/issue.net" /etc/ssh/sshd_config || echo "Banner /etc/issue.net" >> /etc/ssh/sshd_config
systemctl restart ssh
systemctl restart dropbear
cat > /usr/local/bin/menu << 'EOF'
#!/bin/bash

clear
[ -f /etc/arturo/banner ] && bash /etc/arturo/banner
OS=$(lsb_release -ds | tr -d '"')
RAM_TOTAL=$(free -h | awk '/Mem:/ {print $2}')
RAM_USED=$(free | awk '/Mem:/ {printf("%.1f"), $3/$2 * 100}')
CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}')
TIME=$(date +"%H:%M:%S")

SSH_PORT=$(grep -i "^Port" /etc/ssh/sshd_config | head -1 | awk '{print $2}')
[ -z "$SSH_PORT" ] && SSH_PORT="22"

echo -e "\033[1;34m==================================================\033[0m"
echo -e "\033[1;37;41m  SSHPLUS MANAGER ⇌   by @mekigis  \033[0m"
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
echo -e "\033[1;34m====================================\033[0m"

online=$(who | wc -l)
total=$(awk -F: '$3 >= 1000 && $1 != "nobody" {print $1}' /etc/passwd | wc -l)
expired=0

echo -e "\033[1;33mPrisijungę:\033[0m $online"
echo -e "\033[1;33mViso vartotojų:\033[0m $total"
echo -e "\033[1;33mPasibaigusių:\033[0m $expired"

echo -e "\033[1;34m====================================\033[0m"

echo ""
echo -e "\033[1;34m=========== SERVICE STATUS ===========\033[0m"

systemctl is-active --quiet ssh && SSH_STATUS="\033[1;32mONLINE\033[0m" || SSH_STATUS="\033[1;31mOFFLINE\033[0m"

systemctl is-active --quiet dropbear && DROPBEAR_STATUS="\033[1;32mONLINE\033[0m" || DROPBEAR_STATUS="\033[1;31mOFFLINE\033[0m"

systemctl is-active --quiet squid && SQUID_STATUS="\033[1;32mONLINE\033[0m" || SQUID_STATUS="\033[1;31mOFFLINE\033[0m"

ss -lntp | grep -q ':80 ' && WS_STATUS="\033[1;32mONLINE\033[0m" || WS_STATUS="\033[1;31mOFFLINE\033[0m"

systemctl is-active --quiet stunnel4 && SSL_STATUS="\033[1;32mONLINE\033[0m" || SSL_STATUS="\033[1;31mOFFLINE\033[0m"
systemctl is-active --quiet apache2 && APACHE_STATUS="\033[1;32mONLINE\033[0m" || APACHE_STATUS="\033[1;31mOFFLINE\033[0m"

pgrep badvpn-udpgw >/dev/null && BADVPN_STATUS="\033[1;32mONLINE\033[0m" || BADVPN_STATUS="\033[1;31mOFFLINE\033[0m"

echo -e "SSH         : 22    $SSH_STATUS"
echo -e "DROPBEAR    : 110   $DROPBEAR_STATUS"
echo -e "SQUID       : 8080  $SQUID_STATUS"
echo -e "WEBSOCKET   : 80    $WS_STATUS"
echo -e "SSL         : 443   $SSL_STATUS"
echo -e "APACHE2     : 8888  $APACHE_STATUS"
echo -e "BADVPN      : 7300  $BADVPN_STATUS"

echo -e "\033[1;34m======================================\033[0m"
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

if id "$user" >/dev/null 2>&1; then
echo ""
echo "Toks vartotojas jau egzistuoja!"
read -p "Spausk ENTER..." pause
menu
exit
fi

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

echo "========== VARTOTOJŲ INFORMACIJA =========="
echo ""

cut -d: -f1 /etc/passwd | grep -E '^[a-zA-Z0-9]' | while read user
do
exp=$(chage -l $user 2>/dev/null | grep "Account expires" | cut -d: -f2)
lim=$(grep "^$user " /root/limit.db 2>/dev/null | awk '{print $2}')

echo "Vartotojas : $user"
echo "Galioja iki: $exp"
echo "Limitas : ${lim:-Neribotas}"
echo "-----------------------------------"
done

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
while true; do
clear

echo "================================="
echo " Telegram Bot (AutoBackup)"
echo "================================="
echo ""
echo " VPS Atsarginių kopijų valdymas"
echo ""
echo " Automatinės atsarginės kopijos statusas: [Įjungta]"
echo ""
echo "[1] Nustatyti Telegram Bot"
echo "[2] Automatinės atsarginės kopijos įjungimas/išjungimas"
echo "[3] Kurti VPS atsarginę kopiją (Telegram)"
echo "[4] Atkurti duomenis"
echo "[5] Grįžti į pagrindinį meniu"
echo ""
read -p "Pasirinkite iš meniu [1 - 5]: " opc2

case $opc2 in
1)
clear
read -p "BOT TOKEN: " token
read -p "CHAT ID: " chatid

mkdir -p /etc/arturo

cat > /etc/arturo/telegram.conf << EOTG
BOT_TOKEN="$token"
CHAT_ID="$chatid"
EOTG

echo ""
echo "Telegram botas išsaugotas!"
read -p "Spausk ENTER..."
;;

2)
clear

if [ -f /etc/arturo/autobackup ]; then
rm -f /etc/arturo/autobackup
echo "AutoBackup išjungtas!"
else
touch /etc/arturo/autobackup
echo "AutoBackup įjungtas!"
fi

read -p "Spausk ENTER..."
;;

3)
clear

IP=$(curl -s ipv4.icanhazip.com)
DATE=$(date +%Y-%m-%d)

BACKUP_NAME="backup-${IP}-${DATE}.tar.gz"

tar -czf /root/$BACKUP_NAME \
/etc/arturo \
/root/*.db \
/usr/local/bin/menu \
/etc/passwd \
/etc/shadow \
/etc/group \
/etc/gshadow \
/etc/xray \
/etc/stunnel \
/etc/squid \
/etc/dropbear \
/etc/ssh \
/etc/apache2 \
/var/www/html \
/etc/crontab \
/root/cert \
2>/dev/null

source /etc/arturo/telegram.conf

curl -F document=@/root/$BACKUP_NAME \
"https://api.telegram.org/bot$BOT_TOKEN/sendDocument?chat_id=$CHAT_ID"

echo ""
echo "Backup išsiųstas į Telegram!"
echo "Failas: $BACKUP_NAME"
read -p "Spausk ENTER..."
;;

4)
clear
echo "Įkelkite backup failą į /root/"
echo "Failo pavadinimas: backup.tar.gz"
read -p "Spausk ENTER..."
;;

5)
menu
break
;;

*)
echo "Neteisingas pasirinkimas!"
sleep 2
;;
esac
done
;;
10|10)
clear
echo "Perkraunami servisai..."
echo ""

for s in ssh dropbear squid stunnel4 nginx nodews apache2; do
    echo -n "$s ... "
    systemctl restart $s 2>/dev/null && echo "OK" || echo "KLAIDA / NĖRA"
done

echo ""
read -p "Spausk ENTER..." pause
menu
;;
11|11)
reboot
;;
12|12)
clear

if grep -q "menu" /root/.bashrc; then
sed -i '/menu/d' /root/.bashrc

echo ""
echo "Auto MENU išjungtas!"

else
echo 'clear; menu' >> /root/.bashrc

echo ""
echo "Auto MENU įjungtas!"

fi

read -p "Spausk ENTER..." pause
menu
;;
13)
clear
echo "Atnaujinamas skriptas..."

wget -O /root/setup.sh https://raw.githubusercontent.com/arturad/ssh-plus/main/setup.sh

chmod +x /root/setup.sh

bash /root/setup.sh

;;
14)
clear
echo "======================"
echo " TORRENT BLOKAVIMAS"
echo "======================"
echo ""
echo "[1] Blokuoti torrentus"
echo "[2] Atblokuoti torrentus"
echo ""

read -p "Pasirinkimas: " tor

case $tor in

1)
iptables -A OUTPUT -p tcp --dport 6881:6999 -j DROP
iptables -A OUTPUT -p udp --dport 6881:6999 -j DROP

echo ""
echo "Torrentai užblokuoti!"
;;

2)
iptables -D OUTPUT -p tcp --dport 6881:6999 -j DROP 2>/dev/null
iptables -D OUTPUT -p udp --dport 6881:6999 -j DROP 2>/dev/null

echo ""
echo "Torrentai atblokuoti!"
;;

*)
echo "Neteisingas pasirinkimas!"
;;

esac

read -p "Spausk ENTER..." pause
menu
;;
15|15)
clear

if pgrep -f "badvpn-udpgw" >/dev/null; then
    BADVPN_STATUS="IJUNGTAS"
else
    BADVPN_STATUS="ISJUNGTAS"
fi

echo "======================"
echo " BADVPN [$BADVPN_STATUS]"
echo "======================"
echo ""
echo "[1] Ijungti BADVPN"
echo "[2] Isjungti BADVPN"
echo ""

read -p "Pasirinkimas: " bad

case $bad in

1)
pkill -f badvpn-udpgw 2>/dev/null
screen -dmS badvpn badvpn-udpgw --listen-addr 127.0.0.1:7300

sleep 1

if pgrep -f "badvpn-udpgw" >/dev/null; then
    echo ""
    echo "BADVPN paleistas! Statusas: IJUNGTAS"
else
    echo ""
    echo "BADVPN nepasileido!"
fi
;;

2)
pkill -f badvpn-udpgw 2>/dev/null
sleep 1

if pgrep -f "badvpn-udpgw" >/dev/null; then
    echo ""
    echo "BADVPN vis dar veikia!"
else
    echo ""
    echo "BADVPN sustabdytas! Statusas: ISJUNGTAS"
fi
;;

*)
echo "Neteisingas pasirinkimas!"
;;

esac

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
