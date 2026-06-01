#!/bin/bash

GREEN='\033[0;32m'
RED='\033[0;31m'
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

# Jei failas dar neegzistuoja, tik tada jį sukuriame švarų
if [ ! -f /etc/arturo/limitai.db ]; then
    touch /etc/arturo/limitai.db
fi

# Visada užtikriname pilnas teises šiam failui ir visai direktorijai
chmod -R 777 /etc/arturo
chmod 777 /etc/arturo/limitai.db

# =========================================================================
# NAUJAS METODAS: NGINX PRIEKYJE (PORT 80) + NODE.JS FONE (PORT 8181)
# =========================================================================

# 1. Sukuriame Node.js WebSocket tiltą ant porto 8181
mkdir -p /etc/arturo
cat << 'EOF_NODEJS' > /etc/arturo/sh.js
const net = require('net');

const server = net.createServer((socket) => {
    socket.once('data', (buffer) => {
        const data = buffer.toString().toLowerCase();

        const ssh = net.connect(22, '127.0.0.1', () => {
            if (data.includes('upgrade: websocket')) {
                socket.write(
                    "HTTP/1.1 101 Script By Arturo\r\n" +
                    "Upgrade: websocket\r\n" +
                    "Connection: Upgrade\r\n\r\n"
                );
            } else {
                ssh.write(buffer);
            }

            ssh.pipe(socket);
            socket.pipe(ssh);
        });

        ssh.on('error', () => socket.destroy());
        socket.on('error', () => ssh.destroy());
    });
});

server.listen(8181, '127.0.0.1');
EOF_NODEJS


# 2. Sukuriame Systemd servisą, kad Node.js veiktų fone visada
cat << 'EOF_SERVICE' > /etc/systemd/system/nodews.service
[Unit]
Description=NodeJS WS Backend
After=network.target

[Service]
Type=simple
User=root
ExecStart=/usr/bin/node /etc/arturo/sh.js
Restart=always

[Install]
WantedBy=multi-user.target
EOF_SERVICE

systemctl daemon-reload
systemctl enable nodews
systemctl restart nodews

cat > /etc/arturo/PDirect.js <<'EOF'
const net = require('net');
const stream = require('stream');
const util = require('util');

var dhost = "127.0.0.1";
var dport = "109";
var mainPort = "2052";
var packetsToSkip = 0;
var gcwarn = true;

for(c = 0; c < process.argv.length; c++) {
    switch(process.argv[c]) {
        case "-skip":
            packetsToSkip = process.argv[c + 1];
            break;
        case "-dhost":
            dhost = process.argv[c + 1];
            break;
        case "-dport":
            dport = process.argv[c + 1];
            break;
        case "-mport":
            mainPort = process.argv[c + 1];
            break;
    }
}

function gcollector() {
    if(!global.gc && gcwarn) {
        console.log("[WARNING] Garbage Collector isn't enabled! Memory leaks may occur.");
        gcwarn = false;
        return;
    } else if(global.gc) {
        global.gc();
        return;
    }
}

setInterval(gcollector, 1000);

const server = net.createServer();

server.on('connection', function(socket) {
    var packetCount = 0;
    var anu = "Script By Arturo";

    socket.write("HTTP/1.1 101 " + anu + "\r\nContent-Length: 1048576000000\r\n\r\n");

    var conn = net.createConnection({host: dhost, port: dport});

    socket.on('data', function(data) {
        if(packetCount < packetsToSkip) {
            packetCount++;
        } else if(packetCount == packetsToSkip) {
            conn.write(data);
        }

        if(packetCount > packetsToSkip) {
            packetCount = packetsToSkip;
        }
    });

    conn.on('data', function(data) {
        socket.write(data);
    });

    socket.on('error', function() {
        conn.destroy();
    });

    conn.on('error', function() {
        socket.destroy();
    });

    socket.on('close', function() {
        conn.destroy();
    });
});

server.listen(mainPort, function(){
    console.log("[INFO] Server started on port: " + mainPort);
    console.log("[INFO] Redirecting requests to: " + dhost + " at port " + dport);
});
EOF

