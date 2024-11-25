# В якості фаєрвола використаєм nftables

# Переконаємось, що пакет nftables встановлен
apt update ; apt install -y nftables

# Вімкнемо його для автозавантаженя під ввімкненя системи
systemctl enable nftables

# Налаштовуємо фаєрвол
cat << EOF > /etc/nftables.conf
#!/usr/sbin/nft -f
flush ruleset

define pub_iface = "enp0s3"
define loc_iface = "enp0s8"

table inet filter {
	chain prerouting {
		type nat hook prerouting priority 100; policy accept;
	}

	chain input {
		type filter hook input priority filter; policy accept;
		ct state vmap { invalid : drop, established : accept, related : accept } counter packets 0 bytes 0
		ip saddr 127.0.0.0/16 accept
		ip saddr 10.0.0.0/8 accept
		ip saddr 172.16.0.0/12 accept
		udp dport {ssh, https} counter packets 0 bytes 0 accept
		tcp dport {ssh, https} counter packets 0 bytes 0 accept
		ip protocol icmp counter packets 0 bytes 0 accept
		iifname $pub_iface meta l4proto udp ct state new udp dport ssh counter packets 0 bytes 0 accept
		iifname $pub_iface meta l4proto tcp ct state new tcp dport ssh counter packets 0 bytes 0 accept
		iifname $loc_iface counter packets 0 bytes 0 accept
		tcp dport { 1-20000 } jump network
		drop
	}

	chain forward {
		type filter hook forward priority filter; policy accept;
		iifname $pub_iface oifname $loc_iface ct state established,related counter packets 0 bytes 0 accept
		iifname $loc_iface oifname $loc_iface ct state established,related counter packets 0 bytes 0 accept
		meta l4proto { icmp, ipv6-icmp } counter packets 0 bytes 0 accept
		ct state vmap { invalid : drop, related : accept } counter packets 0 bytes 0
	}

	chain output {
		type filter hook output priority filter; policy accept;
		oifname $pub_iface counter packets 0 bytes 0 accept
		oifname $loc_iface counter packets 0 bytes 0 accept

	}

table inet nat {
	chain POSTROUTING {
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
