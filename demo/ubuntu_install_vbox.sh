# Додаєм репозіторій
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/oracle-virtualbox-2016.gpg] https://download.virtualbox.org/virtualbox/debian jammy contrib" > /etc/apt/sources.list.d/oracle-virtualbox.list

# Завантажуєм файл з підписом репозіторія
wget -O- https://www.virtualbox.org/download/oracle_vbox_2016.asc | sudo gpg --yes --output /usr/share/keyrings/oracle-virtualbox-2016.gpg --dearmor

# Перевіряем версію gcc-12 (без якої не будуть запускатись віртуальні машини) і встновлюєм її якщо треба
if dpkg -l | grep gcc-12 >2; 
then
    apt-get update ; apt-get install virtualbox-7.0 ;
else 
    apt-get update ; apt-get install gcc-12 virtualbox-7.0 ;
fi