cat > /etc/systemd/system/pdirect.service <<'EOF'
[Unit]
Description=PDirect WS Bridge
After=network.target

[Service]
Type=simple
User=root
ExecStart=/usr/bin/node --expose-gc /etc/arturo/PDirect.js -dhost 127.0.0.1 -dport 22 -mport 2052 -skip 1
Restart=always

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable pdirect
systemctl restart pdirect

iptables -t nat -D PREROUTING -p tcp --dport 80 -j REDIRECT --to-ports 2052 2>/dev/null
iptables -t nat -A PREROUTING -p tcp --dport 80 -j REDIRECT --to-ports 2052

systemctl stop squid 2>/dev/null
systemctl disable squid 2>/dev/null
systemctl mask squid 2>/dev/null


systemctl stop nginx 2>/dev/null
systemctl stop apache2 2>/dev/null
systemctl disable nginx 2>/dev/null


cat > /etc/squid/squid.conf << 'EOF'
acl mano_serveris dst tavo_ip

http_access allow mano_serveris
http_access deny all

# Squid portas
http_port 0.0.0.0:8080

# DNS nustatymai, kad Squid surastų bet kokį tavo įrašytą hostą (pvz., vodafone.de)
dns_v4_first on
dns_nameservers 8.8.8.8 1.1.1.1

# Paslepiam proxy pėdsakus nuo operatoriaus filtrų
via off
forwarded_for off
request_header_access Allow allow all
request_header_access Authorization allow all
request_header_access Proxy-Authorization allow all
request_header_access Proxy-Connection allow all
request_header_access Proxy-Respond allow all

visible_hostname VPSMANAGER
EOF


mkdir -p /etc/systemd/system/squid.service.d
cat > /etc/systemd/system/squid.service.d/override.conf << 'EOF_SQUID_OVERRIDE'

[Service]
LimitNOFILE=65535
EOF_SQUID_OVERRIDE


systemctl daemon-reload
systemctl enable squid
systemctl restart squid

# 3. Konfigūruojame Apache2 portus
sed -i 's/^Listen .*/Listen 8888/g' /etc/apache2/ports.conf
sed -i 's/<VirtualHost \*:80>/<VirtualHost *:8888>/g' /etc/apache2/sites-enabled/000-default.conf
systemctl enable apache2
systemctl restart apache2

# 4. Konfigūruojame Stunnel4 SSL (Nukreipiam ws-ssl į teisingą Node.js portą 8088)
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
EOFSSL


echo 'ENABLED=1' > /etc/default/stunnel4
pkill stunnel4
killall stunnel 2>/dev/null
systemctl enable stunnel4
systemctl restart stunnel4

# 5. Papildomi nustatymai
touch /etc/arturo/limitai.db
systemctl enable vnstat 2>/dev/null
systemctl restart vnstat 2>/dev/null

systemctl enable dropbear 2>/dev/null
systemctl restart dropbear 2>/dev/null

# Sukuriame issue.net banerį
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
echo "UseDNS no" >> /etc/ssh/sshd_config
echo "TCPKeepAlive yes" >> /etc/ssh/sshd_config
echo "ClientAliveInterval 30" >> /etc/ssh/sshd_config
echo "ClientAliveCountMax 99999" >> /etc/ssh/sshd_config
echo "MaxSessions 500" >> /etc/ssh/sshd_config
echo "MaxStartups 500:30:1000" >> /etc/ssh/sshd_config
echo "LoginGraceTime 20" >> /etc/ssh/sshd_config
echo "Compression no" >> /etc/ssh/sshd_config
systemctl restart ssh
systemctl restart dropbear

apt install -y cmake make gcc g++ git speedtest-cli

cd /tmp
rm -rf badvpn

git clone https://github.com/ambrop72/badvpn.git
cd badvpn

mkdir build
cd build

cmake .. -DBUILD_NOTHING_BY_DEFAULT=1 -DBUILD_UDPGW=1

make install

cat > /etc/systemd/system/badvpn.service << 'EOF'
[Unit]
Description=BadVPN UDPGW
After=network.target

