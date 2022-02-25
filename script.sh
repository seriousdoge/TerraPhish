#!/bin/bash
apt update
DEBIAN_FRONTEND=noninteractive apt install postfix -y
DEBIAN_FRONTEND=noninteractive apt install opendkim opendkim-tools postfix-policyd-spf-python  -y
DEBIAN_FRONTEND=noninteractive apt install nginx -y

echo 'policyd-spf  unix  -       n       n       -       0       spawn
    user=policyd-spf argv=/usr/bin/policyd-spf' >> /etc/postfix/master.cf

echo 'policyd-spf_time_limit = 3600
smtpd_recipient_restrictions =
        check_policy_service unix:private/policyd-spf,' >> /etc/postfix/main.cf

snap install core;snap refresh core
snap install --classic certbot
ln -s /snap/bin/certbot /usr/bin/certbot


sleep 1m
certbot certonly --nginx --noninteractive --agree-tos --email admin@$1 -d $1


#certbot-auto certonly --nginx --noninteractive --agree-tos --email admin@$1 -d $1
apt install unzip -y
mkdir /opt/gophish
cd /opt/gophish
wget https://github.com/gophish/gophish/releases/download/v0.11.0/gophish-v0.11.0-linux-64bit.zip

unzip gophish-v0.11.0-linux-64bit.zip

echo '{
     "admin_server" : {
        "listen_url" : "127.0.0.1:3333",
        "use_tls" : true,
        "cert_path" : "gophish_admin.crt",
        "key_path" : "gophish_admin.key"
      },
      "phish_server" : {
        "listen_url" : "0.0.0.0:443",
        "use_tls" : true,
        "cert_path" : "admin.crt",
        "key_path": "admin.key"
      },
      "db_name" : "sqlite3",
      "db_path" : "gophish.db",
      "migrations_prefix" : "db/db_",
       "contact_address": "",
        "logging": {
                "filename": "",
                "level": ""
        }
}' > config.json

chmod +x /opt/gophish/gophish

cp "/etc/letsencrypt/live/$1/fullchain.pem" "/opt/gophish/admin.crt"
cp "/etc/letsencrypt/live/$1/privkey.pem" "/opt/gophish/admin.key"


echo 'Syslog          yes
UMask           002
UserID          opendkim
KeyTable        /etc/opendkim/key.table
SigningTable        refile:/etc/opendkim/signing.table
ExternalIgnoreList  /etc/opendkim/trusted.hosts
InternalHosts       /etc/opendkim/trusted.hosts
Canonicalization    relaxed/simple
Mode            sv
SubDomains      no
AutoRestart     yes
AutoRestartRate     10/1M
Background      yes
DNSTimeout      5
SignatureAlgorithm  rsa-sha256
OversignHeaders     From
Socket              local:/var/spool/postfix/opendkim/opendkim.sock
PidFile             /var/run/opendkim/opendkim.pid
KeyFile                 /etc/postfix/dkim.key
Selector                mail
SOCKET                  inet:8891@localhost' > /etc/opendkim.conf

echo "Domain     $1" >> /etc/opendkim.conf

chmod u=rw,go=r /etc/opendkim.conf

mkdir /etc/opendkim
mkdir /etc/opendkim/keys
touch /etc/opendkim/trusted.hosts


echo  "*@$1 $(echo "$1" | cut -d . -f 1)" > /etc/opendkim/signing.table
echo "$(echo "$1" | cut -d . -f 1) $1:$2:/etc/opendkim/keys/$1.private"> /etc/opendkim/key.table


echo '127.0.0.1
::1
localhost'  > /etc/opendkim/trusted.hosts
echo $1 >> /etc/opendkim/trusted.hosts
echo $1 | cut -d . -f 1 >> /etc/opendkim/trusted.hosts
echo "SOCKET="inet:8891@localhost"" >> /etc/default/opendkim

mkdir /opt/DKIM
cd /opt/DKIM/
opendkim-genkey -b 2048 -h rsa-sha256 -r -s $2 -d $1 -v
mv *.private $1.private
mv *.txt $1.txt
cp *.private /etc/opendkim/keys/

chown -R opendkim:opendkim /etc/opendkim
chmod go-rw /etc/opendkim/keys
chmod 700 /var/run/opendkim
cat *.txt | cut -d "(" -f2 | cut -d ")" -f1 | tr -d '\040\011\012\015' > dkim.txt
service postfix restart
service opendkim restart
cat dkim.txt
