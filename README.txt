1) Написать service, который будет раз в 30 секунд мониторить лог на предмет наличия ключевого слова (файл лога и ключевое слово должны задаваться в /etc/default).

Создаём файл /etc/default/watchlog:

cat >> /etc/default/watchlog << EOF
# Configuration file for my watchlog service
# Place it to /etc/default

# File and word in that file that we will be monit
WORD="ALERT"
LOG=/var/log/watchlog.log
EOF

Создаём файл /var/log/watchlog.log:

cat >> /var/log/watchlog.log << EOF
ALERT
EOF

Создадим скрипт:

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

Создадим юнит для сервиса:

cat >> /etc/systemd/system/watchlog.service << EOF
[Unit]
Description=My watchlog service

[Service]
Type=oneshot
EnvironmentFile=/etc/default/watchlog
ExecStart=/opt/watchlog.sh \$WORD \$LOG
EOF

Создадим юнит для таймера:

cat >> /etc/systemd/system/watchlog.timer << EOF
[Unit]
Description=Run watchlog script every 30 second

[Timer]
# Run every 30 second
OnUnitActiveSec=30
Unit=watchlog.service

[Install]
WantedBy=multi-user.target
EOF

Запускаем сервис:

systemctl start watchlog.timer

tail -n 1000 /var/log/syslog  | grep word

root@ubuntu-focal:/home/vagrant# tail -n 1000 /var/log/syslog  | grep word
Jun 24 19:11:38 ubuntu-focal root: Mon Jun 24 19:11:38 UTC 2024: I found word, Master!
Jun 24 19:12:42 ubuntu-focal root: Mon Jun 24 19:12:42 UTC 2024: I found word, Master!
Jun 24 19:13:22 ubuntu-focal root: Mon Jun 24 19:13:22 UTC 2024: I found word, Master!
Jun 24 19:14:06 ubuntu-focal root: Mon Jun 24 19:14:06 UTC 2024: I found word, Master!
Jun 24 19:14:42 ubuntu-focal root: Mon Jun 24 19:14:42 UTC 2024: I found word, Master!
Jun 24 19:15:32 ubuntu-focal root: Mon Jun 24 19:15:32 UTC 2024: I found word, Master!
Jun 24 19:16:36 ubuntu-focal root: Mon Jun 24 19:16:36 UTC 2024: I found word, Master!
Jun 24 19:17:42 ubuntu-focal root: Mon Jun 24 19:17:42 UTC 2024: I found word, Master!
Jun 24 19:18:42 ubuntu-focal root: Mon Jun 24 19:18:42 UTC 2024: I found word, Master!

2) Установить spawn-fcgi и создать unit-файл (spawn-fcgi.sevice) с помощью переделки init-скрипта (https://gist.github.com/cea2k/1318020).

Устанавливаем spawn-fcgi и необходимые для него компоненты.
apt update
apt install spawn-fcgi php php-cgi php-cli apache2 libapache2-mod-fcgid -y

Создаём файл /etc/spawn-fcgi/fcgi.conf:

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

Создаём юнит:

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

Запускаем сервис:
systemctl start spawn-fcgi

Проверяем:
systemctl status spawn-fcgi

root@ubuntu-focal:/home/vagrant# systemctl status spawn-fcgi
● spawn-fcgi.service - Spawn-fcgi startup service by Otus
     Loaded: loaded (/etc/systemd/system/spawn-fcgi.service; disabled; vendor preset: enabled)
     Active: active (running) since Mon 2024-06-24 20:37:08 UTC; 5s ago
   Main PID: 29553 (php-cgi)
      Tasks: 33 (limit: 1117)
     Memory: 17.9M
     CGroup: /system.slice/spawn-fcgi.service
             ├─29553 /usr/bin/php-cgi
             ├─29555 /usr/bin/php-cgi
             ├─29556 /usr/bin/php-cgi
             ├─29557 /usr/bin/php-cgi
             ├─29558 /usr/bin/php-cgi
             ├─29559 /usr/bin/php-cgi
             ├─29560 /usr/bin/php-cgi
             ├─29561 /usr/bin/php-cgi
             ├─29562 /usr/bin/php-cgi
             ├─29563 /usr/bin/php-cgi
             ├─29564 /usr/bin/php-cgi
             ├─29565 /usr/bin/php-cgi
             ├─29566 /usr/bin/php-cgi
             ├─29567 /usr/bin/php-cgi
             ├─29568 /usr/bin/php-cgi
             ├─29569 /usr/bin/php-cgi
             ├─29570 /usr/bin/php-cgi
             ├─29571 /usr/bin/php-cgi
             ├─29572 /usr/bin/php-cgi
             ├─29573 /usr/bin/php-cgi
             ├─29574 /usr/bin/php-cgi
             ├─29575 /usr/bin/php-cgi
             ├─29576 /usr/bin/php-cgi
             ├─29577 /usr/bin/php-cgi
             ├─29578 /usr/bin/php-cgi
             ├─29579 /usr/bin/php-cgi
             ├─29580 /usr/bin/php-cgi
             ├─29581 /usr/bin/php-cgi
             ├─29582 /usr/bin/php-cgi
             ├─29583 /usr/bin/php-cgi
             ├─29584 /usr/bin/php-cgi
             ├─29585 /usr/bin/php-cgi
             └─29586 /usr/bin/php-cgi

Jun 24 20:37:08 ubuntu-focal systemd[1]: Started Spawn-fcgi startup service by Otus.

3) Доработать unit-файл Nginx (nginx.service) для запуска нескольких инстансов сервера с разными конфигурационными файлами одновременно.

Устанавливаем NGINX:

apt install nginx -y

Для запуска нескольких экземпляров сервиса модифицируем исходный service для использования различной конфигурации, а также PID-файлов. Для этого создадим новый Unit для работы с шаблонами (/etc/systemd/system/nginx@.service):

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

Далее необходимо создать два файла конфигурации (/etc/nginx/nginx-first.conf, /etc/nginx/nginx-second.conf). Их можно сформировать из стандартного конфига /etc/nginx/nginx.conf, с модификацией путей до PID-файлов и разделением по портам:

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

Запускаем сервисы:

systemctl start nginx@first
systemctl start nginx@second

проверяем:

systemctl status nginx@first
systemctl status nginx@second

ss -tnulp | grep nginx

root@ubuntu-focal:/etc/nginx# ss -tnulp | grep nginx
tcp    LISTEN  0        511                 0.0.0.0:9001          0.0.0.0:*      users:(("nginx",pid=34090,fd=6),("nginx",pid=34089,fd=6),("nginx",pid=34088,fd=6))
tcp    LISTEN  0        511                 0.0.0.0:9002          0.0.0.0:*      users:(("nginx",pid=34123,fd=6),("nginx",pid=34122,fd=6),("nginx",pid=34121,fd=6))

ps afx | grep nginx

root@ubuntu-focal:/etc/nginx# ps afx | grep nginx
  34444 pts/0    S+     0:00                          \_ grep --color=auto nginx
  34088 ?        Ss     0:00 nginx: master process /usr/sbin/nginx -c /etc/nginx/nginx-first.conf -g daemon on; master_process on;
  34089 ?        S      0:00  \_ nginx: worker process
  34090 ?        S      0:00  \_ nginx: worker process
  34121 ?        Ss     0:00 nginx: master process /usr/sbin/nginx -c /etc/nginx/nginx-second.conf -g daemon on; master_process on;
  34122 ?        S      0:00  \_ nginx: worker process
  34123 ?        S      0:00  \_ nginx: worker process







