
# Встановлюємо пакет для dhcp сервера isc-dhcp-server
apt install -y isc-dhcp-server

# Робимо копію дефолтної конфігурації
cp /etc/default/isc-dhcp-server{,.default}

# Законментовуємо неактуальні рядки
sed -i "s/^INTERFACE/#INTERFACE/g" /etc/default/isc-dhcp-server
# StrimEDitor - дозволяє вносити зміни в тестовий файл не відкриваючи його (у потоці)
# Example -- sed "s/шо_шукаєм/на_що_замінюєм/" /шлях/та/назва_файла

# Додаємо в кінець файлу isc-dhcp-server на якому інтерфейсі сервер буде приймати dhcp запити
echo 'INTERFACESv4="enp0s8"' >> /etc/default/isc-dhcp-server

# Робимо копію дефолтної конфігурації
cp /etc/dhcp/dhcpd.conf{,.default}
# Конфігуруємо dhcpd сервер
sed -i "s/^#authoritative;$/authoritative;/g" /etc/dhcp/dhcpd.conf

# Створюємо директорію для зручності зберігання конфігів

mkdir -p /etc/dhcp/dhcpd.d/
echo 'include "/etc/dhcp/dhcpd.d/subnet.conf";' >> /etc/dhcp/dhcpd.d/dhcpd.conf
echo 'include "/etc/dhcp/dhcpd.d/static.conf";' >> /etc/dhcp/dhcpd.d/static.conf
# EXAMPLE with for
# for file in subnet static ; 
#  do echo "include \"/etc/dhcp/dhcpd.d/$file.conf\";" >> /etc/dhcp/dhcpd.conf ;
# done

# Додаємо конфігурацію мережі dhcp-сервера
cat << EOF > /etc/dhcp/dhcpd.d/subnet.conf 
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
cat << EOF > /etc/dhcp/dhcpd.d/static.conf 
host mysql {
   hardware ethernet <MAC:ADDRESS:FROM:NETWOTK:MYSQL:SERVER>; # example 08:45:32:00:00:23
   fixed-address 10.200.10.11;
}

host web {
   hardware ethernet <MAC:ADDRESS:FROM:NETWOTK:WEB:SERVER>; # example - 08:45:32:00:00:24
   fixed-address 10.200.10.12;
}
EOF

# Перевіряємо кронфігурцію
dhcpd -t -cf /etc/dhcp/dhcpd.conf

# Перезапускаємо сервіс isc-dhcp-server
systemctl restart isc-dhcp-server
systemctl status isc-dhcp-server

# На цьому етапі ми отримали dhcpd-сервер з двома налаштованими інтерфейсами (зовнішній - в інтернет та внутрішній - до інших серверів)
# Тепер треба відкрити доступ до зовнішної мережі через наш сервер. Для цього треба виконати дві умови
# 1 - Налаштувати фаєрвол, який буде дозволяти форвардити трафік у зовнішню мережу та маскарадити його у внутрішню
# 2 - Ввімкнути параметр ядра, який дозволяє системі передавати пакети між інтерфейсами
