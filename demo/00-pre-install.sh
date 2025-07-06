### Перелік налаштувань з практики 25.10.2024

# Спершу у Vbox створюєм вітртуальну машину з двома мереживими адаптерами :
#    1 зовнішній  -в режимі bridged; 
#    2 внутрішній -в режимі Internal Network.
# Запускаєм віртуальну машину та логінимось під користувачем root.

# Встановлюємо пакети vim та sudo для зручної роботи
apt update ; apt install -y vim sudo curl mc net-tools htop nftables tree inetutils-ping netcat

USERNAME=<username>

useradd $USERNAME -d /home/$USERNAME -s /bin/bash ; \
 mkdir -p /home/$USERNAME/.ssh ; \
 chown $USERNAME:$USERNAME -R /home/$USERNAME ; \
 chmod 774 -R /home/$USERNAME ; \
 cat > /home/$USERNAME/.ssh/authorized_keys <<EOF
 ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQC4dj9GJTmYdX6ggdhXvyaswOAAOD5r0iUB+UAMY0BKeSLLW/d4dGmZ6+niL1WRSQY15Q/0ARKZA4dx3wnkvOY0p724Z7JVUQpGQFcY6u4lWC3/V7A5dlSxqzCb+PLwFPd57kOQkepyYrG7WCboRaXPg9NkOOiGLKsMBt/BmnPJODAinN/kIm60D4kg7//AAVq9LJenYGJQi6QlEdoPzbPCZSqwoTAj5V1r1s7NHyQPxgMN58h7s2TkRYwnc9SQ9fIliL6461TgBVARUcdQSIPhl/nByO01MFTq6BV+c1EOSTEIzqipnxcIk8nfWsKnl329T0I3ArOpO9mE3D/J6edrKWWc+Gx1gXnhP5Oklp75wWILUhehdDK6JpFrpstM0tJAQDQ5Vbp2j2NtVTCQeaydozGiXxDX/sJBUz7ALlsOequ5OYY/mGysmDovh0EM7SHS/TctSqqAUEUDexGOVPgokfUqPEV0yMGtqrnlNQc0MnYapD51KbWA80Q1r0GgLL8= $USERNAME.priv_pub
EOF

cat > /home/$USERNAME/.bashrc <<EOF

if [ -f ~/.bash_aliases ]; then
    . ~/.bash_aliases
fi

alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'
alias randpw='< /dev/urandom tr -dc 'a-zA-Z0-9' | fold -w 36 | head -n 5'
alias python='/usr/bin/python3'

alias ls='ls --color=auto'
alias dir='dir --color=auto'
alias vdir='vdir --color=auto'

alias grep='grep --color=auto'
alias fgrep='fgrep --color=auto'
alias egrep='egrep --color=auto'

# Add an "alert" alias for long running commands.  Use like so:
#   sleep 10; alert
alias alert='notify-send --urgency=low -i "$([ $? = 0 ] && echo terminal || echo error)" "$(history|tail -n1|sed -e '\''s/^\s*[0-9]\+\s*//;s/[;&|]\s*alert$//'\'')"'

# append to the history file, don't overwrite it
shopt -s histappend

export HISTCONTROL=ignoredups
export HISTSIZE=10000
export HISTTIMEFORMAT="%h %d %H:%M:%S "
PROMPT_COMMAND='history -a'
export HISTIGNORE="&:history:ls:[bf]g:exit:ll:w:htop:pwd"
force_color_prompt=yes
PATH='/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin'
PS1='${debian_chroot:+($debian_chroot)}\[\033[01;34m\]\A \[\033[01;32m\]\u@\[\033[01;33m\]\h\[\033[01;34m\]\w# \[\033[00;38m\]'
EOF
# При винекненні помилки "apt-listchanges: Can't set locale; make sure $LC_* and $LANG are correct!" виконайте

echo "LC_ALL=en_US.UTF-8" >> /etc/environment
echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf

# Встановлюєм vim за замовчування
update-alternatives --set editor /usr/bin/vim.tiny

# Додаємо "не root" користувача $USERNAME в групу sudo
usermod -aG sudo $USERNAME

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
ssh-keygen -t ed25519 -C "$USERNAME_key"

# Копіюєм публічну частину ключа на сервер для подальшого доступу до нього
cat ~/.ssh/id_ed25519.pub | ssh $USERNAME@10.200.10.1 "mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys"
# Альтрнативний спосіб
# ssh-copy-id $USERNAME@10.200.10.1

# Під'єднуємось по ssh. важливо щоб віртуальна машина не запитувала пароль
ssh $USERNAME@10.200.10.1

# Змінюємо конфігурацію ssh - 
# Забороняємо логін по паролю
sed -i "s/PasswordAuthentication(.+)$/PasswordAuthentication\ no/g" /etc/ssh/sshd_config

# Забороняємо логін користувачу root
sed -i "s/PermitRootLogin(.+)$/PermitRootLogin\ no/g" /etc/ssh/sshd_config

# Перевіряємо коректність ssh конфігурації
sshd -T

# Перезапускаємо сервіс sshd
systemctl restart sshd
systemctl status sshd
