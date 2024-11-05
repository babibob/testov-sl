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

# Додаєм присутнім в групі sudo користувачам повні права, на додаток не буде запитувати пароль
echo "%sudo ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

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


#!!!!! Дві команди виконуються на локальній машині для надання ssh доступу !!!!
# Створюєм пару ключів
ssh-keygen -t ed25519 -C "<usrname>_key"

# Копіюєм публічну частину ключа на сервер для подальшого доступу до нього
cat ~/.ssh/id_ed25519.pub | ssh <usrname>@10.200.10.1 "mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys"
# Альтрнативний спосіб
# ssh-copy-id <usrname>@10.200.10.1

# Під'єднуємось по ssh. важливо щоб віртуальна машина не запитувала пароль
ssh <usrname>@10.200.10.1

# Змінюємо конфігурацію ssh - 
# Забороняємо логін по паролю
sed PasswordAuthentication(.+)$

# Забороняємо логін користувачу root
sed -i "s/PermitRootLogin(.+)$/PermitRootLogin\ no/g" /etc/ssh/sshd_config

# Перевіряємо коректність ssh конфігурації
sshd -T

# Перезапускаємо сервіс sshd
systemctl restart sshd
systemctl status sshd
