# Встановлюємо пакет для dhcp сервера isc-dhcp-server

apt-get install -y bind9
systemctl status named

# Для зручності встановлюємо змінні параметрами, які будемо використовувати
export DOMAIN="itedu.local"
export LOCAL_IP="10.200.10.1"
export FORWARD_ZONE_FILE="/var/lib/bind/db.${DOMAIN}"
export REVERCE_ZONE_FILE="/var/lib/bind/db.10.200.10"

# Робимо копії дефолтних конфігурацій
mv /etc/bind/named.conf.options{,.bak}
mv /etc/bind/named.conf.local{,.bak} 
mv "${FORWARD_ZONE_FILE}"{,.bak} 
mv "${REVERCE_ZONE_FILE}"{,.bak} 

# Створюємо та конфігуруємо файл з параметрами роботи сервера
cat <<EOF > /etc/bind/named.conf.options
options {
	directory "/var/cache/bind";

	listen-on port 53 { 127.0.0.1; ${LOCAL_IP}; };
	 allow-query { 127.0.0.0/8; 10.200.10.0/24; };
	 allow-recursion { 127.0.0.0/8; 10.200.10.0/24; };	
	 allow-transfer { none; };
	 forwarders { 1.1.1.1; 8.8.8.8; };

	dnssec-validation no;
	 listen-on-v6 { none; };
};
EOF

# Створюємо та конфігуруємо файл з описанням файлів зон для домену та його зворотньої зони
cat <<EOF > /etc/bind/named.conf.local
zone ${DOMAIN} {
     type master;
     file "${FORWARD_ZONE_FILE}"; 
     allow-transfer { ${LOCAL_IP}; };
};

zone "10.200.10.in-addr.arpa" {
     type master;
     file "${REVERCE_ZONE_FILE}";
     allow-transfer { ${LOCAL_IP}; };
};

EOF

# Створюємо та конфігуруємо файл прямої зони
cat <<EOF > "${FORWARD_ZONE_FILE}"
\$TTL	 86400
@	 IN SOA dns.${DOMAIN}. root.${DOMAIN}. (
         	3	       ; Serial
         	604800	   ; Refresh
       	 	86400	   ; Retry
         	2419200	   ; Expire
         	604800 )   ; Negative Cache TTL

; name server NS record
  IN 	NS 	dns.${DOMAIN}.

; name server A record
dns.${DOMAIN}.       		IN A ${LOCAL_IP}

; A records for 10.200.10.0/24 
gateway.${DOMAIN}.   		IN A ${LOCAL_IP}
dhcp-web.${DOMAIN}.  		IN CNAME gateway
php-admin.${DOMAIN}. 		IN CNAME gateway
mysql-master.${DOMAIN}.	    IN A 10.200.10.11
mysql-slave.${DOMAIN}.    	IN A 10.200.10.12
EOF

# Перевіряємо правильність, в аутпуті не має бути помилок
named-checkzone "${DOMAIN}" "${ZONE_FILE}"

# Створюємо та конфігуруємо файл зворотнбої зони
cat <<EOF > "${REVERCE_ZONE_FILE}"
\$TTL 604800
@	 IN SOA ${DOMAIN}. root.${DOMAIN}. (
            3           ; Serial
            604800      ; Refresh
            86400       ; Retry
            2419200     ; Expire
            604800 )    ; Negative Cache TTL

; name server NS record
  IN 	NS 	dns.${DOMAIN}.

; PTR Records
1   IN      PTR     dns.${DOMAIN}.
1   IN      PTR     gateway.${DOMAIN}.
11  IN      PTR     mysql-master.${DOMAIN}.
12  IN      PTR     mysql-slave.${DOMAIN}.
EOF

# Перевіряємо правильність, в аутпуті не має бути помилок
named-checkzone 10.200.10.in-addr.arpa ${REVERCE_ZONE_FILE}

# Задаємо права 

chown root:bind /etc/bind/named.conf.options /etc/bind/named.conf.local "${FORWARD_ZONE_FILE}" "${REVERCE_ZONE_FILE}"
chmod 640       /etc/bind/named.conf.options /etc/bind/named.conf.local "${FORWARD_ZONE_FILE}" "${REVERCE_ZONE_FILE}"
ls -la          /etc/bind/named.conf.options /etc/bind/named.conf.local "${FORWARD_ZONE_FILE}" "${REVERCE_ZONE_FILE}"

# Перевіряємо правильність конфігурації, в аутпуті не має бути помилок
named-checkconf


# Перезапускаємо сервіс для застосування налаштувань
systemctl restart named

# Перевіряємо статус сервісу
systemctl status named

# Перевіряємо як наш сервер обробляє запити
dig gateway.${DOMAIN} @${LOCAL_IP}

dig ${LOCAL_IP} @${LOCAL_IP}