[Service]
ExecStart=/usr/local/bin/badvpn-udpgw --listen-addr 0.0.0.0:7300 --max-clients 500
Restart=always

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable squid >/dev/null 2>&1

# Duodame serveriui sekundę „įkvėpti“ ir keliam servisus
sleep 1
systemctl restart apache2 >/dev/null 2>&1
systemctl restart ssh >/dev/null 2>&1
systemctl restart dropbear >/dev/null 2>&1

# SQUID SPRENDIMAS: prieš jį paleidžiant duodame 2 sekundes tinklui stabilizuotis
sleep 2
systemctl restart squid >/dev/null 2>&1


cd /root
rm -rf /tmp/badvpn

mkdir -p /root/limit

cat > /usr/local/bin/userlimit.sh << 'EOF_USERLIMIT'
#!/bin/bash

# 1. VALYMAS: Jei laikas pasibaigė, visiškai ištriname vartotoją iš serverio
if [ -s /etc/arturo/limitai.db ]; then
    while read -r user limit; do
        [[ -z "$user" || "$user" == "net" ]] && continue
        if chage -l "$user" | grep -q "Account expires" && [ "$(date +%s)" -gt "$(date -d "$(chage -l "$user" | grep "Account expires" | cut -d: -f2)" +%s 2>/dev/null)" ]; then
            pkill -f "sshd: $user" >/dev/null 2>&1
            pkill -u "$user" >/dev/null 2>&1
            userdel -f "$user" >/dev/null 2>&1
            sed -i "/^$user /d" /etc/arturo/limitai.db
        fi
    done < /etc/arturo/limitai.db
fi

# 2. KONTROLĖ: Tikriname limitus realiu laiku
if [ -s /etc/arturo/limitai.db ]; then
    while read -r user limit; do
        [[ -z "$user" || -z "$limit" || "$user" == "net" ]] && continue
        TOTAL=$(ps -u "$user" -o pid= | wc -l)

FLAG="/tmp/limit_${user}"

if [ "$TOTAL" -gt "$limit" ]; then
    if [ -f "$FLAG" ]; then
        OLD=$(cat "$FLAG")
        NOW=$(date +%s)
        DIFF=$((NOW - OLD))

        if [ "$DIFF" -ge 25 ]; then
            pkill -f "sshd: $user"
            pkill -u "$user"
            rm -f "$FLAG"
        fi
    else
        date +%s > "$FLAG"
    fi
else
    rm -f "$FLAG"
fi
EOF_USERLIMIT





# Sukuriame direktoriją, jei jos nėra
mkdir -p /etc/arturo

# Sukuriame gražų pasisveikinimo Banner failą
cat > /etc/arturo/banner << 'EOF_BANNER'
#!/bin/bash
clear
# Spalvų kintamieji
CYAN='\033[0;36m'
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${CYAN} ____ ____  _   _     ____  _    _   _ ____  ${NC}"
echo -e "${CYAN}/ ___/ ___|| | | |   |  _ \| |  | | | / ___| ${NC}"
echo -e "${CYAN}\___ \___ \| |_| |   | |_) | |  | | | \___ \ ${NC}"
echo -e "${CYAN} ___) |__) |  _  |   |  __/| |__| |_| |___) |${NC}"
echo -e "${CYAN}|____/____/|_| |_|___|_|   |_____\___/|____/ ${NC}"
echo -e "${CYAN}                |_____|                      ${NC}"
echo ""
echo -e "${GREEN}SERVERIO PAVADINIMAS :${NC} $(hostname)"
echo -e "${GREEN}DATA :${NC} $(date +'%d-%m-%y')"
echo -e "${GREEN}LAIKAS :${NC} $(date +'%T')"
echo -e "${GREEN}@mekigis${NC}"
echo -e "${RED}NAUDOKITE KOMANDA ( menu ) IEITI I SCRIPTĄ.${NC}"
echo ""
EOF_BANNER


chmod +x /etc/arturo/banner



chmod +x /usr/local/bin/userlimit.sh

