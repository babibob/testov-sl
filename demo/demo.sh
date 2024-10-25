### Перелік налаштувань з практики 25.10.2024

# Спершу у Vbox створюєм вітртуальну машину з двома мереживими адаптерами :
#    1 зовнішній  -в режимі bridged; 
#    2 внутрішній -в режимі Internal Network.
# Запускаєм віртуальну машину та логінимось під користувачем root.

# Встановлюємо пакети vim та sudo для зручної роботи
apt update ; apt install -y vim sudo

# Встановлюєм vim за замовчування
update-alternatives --set editor /usr/bin/vim.tiny

# Додаємо "не root" користувача <usrname> в групу sudo
usermod -aG sudo <usrname>

# Треба розлогінитись та залогінитись знову з підвищеними привілеями
# Ctrl + d
sudo su

# Треба перевірити які інтерфейси є в системі
# Потім треба обрати, той який в статусі DOWN, це внутрішній інтерфейс (для мережі Internal Network)
# В моєму випадку назва інтерфейса enp0s8
ip link show

# Конфігуруєм інтерфейс enp0s8 Internal Network:
# Коснтоукція EOF(End Of File) дозволяє створювати з командного рядка багато рядкові тектові файли
cat << EOF > /etc/network/interfaces.d/enp0s8
auto enp0s8
iface enp0s8 inet static
	address 10.200.10.1/24
EOF

# Перезапускаємо networking
systemctl restart networking

# Перевіряємо статус networking та чи призначилась адреса та маршрут:
systemctl status networking
ip address show enp0s8
ip route show dev enp0s8

# Якщо помилок немає, то ця нода має доступ к двум мережам: 
#    - доступ в інтернет, через брідж утворений з вашим фізичним адаптером лаптопа
#    - доступ до Internal network, який ми вже налаштували

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
# do echo "include \"/etc/dhcp/dhcpd.d/$file.conf\";" >> /etc/dhcp/dhcpd.conf ;
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

# Перезапускаємо сервіс
systemctl restart isc-dhcp-server
systemctl status isc-dhcp-server

# На цьому етапі ми отримали dhcpd-сервер з двома налаштованими інтерфейсами (зовнішній - в інтернет та внутрішній - до інших серверів)
# Тепер треба відкрити доступ до зовнішної мережі через наш сервер. Для цього треба виконати дві умови
# 1 - Налаштувати фаєрвол, який буде дозволяти форвардити трафік у зовнішню мережу та маскарадити його у внутрішню
# 2 - Ввімкнути параметр ядра, який дозволяє системі передавати пакети між інтерфейсами
# В якості фаєрвола використаєм nftables

# Переконаємось, що пакет nftables встановлен
apt update ; apt install -y nftables

# Вімкнемо його для автозавантаженя під ввімкненя системи
systemctl enable nftables

# Налаштовуємо фаєрвол
cat << EOF > /etc/nftables.conf
#!/usr/sbin/nft -f

flush ruleset

table inet filter {
	chain input {
		type filter hook input priority filter; policy accept;
	}

	chain forward {
		type filter hook forward priority filter; policy accept;
		ct state established counter packets 0 bytes 0 accept
		ct state vmap { invalid : drop, related : accept } counter packets 0 bytes 0
	}

	chain output {
		type filter hook output priority filter; policy accept;
	}
}
table ip nat {
	chain postrouting {
		type nat hook postrouting priority srcnat; policy accept;
		ip saddr 10.200.10.0/24 counter packets 0 bytes 0 masquerade
	}
}
EOF

# Вмикаємо параметр ядра
# sysctl -w net.ipv4.ip_forward=1 - не зберігається після перезавантаження
sed -i 's/#net.ipv4.ip_forward=0/net.ipv4.ip_forward=1/g' /etc/sysctl.conf

# Застосовуємо зміни
sysctl -p
