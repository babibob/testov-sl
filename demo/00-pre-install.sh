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

