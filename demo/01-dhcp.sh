
# Встановлюємо пакет для dhcp сервера isc-dhcp-server
apt install -y isc-dhcp-server

# Робимо копію дефолтної конфігурації
cp /etc/default/isc-dhcp-server{,.default}

# Законментовуємо неактуальні рядки
sed -i "s/^INTERFACE/#INTERFACE/g" /etc/default/isc-dhcp-server
# StrimEDitor - дозволяє вносити зміни в тестовий файл не відкриваючи його (у потоці)
# Example --> sed "s/шо_шукаєм/на_що_замінюєм/" /шлях/до/файла

# Додаємо в кінець файлу isc-dhcp-server на якому інтерфейсі сервер буде приймати dhcp запити
echo 'INTERFACESv4="enp0s8"' >> /etc/default/isc-dhcp-server

# Робимо копію дефолтної конфігурації
cp /etc/dhcp/dhcpd.conf{,.default}

#------- при викоритсанні веб-інтерфейса не актуально
# Створюємо директорію для зручності зберігання конфігів
# 
# mkdir -p /etc/dhcp/dhcpd.d/
# echo 'include "/etc/dhcp/dhcpd.d/subnet.conf";' >> /etc/dhcp/dhcpd.conf
# echo 'include "/etc/dhcp/dhcpd.d/static.conf";' >> /etc/dhcp/dhcpd.conf
# EXAMPLE with for
# for file in subnet static ; 
#  do echo "include \"/etc/dhcp/dhcpd.d/$file.conf\";" >> /etc/dhcp/dhcpd.conf ;
# done
# EXAMPLE with in one line
# printf "include \"/etc/dhcp/dhcpd.d/subnet.conf\";\ninclude \"/etc/dhcp/dhcpd.d/static.conf\";\n" >> /etc/dhcp/dhcpd.conf
#-------

# Конфігуруємо dhcpd сервер
sed -i "s/^#authoritative;$/authoritative;/g" /etc/dhcp/dhcpd.conf

# Додаємо конфігурацію мережі dhcp-сервера
cat << EOF >> /etc/dhcp/dhcpd.conf

subnet 10.200.10.0 netmask 255.255.255.0 {
   option subnet-mask 255.255.255.0;
   option routers 10.200.10.1;
   option domain-name-servers 10.200.10.1;
   option domain-name "itedu.local";
   option domain-name-servers ns1.itedu.local;
   default-lease-time 28800;
   max-lease-time 86400;
   pool {
     range 10.200.10.50 10.200.10.250;
   }
}
EOF

# Додаємо конфігурацію зі статичною адресацією
cat << EOF >> /etc/dhcp/dhcpd.conf

host mysql-master1 {
   hardware ethernet <MAC:ADDRESS:FROM:NETWOTK:MYSQL:SERVER>; # example 08:45:32:00:00:23
   fixed-address 10.200.10.11;
}

host mysql-master1 {
   hardware ethernet <MAC:ADDRESS:FROM:NETWOTK:MYSQL:SERVER>; # example 08:45:32:00:00:23
   fixed-address 10.200.10.12;
}

host mysql-slave {
   hardware ethernet <MAC:ADDRESS:FROM:NETWOTK:WEB:SERVER>; # example - 08:45:32:00:00:24
   fixed-address 10.200.10.12;
}
EOF

# Видаляємо коментарі, щоб візуально зменьшити конфігурацію
cat /etc/dhcp/dhcpd.conf | grep -E -v '[^#]|^$' >> /etc/dhcp/dhcpd.conf

# Перевіряємо кронфігурцію
dhcpd -t -cf /etc/dhcp/dhcpd.conf

# Перезапускаємо сервіс isc-dhcp-server
systemctl restart isc-dhcp-server
systemctl status isc-dhcp-server

# На цьому етапі ми отримали dhcpd-сервер з двома налаштованими інтерфейсами (зовнішній - в інтернет та внутрішній - до інших серверів)
# Тепер треба відкрити доступ до зовнішної мережі через наш сервер. Для цього треба виконати дві умови
# 1 - Налаштувати фаєрвол, який буде дозволяти форвардити трафік у зовнішню мережу та маскарадити його у внутрішню
# 2 - Ввімкнути параметр ядра, який дозволяє системі передавати пакети між інтерфейсами

# Встановимо та сконфінуруємо веб-інтерфейс для dhcp server та для подальшого налаштування проксювання через nginx

# Встановимо залежності - nodejs
curl -sL https://deb.nodesource.com/setup_8.x | sudo -E bash -
apt-get install -y nodejs

# Клонуємо репозіторій, в якому зберігається вихідний код веб-інтерфейса в задану директорію
git clone https://github.com/Akkadius/glass-isc-dhcp.git /opt/glass-isc-dhcp

# Створюємо каталог для логів
mkdir -p /opt/glass-isc-dhcp/log
# Hадаємо права на виконання скріптам та бінарним файлам
chmod -R u+x /opt/glass-isc-dhcp/bin/
chmod u+x /opt/glass-isc-dhcp/*.sh
# Виконуємо встановлення пакетів
npm install
npm install forever -g

# Робим копію конфігурації
cp /opt/glass-isc-dhcp/config/glass_config.json{,.bak}

# Змінюєм файл логування
sed -i "s/\/var\/log\//\/opt\/glass-isc-dhcp\/log\//g" /opt/glass-isc-dhcp/config/glass_config.json

# Змінюєм дефолтний пароль
export RANDOM_PASS=$(< /dev/urandom tr -dc a-zA-Z0-9 | fold -w 12 | head -n 1)
sed -i "s/password\"\:\ \"glassadmin\"/password\"\:\ \"${RANDOM_PASS}\"/" /opt/glass-isc-dhcp/config/glass_config.json
echo ${RANDOM_PASS}

# Створюєм systemd unit для коретного запуску веб-інтерфайса
cat <<EOF > /lib/systemd/system/dhcp-web.service
[Unit]
Description='Start web interface for isc-dhcp-server'
Documentation='https://github.com/Akkadius/glass-isc-dhcp/blob/master/README.md'
After=isc-dhcp-server.service
Wants=isc-dhcp-server.service

[Service]
Type=simple
PIDFile=/var/run/dhcp-web.pid
WorkingDirectory=/opt/glass-isc-dhcp
ExecStart=/bin/bash -c "node ./bin/www"
ExecReload=/bin/sh -c "/bin/kill -s HUP $(/bin/cat /var/run/dhcp-web.pid)"
ExecStop=/bin/sh -c "/bin/kill -s TERM $(/bin/cat /var/run/dhcp-web.pid)"

[Install]
WantedBy=multi-user.target
EOF