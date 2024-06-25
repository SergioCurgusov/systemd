#!/bin/bash

#Создаём файл /etc/default/watchlog:

cat >> /etc/default/watchlog << EOF
# Configuration file for my watchlog service
# Place it to /etc/default

# File and word in that file that we will be monit
WORD="ALERT"
LOG=/var/log/watchlog.log
EOF

#Создаём файл /var/log/watchlog.log:

cat >> /var/log/watchlog.log << EOF
ALERT
EOF

#Создадим скрипт:

cat >> /opt/watchlog.sh << EOF
#!/bin/bash

WORD=\$1
LOG=\$2
DATE=\`date\`

if grep \$WORD \$LOG &> /dev/null
then
logger "\$DATE: I found word, Master!"
else
exit 0
fi
EOF

chmod +x /opt/watchlog.sh

#Создадим юнит для сервиса:

cat >> /etc/systemd/system/watchlog.service << EOF
[Unit]
Description=My watchlog service

[Service]
Type=oneshot
EnvironmentFile=/etc/default/watchlog
ExecStart=/opt/watchlog.sh \$WORD \$LOG
EOF

#Создадим юнит для таймера:

cat >> /etc/systemd/system/watchlog.timer << EOF
[Unit]
Description=Run watchlog script every 30 second

[Timer]
# Run every 30 second
OnUnitActiveSec=30
Unit=watchlog.service
OnCalendar=*:*:0/30

[Install]
WantedBy=multi-user.target
EOF

#Запускаем сервис:
systemctl start watchlog.timer

# Установить spawn-fcgi и создать unit-файл (spawn-fcgi.sevice) с помощью переделки init-скрипта (https://gist.github.com/cea2k/1318020).

#Устанавливаем spawn-fcgi и необходимые для него компоненты.
apt update
apt install spawn-fcgi php php-cgi php-cli apache2 libapache2-mod-fcgid -y

#Создаём файл /etc/spawn-fcgi/fcgi.conf:

mkdir /etc/spawn-fcgi

cat >> /etc/spawn-fcgi/fcgi.conf << EOF
# You must set some working options before the "spawn-fcgi" service will work.
# If SOCKET points to a file, then this file is cleaned up by the init script.
#
# See spawn-fcgi(1) for all possible options.
#
# Example :
SOCKET=/var/run/php-fcgi.sock
OPTIONS="-u www-data -g www-data -s \$SOCKET -S -M 0600 -C 32 -F 1 -- /usr/bin/php-cgi"
EOF

#Создаём юнит:

cat >> /etc/systemd/system/spawn-fcgi.service << EOF
[Unit]
Description=Spawn-fcgi startup service by Otus
After=network.target

[Service]
Type=simple
PIDFile=/var/run/spawn-fcgi.pid
EnvironmentFile=/etc/spawn-fcgi/fcgi.conf
ExecStart=/usr/bin/spawn-fcgi -n \$OPTIONS
KillMode=process

[Install]
WantedBy=multi-user.target
EOF

#Запускаем сервис:
systemctl start spawn-fcgi

# Доработать unit-файл Nginx (nginx.service) для запуска нескольких инстансов сервера с разными конфигурационными файлами одновременно.

#Устанавливаем NGINX:

apt install nginx -y

#Для запуска нескольких экземпляров сервиса модифицируем исходный service для использования различной конфигурации, а также PID-файлов. Для этого создадим новый Unit для работы с шаблонами (/etc/systemd/system/nginx@.service):

cat >> /etc/systemd/system/nginx@.service << EOF
# Stop dance for nginx
# =======================
#
# ExecStop sends SIGSTOP (graceful stop) to the nginx process.
# If, after 5s (--retry QUIT/5) nginx is still running, systemd takes control
# and sends SIGTERM (fast shutdown) to the main process.
# After another 5s (TimeoutStopSec=5), and if nginx is alive, systemd sends
# SIGKILL to all the remaining processes in the process group (KillMode=mixed).
#
# nginx signals reference doc:
# http://nginx.org/en/docs/control.html
#
[Unit]
Description=A high performance web server and a reverse proxy server
Documentation=man:nginx(8)
After=network.target nss-lookup.target

[Service]
Type=forking
PIDFile=/run/nginx-%I.pid
ExecStartPre=/usr/sbin/nginx -t -c /etc/nginx/nginx-%I.conf -q -g 'daemon on; master_process on;'
ExecStart=/usr/sbin/nginx -c /etc/nginx/nginx-%I.conf -g 'daemon on; master_process on;'
ExecReload=/usr/sbin/nginx -c /etc/nginx/nginx-%I.conf -g 'daemon on; master_process on;' -s reload
ExecStop=-/sbin/start-stop-daemon --quiet --stop --retry QUIT/5 --pidfile /run/nginx-%I.pid
TimeoutStopSec=5
KillMode=mixed

[Install]
WantedBy=multi-user.target
EOF

#Далее необходимо создать два файла конфигурации (/etc/nginx/nginx-first.conf, /etc/nginx/nginx-second.conf). Их можно сформировать из стандартного конфига /etc/nginx/nginx.conf, с модификацией путей до PID-файлов и разделением по портам:

cp /etc/nginx/nginx.conf /etc/nginx/nginx-first.conf
sed -i 's/\/run\/nginx.pid/\/run\/nginx-first.pid/g' /etc/nginx/nginx-first.conf

TEMPVAR=$(cat /etc/nginx/nginx-first.conf | grep -n "include /etc/nginx/sites-enabled" | grep -v \# | awk '{print $1}')
TEMPVAR="${TEMPVAR::-1}"
sed -i $TEMPVAR"s/^/#/" /etc/nginx/nginx-first.conf
sed -i $TEMPVAR'a\ ' /etc/nginx/nginx-first.conf
sed -i $TEMPVAR'a\        }' /etc/nginx/nginx-first.conf
sed -i $TEMPVAR'a\          listen 9001;' /etc/nginx/nginx-first.conf
sed -i $TEMPVAR'a\        server {' /etc/nginx/nginx-first.conf
sed -i $TEMPVAR'a\ ' /etc/nginx/nginx-first.conf

cp /etc/nginx/nginx.conf /etc/nginx/nginx-second.conf
sed -i 's/\/run\/nginx.pid/\/run\/nginx-second.pid/g' /etc/nginx/nginx-second.conf

TEMPVAR=$(cat /etc/nginx/nginx-second.conf | grep -n "include /etc/nginx/sites-enabled" | grep -v \# | awk '{print $1}')
TEMPVAR="${TEMPVAR::-1}"
sed -i $TEMPVAR"s/^/#/" /etc/nginx/nginx-second.conf
sed -i $TEMPVAR'a\ ' /etc/nginx/nginx-second.conf
sed -i $TEMPVAR'a\        }' /etc/nginx/nginx-second.conf
sed -i $TEMPVAR'a\          listen 9002;' /etc/nginx/nginx-second.conf
sed -i $TEMPVAR'a\        server {' /etc/nginx/nginx-second.conf
sed -i $TEMPVAR'a\ ' /etc/nginx/nginx-second.conf

#Запускаем сервисы:

systemctl start nginx@first
systemctl start nginx@second