(crontab -l 2>/dev/null | grep -v userlimit.sh; echo "* * * * * /usr/local/bin/userlimit.sh") | crontab -

# 6. Gražiname pilną tavo originalų MENU (Visi 16 punktų be pakeitimų)
cat > /usr/local/bin/menu << 'EOF'
#!/bin/bash

clear
# Sukuriame trūkstamus sistemos informacijos kintamuosius
OS=$(lsb_release -ds | tr -d '"')
RAM_TOTAL=$(free -h | grep "Mem:" | awk '{print $2}')
RAM_USED_RAW=$(free | grep "Mem:" | awk '{print $3}')
RAM_TOTAL_RAW=$(free | grep "Mem:" | awk '{print $2}')
RAM_USED=$((RAM_USED_RAW * 100 / RAM_TOTAL_RAW))
TIME=$(date +'%T')

# Iškviečiame viršutinį logotipą
[ -f /etc/arturo/banner ] && bash /etc/arturo/banner

# Atvaizduojame gautą statistiką ekrane
echo -e "\033[1;32mSISTEMA\033[0m"
echo "OS: $OS"
echo "Laikas: $TIME"

echo ""
echo -e "\033[1;32mATMINTIS RAM\033[0m"
echo "Iš viso: $RAM_TOTAL"
echo "Naudoja: ${RAM_USED}%"


echo ""
echo -e "\033[1;34m=========================================\033[0m"


echo ""
echo -e "\033[1;34m====================================\033[0m"

online=$(awk -F: '$3 >= 1000 && $1 != "nobody" {print $1}' /etc/passwd | while read user; do pgrep -u "$user" >/dev/null && echo "$user"; done | wc -l)

total=$(awk -F: '$3 >= 1000 && $1 != "nobody" {print $1}' /etc/passwd | wc -l)

expired=$(awk -F: '$3 >= 1000 && $1 != "nobody" {print $1}' /etc/passwd | while read user; do

exp=$(chage -l "$user" 2>/dev/null | grep "Account expires" | cut -d: -f2)

if [[ "$exp" != " never" && "$exp" != "never" ]]; then

expsec=$(date -d "$exp" +%s 2>/dev/null)
now=$(date +%s)

if [ "$now" -gt "$expsec" ]; then
echo "$user"
fi

fi

done | wc -l)

echo -e "\033[1;33mPrisijungę:\033[0m $online"
echo -e "\033[1;33mViso vartotojų:\033[0m $total"
echo -e "\033[1;33mPasibaigusių:\033[0m $expired"

echo -e "\033[1;34m====================================\033[0m"

echo ""
echo -e "\033[1;34m=========== SERVICE STATUS ===========\033[0m"

systemctl is-active --quiet ssh && SSH_STATUS="\033[1;32mONLINE\033[0m" || SSH_STATUS="\033[1;31mOFFLINE\033[0m"
systemctl is-active --quiet dropbear && DROPBEAR_STATUS="\033[1;32mONLINE\033[0m" || DROPBEAR_STATUS="\033[1;31mOFFLINE\033[0m"
systemctl is-active --quiet squid && SQUID_STATUS="\033[1;32mONLINE\033[0m" || SQUID_STATUS="\033[1;31mOFFLINE\033[0m"
systemctl is-active --quiet pdirect && WS_STATUS="\033[1;32mONLINE\033[0m" || WS_STATUS="\033[1;31mOFFLINE\033[0m"
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
echo -e "\033[1;36m[03]\033[0m • VARTOTOJU INFORMACIJA    \033[1;36m[11]\033[0m • PERKRAUTI SISTEMĄ"
echo -e "\033[1;36m[04]\033[0m • KEISTI DATĄ              \033[1;36m[12]\033[0m • AUTO PALEISTIS MENU"
echo -e "\033[1;36m[05]\033[0m • KEISTI LIMITĄ            \033[1;36m[13]\033[0m • ATNAUJINTI SKRIPTĄ"
echo -e "\033[1;36m[06]\033[0m • KEISTI SLAPTAŽODĮ        \033[1;36m[14]\033[0m • BLOKUOTI TORRENTUS"
echo -e "\033[1;36m[07]\033[0m • DUOMENŲ MONITORIUS       \033[1;36m[15]\033[0m • BADVPN"
echo -e "\033[1;36m[08]\033[0m • SPEEDTEST                \033[1;36m[16]\033[0m • TELEGRAM BOT"
echo -e "                                \033[1;36m[17]\033[0m • PRISIJUNGĘ VARTOTOJAI"

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

