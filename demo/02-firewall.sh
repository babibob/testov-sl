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