# Paimame tik tikrus vartotojus, kurių UID yra 1000 arba didesnis (atmetame sisteminius)
awk -F: '$3 >= 1000 && $1 != "nobody" {print $1}' /etc/passwd | while read user
do
    # Gauname paskyros galiojimo pabaigos datą
    exp=$(chage -l "$user" 2>/dev/null | grep "Account expires" | cut -d: -f2)
    
    # Gauname prisijungimų limitą iš tavo duomenų bazės (priklausomai nuo to, kur laikai failą)
    if [ -f /root/limit.db ]; then
        lim=$(grep -w "^$user" /root/limit.db | awk '{print $2}')
    elif [ -f /etc/arturo/limitai.db ]; then
        lim=$(grep -w "^$user" /etc/arturo/limitai.db | awk '{print $2}')
    else
        lim=""
    fi

    # Gražiai išvedame informaciją į ekraną
    echo "Vartotojas : $user"
    echo "Galioja iki: ${exp:-never}"
    echo "Limitas    : ${lim:-Neribotas}"
    echo "-------------------------------------------"
done

read -p "Spausk ENTER..." _
menu
;;
4|04)
clear
echo "========================="
echo "     VPN VARTOTOJAI      "
echo "========================="
if [ -s /etc/arturo/limitai.db ]; then
    while read -r u l; do
        exp=$(chage -l "$u" | grep "Account expires" | cut -d: -f2 | xargs)
        echo "Vartotojas : $u"
        echo "Galioja iki: $exp"
        echo "-------------------------"
    done < /etc/arturo/limitai.db
else
    echo "Vartotojų nėra."
fi
echo ""
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

mkdir -p /root/limit
echo "$limit" > /root/limit/$user
sed -i "/^$user /d" /etc/arturo/limitai.db 2>/dev/null
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
echo "========================="
echo "     VPN VARTOTOJAI      "
echo "========================="
if [ -s /etc/arturo/limitai.db ]; then
    while read -r u l; do
        echo "Vartotojas : $u"
        echo "Limitai    : $l"
        echo "-------------------------"
    done < /etc/arturo/limitai.db
else
    echo "Vartotojų nėra."
fi
echo ""
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
speedtest-cli
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
read -p "Failo pavadinimas [backup.tar.gz]: " BKP

if [[ -z "$BKP" ]]; then
    BKP="backup.tar.gz"
fi

if [[ ! -f "/root/$BKP" ]]; then
    echo "KLAIDA: failas /root/$BKP nerastas!"
    read -p "Spausk ENTER..."
else
    echo "Atkuriamas backup..."
    tar -xzf "/root/$BKP" -C /

    echo "Backup atkurtas!"
    echo "Perkraunami servisai..."

    systemctl restart ssh 2>/dev/null
    systemctl restart dropbear 2>/dev/null
    systemctl restart squid 2>/dev/null
    systemctl restart stunnel4 2>/dev/null
    systemctl restart apache2 2>/dev/null

    read -p "Spausk ENTER..."
fi
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

for s in ssh dropbear squid stunnel4 nodews apache2; do
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

bash <(curl -L -s https://raw.githubusercontent.com/arturad/ssh-plus/main/setup-pdirect.sh)
;;
    14)
        clear
        echo "============================="
        echo "      TORRENT BLOKAVIMAS     "
        echo "============================="
        echo ""
        echo " [1] Blokuoti torrentus"
        echo " [2] Atblokuoti torrentus"
        echo ""
        read -p "Pasirinkimas: " tor

        case $tor in
            1)
                # Pirmiausia išvalome senas, kad nesidubliuotų
                iptables -D FORWARD -m string --algo bm --string "bittorrent" -j DROP 2>/dev/null
                iptables -D FORWARD -m string --algo bm --string "announce" -j DROP 2>/dev/null
                iptables -D FORWARD -m string --algo bm --string "info_hash" -j DROP 2>/dev/null
                iptables -D FORWARD -p udp --dport 1024:65535 -m string --algo bm --string "tracker" -j DROP 2>/dev/null
                iptables -D FORWARD -p tcp --dport 6881:6999 -j DROP 2>/dev/null
                iptables -D FORWARD -p udp --dport 6881:6999 -j DROP 2>/dev/null

                # 🚫 Įjungiame stiprų filtravimą pagal paketo turinį
                iptables -A FORWARD -m string --algo bm --string "bittorrent" -j DROP
                iptables -A FORWARD -m string --algo bm --string "announce" -j DROP
                iptables -A FORWARD -m string --algo bm --string "info_hash" -j DROP
                iptables -A FORWARD -p udp --dport 1024:65535 -m string --algo bm --string "tracker" -j DROP

                # 🚫 Uždarome išplėstus Torrent portus
                iptables -A FORWARD -p tcp --dport 6881:6999 -j DROP
                iptables -A FORWARD -p udp --dport 6881:6999 -j DROP

                # Išsaugome taisykles, kad liktų po restarto
                apt install iptables-persistent -y >/dev/null 2>&1
                netfilter-persistent save >/dev/null 2>&1
                
                echo ""
                echo "✅ Torrentai sėkmingai užblokuoti!"
                ;;
            2)
                # 🟢 Atblokuojame - ištriname visas sukurtas taisykles
                iptables -D FORWARD -m string --algo bm --string "bittorrent" -j DROP 2>/dev/null
                iptables -D FORWARD -m string --algo bm --string "announce" -j DROP 2>/dev/null
                iptables -D FORWARD -m string --algo bm --string "info_hash" -j DROP 2>/dev/null
                iptables -D FORWARD -p udp --dport 1024:65535 -m string --algo bm --string "tracker" -j DROP 2>/dev/null
                iptables -D FORWARD -p tcp --dport 6881:6999 -j DROP 2>/dev/null
                iptables -D FORWARD -p udp --dport 6881:6999 -j DROP 2>/dev/null

                # Išsaugome tuščią būseną
                netfilter-persistent save >/dev/null 2>&1

                echo ""
                echo "✅ Torrentai sėkmingai atblokuoti!"
                ;;
            *)
                echo ""
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
    17|17)
    clear
    echo "========================="
    echo "   PRISIJUNGĘ VARTOTOJAI "
    echo "========================="
    if [ -s /etc/arturo/limitai.db ]; then
        while read -r u l; do
            [[ -z "$u" || "$u" == "net" ]] && continue
            
            # Tikslus ir saugus srautų skaičiavimas
            online=$(ps aux | grep -E "sshd: $u@|sshd: $u " | grep -v grep | wc -l)
            
            if [ "$online" -gt 0 ]; then
                echo "Vartotojas: $u ($online/$l)"
            fi
        done < /etc/arturo/limitai.db
    else
        echo "Vartotojų nėra."
    fi
    echo ""
    read -p "Spausk ENTER..." pause
    menu
    ;;
esac
EOF

chmod +x /usr/local/bin/menu

# Kasnakt 04:00 val. ryte automatiškai perkrauname servisus, kad išsivalytų RAM atmintis
(crontab -l 2>/dev/null | grep -v "systemctl restart"; echo "0 4 * * * systemctl restart ssh dropbear squid nginx badvpn >/dev/null 2>&1") | crontab -
# Įrašome bannerio paleidimą į sistemos profilį, kad rodytų iškart prisijungus prie SSH
grep -q "/etc/arturo/banner" /root/.bashrc || echo "bash /etc/arturo/banner" >> /root/.bashrc

echo -e "${GREEN}Diegimas baigtas! Paleisk: menu${NC}"
menu

