#!/bin/bash
# hah-engine.sh : install your own server at home
# Licence:  GPLv3
# Author:  © Xavier Cartron (XC) 2013 2014, thuban@yeuxdelibad.net
# http://hg.yeuxdelibad.net/hostathome
VERSION="0.8"

# files
LOGFILE="$CURDIR/hah-$(date +%F-%H-%M).log"
RAPPORT="~/hah-$(date +%F-%H-%M).report"
TEMP="/tmp/hah"
#debian
if [ -d /usr/share/hostathome/stock ]; then
    STOCK="/usr/share/hostathome/stock"
else
    STOCK="$CURDIR/stock"
fi

verbose() {
  set -x
  "$@"
  set +x
}

installapt() {
    if [[ ! -e /etc/debian_version ]]; then
        die "Il semblerait que vous n'utilisez pas une debian"
    fi
    verbose apt-get -y install "$@" 
}

# Procédure de traitement des configs (merci MrFreez)
# Write error message on stderr and die
die() {
  echo "$@" >&2
  exit 1
}

# Write to stdout the process of template
process() {
  [[ -f "${1}" ]] || die "load() : \"${1}\" don't exist !"
  while read ; do
    if [[ "${REPLY}" =~ \$\{.*\} ]] ; then
      line=$(echo "${REPLY}" | sed 's@\([`"\\!]\)@\\\1@g')
      line=$(echo "${line}" | sed 's@\($[^{]\)@\\\1@g')
      lineout="$(eval "echo \"${line}\"")"
      [[ ! -z "${lineout}" ]] && echo "${lineout}"
    else
      echo "${REPLY}"
    fi
  done < "${1}"
}

rapport() {
  if [[ 0 -eq "$#" ]] ; then
    cat | tee -a "$RAPPORT"
  else
    echo "$@" | tee -a "$RAPPORT"
  fi
}

assign () {
  read -rd '' "$1"
}

# Prepare installation
dopreparation() {
    apt-get update
    apt-get upgrade
    apt-get dist-upgrade
}

createwwwdata() {
    verbose groupadd www-data 
    verbose usermod -a -G www-data www-data 
}

dosslcert() {
# dosslcert <Nom_de_domaine> 
    installapt openssl ssl-cert
    # Nom de domaine
    local NOMDHOTE="$1"
    if [ -z "$NOMDHOTE" ]; then
        die "Pas de nom d'hôte"
    fi

    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -subj "/C=${SSLCOUNTRY}/ST=${SSLSTATE}/L=${SSLLOCATION}/O=${SSLORGANISATION}/CN=${SSLCOMMONNAME}/emailAddress=${SSLEMAILADDRESS}/" \
        -keyout /etc/ssl/private/"$NOMDHOTE".pem \
        -out /etc/ssl/private/"$NOMDHOTE".pem

    chown root:root /etc/ssl/private/"$NOMDHOTE".pem
    chmod 600 /etc/ssl/private/"$NOMDHOTE".pem
}

prepwebserver() {
    # prepwebserver <php 0:oui, 1:non> </dossier/contenant/le/site> <nomdhote>
    if [ $1 -eq 0 ]; then
        cp -v "$STOCK/nginx-php.conf" /etc/nginx/conf.d/php
    fi
    
    if [ -n "$2" ]; then
        createwwwdata
        mkdir -p "/$2/"
    fi

    if [ -n "$3" ]; then
        dosslcert "$3"
        SSLCERT="
        ssl_certificate /etc/ssl/private/$3.pem;
        ssl_certificate_key /etc/ssl/private/$3.pem;"
    fi
}

finwebserver() {
    #finwebserver <php : 0 oui, 1 non> <dossier/contenant/le/site> 
    if [ -n "$2" ]; then
        chown -R www-data:www-data "/$2"
    fi
    service nginx restart
    if [ $1 -eq 0 ]; then
        service php5-fpm restart
    fi
}

phpuploadlimit() {
    # Limite d'upload
    sed -i "s/upload_max_filesize.*$/upload_max_filesize = 1000M/g" /etc/php5/fpm/php.ini
    sed -i "s/post_max_size.*$/post_max_size = 1000M/g" /etc/php5/fpm/php.ini
}

preppgsql() {
    # preppgsql <password>
    local PW="$1"
    su postgres -c psql << EOF
ALTER USER postgres WITH PASSWORD '$PW';
CREATE USER "www-data" WITH PASSWORD '$PW';
\q
EOF
    /etc/init.d/postgresql restart
}

createdbpgsql() {
    #createdbpgsql <nom de la base> <mot de passe>
    su postgres -c psql << EOF
\connect template1
CREATE DATABASE "$1" WITH ENCODING 'UTF-8';
GRANT ALL PRIVILEGES ON DATABASE "$1" TO "www-data";
ALTER DATABASE "$1" OWNER TO "www-data";
\q
EOF
    /etc/init.d/postgresql restart
}

# Function to install http server
dohttp_nginx() {
    # dohttp_nginx <nom d'hote> </emplacement/du/site> <php 0 pour oui/1 pour non> <SSL (1:N, 2:O, 3:O avec redirection)>
    echo "-> installation du serveur http"
    installapt nginx
    local INDEXPAGE="index.html"
    local PORT="80"
    local REWRITEHTTPS=""
    local NOMDHOTE="$1"
    local ROOTOFHTTP="$2"
    local DOPHP="$3"
    local SSL="$4"

    # Nom de domaine
    local domaineconf="/etc/nginx/conf.d/${NOMDHOTE}.conf"
    cp -v "$STOCK/nginx-server.conf" "${domaineconf}"

    # PHP
    if [ $DOPHP -eq 0 ]; then
        echo "-> On installe php"
        installapt php5 php-apc php5-fpm
        INDEXPAGE="index.html index.php"
        cp -v "$STOCK/nginx-php.conf" /etc/nginx/conf.d/php
        DOPHP="include /etc/nginx/conf.d/php;"
    fi

    # SSL
    case $SSL in
        "2") echo "https"
            dosslcert "$NOMDHOTE"
            PORT="443 ssl"
            SSL="
    ssl_certificate /etc/ssl/private/$NOMDHOTE.pem;
    ssl_certificate_key /etc/ssl/private/$NOMDHOTE.pem;"
            ;;
        "3") echo "http -> https"
            dosslcert "$NOMDHOTE"
            PORT="443 ssl"
            SSL="
    ssl_certificate /etc/ssl/private/$NOMDHOTE.pem;
    ssl_certificate_key /etc/ssl/private/$NOMDHOTE.pem;"
            assign REWRITEHTTPS <<EOF
server {
    listen 80;
    server_name $NOMDHOTE;
    rewrite ^ https://\$server_name\$request_uri? permanent;  
}
EOF
            ;;
        *) echo "http sans SSL" 
            SSL=""
            ;;
    esac

    process "$STOCK/nginx-server.conf" > "$domaineconf"

    service nginx restart
    rapport <<EOF
nginx installé et configuré
    * Pensez à ouvrir le(s) port(s) utilisé(s) (80 et 443 si ssl)
    * Créez le dossier \"/$ROOTOFHTTP\" et placez-y les fichiers de votre site"
    * Site : http://nginx.org
EOF
}

dopostfix() {
# dopostfix <nom d'hote> <domaine>
    echo -e "installation du serveur de courriel"
    local NOMDHOTE="$1"
    local DOMAIN="$2"
    
    rapport <<EOF
Un serveur de courriel a besoin de 2 champs DNS :
    - Un champ de type A : mail.server.net . C'est le nom d'hôte vous permettant ensuite de récupérer vos mails.
    - Un champ de type MX pointant vers le A précédent. C'est en général le nom de domaine porté dans les adresses : machin@domain.net
Ainsi, lorqu'on vous écrit à machin@domain.net, c'est directement relié à l'hôte mail.server.net
EOF

    installapt postfix dovecot-imapd postgrey libsasl2-2 sasl2-bin opendkim opendkim-tools

    # SASL
    sed -i "s/START=no/START=yes/" /etc/default/saslauthd
    service saslauthd restart

    # DOVECOT
    cp -v "$STOCK/dovecot.conf" /etc/dovecot
    service dovecot restart

    # POSTFIX
    # Edition de /etc/hosts
    echo "127.0.0.1     $NOMDHOTE" >> /etc/hosts
    echo "$NOMDHOTE" > /etc/mailname
    #hostname $NOMDHOTE

    process "$STOCK/postfix_main.cf" > "/etc/postfix/main.cf"
    process "$STOCK/postfix_master.cf" > "/etc/postfix/master.cf"

    service postfix restart

    # DKIM
    mkdir -p /etc/dkim
    opendkim-genkey -D /etc/dkim -d "$DOMAIN" -s mail
    chown opendkim:opendkim -R /etc/dkim
    process "$STOCK/opendkim.conf" > /etc/opendkim.conf

    echo 'SOCKET="inet:8891:localhost"' >> /etc/default/opendkim

    rapport <<EOF
Configurez vos champs DNS :
Ajoutez un champ DKIM ou TXT contenant le contenu de /etc/dkim/mail.txt suivant:
    ---
mail._domainkey.$DOMAIN"
$(</etc/dkim/mail.txt)
    ---
Ce contenu sera présent dans le fichier de logs et d'information $RAPPORT
EOF

    service opendkim restart

    rapport << EOF
---
Serveur de courriel installé et configuré.
Pensez à ouvrir les ports utilisés (25 ou 587,143,993)" 

Pour lire votre courrier, installez un webmail, 
ou bien avec un client de messagerie tel que thunderbird, claws-mail, 
ou encore récupérez-le avec un programme tel que fdm ou fetchmail en utilisant
l'adresse de votre serveur $DOMAIN.

Pour ajouter une nouvelle adresse de courriel, créez un nouvel utilisateur. 
Par exemple, pour avoir toto@$DOMAIN, créez l'utilisateur toto avec la commande
    adduser toto

* Site de postfix : http://postfix.org
EOF
}

dosquirrelmail() {
# dosquirrelmail <nom d'hote>
    local domaineconf="/etc/nginx/conf.d/squirrelmail.conf"
    local NOMDHOTE="$1"
    local SSLCERT=""
    installapt squirrelmail squirrelmail-locales php5-fpm php5 php5-common squirrelmail-quicksave squirrelmail-spam-buttons squirrelmail-viewashtml nginx

    cp -v "$STOCK/squirrelmail_config.php" /etc/squirrelmail/
    prepwebserver 0 "/$ROOTOFHTTP" "$NOMDHOTE"
    process "$STOCK/nginx-squirrelmail.conf" > "$domaineconf"
    finwebserver 0 

    rapport << EOF
        ---
Le webmail squirrelmail est installé.
Pour ajouter un nouveau compte, lancez la commande :
    adduser --shell=/bin/false nouvelUtilisateur

    * Site : http://squirrelmail.org
EOF
}

dosftp() {
    # dosftp <port> </repertoire/de/chroot> <utilisateur> <partage http (1 ou 0)>
    installapt openssh-server
    addgroup sftpusers

    local PORT="$1"
    local CHROOTDIR="$2"
    local USER="$3"
    local HTTPSHARE="$4"

    # chroot
    mkdir -p "$CHROOTDIR/home"
    chown root:root "$CHROOTDIR"

    # utilisateurs
    mkdir -p /usr/local/bin
    process "$STOCK/addsftpuser.sh" > /usr/local/bin/addsftpuser
    chmod +x /usr/local/bin/addsftpuser

    #Commenté car il faut indiquer le mot de passe -> pas automatique
    #for U in $(echo "$USER"|sed "s; ;\n;g"); do
    #    /usr/local/bin/addsftpuser $U
    #done

    # Partage avec http
    if [ "$HTTPSHARE" = "0" ]; then
        mkdir -p /etc/nginx/conf.d/hostathome
        process "$STOCK/nginx-sftp.conf" > /etc/nginx/conf.d/hostathome/sftp.conf
        service nginx restart
    fi
                
    process "$STOCK/sshd_config" > "/etc/ssh/sshd_config"

    service ssh restart

    rapport << EOF
---
sftp installé et configuré
Pensez à ouvrir le port $PORT.
Vous pourrez désormais ajouter un nouvel utilisateur sftp avec la commande 'addsftpuser <utilisateur>'
EOF
}

dosecurite() {
    installapt fail2ban portsentry rkhunter

    #fail2ban
    if ! [ -f /etc/fail2ban/jail.local ]; then
        cp -v "$STOCK"/jail.local /etc/fail2ban/jail.local
        cp -v "$STOCK"/filter/nginx-404.conf /etc/fail2ban/filter.d/
        cp -v "$STOCK"/filter/nginx-proxy.conf /etc/fail2ban/filter.d/
        cp -v "$STOCK"/filter/nginx-noscript.conf /etc/fail2ban/filter.d/
        cp -v "$STOCK"/filter/nginx-auth.conf /etc/fail2ban/filter.d/
        cp -v "$STOCK"/filter/nginx-login.conf /etc/fail2ban/filter.d/

        #ssh
        if [ -f /etc/ssh/sshd_config ]; then
            SSHPORT="$(grep 'Port' /etc/ssh/sshd_config | cut -d' ' -f 2-)"
            sed -i "s/port.*= ssh/port  = ssh,$SSHPORT/g" /etc/fail2ban/jail.local
        fi
    fi

    service fail2ban restart

    # portsentry default configuration
    cp -v "$STOCK"/portsentry.conf /etc/portsentry/portsentry.conf
    sed -i 's/="tcp"/="atcp"/' /etc/default/portsentry
    sed -i 's/="udp"/="audp"/' /etc/default/portsentry

    service portsentry restart

    # rkhunter
    sed -i 's;#ALLOWHIDDENDIR="/dev/.udev";ALLOWHIDDENDIR="/dev/.udev";' /etc/rkhunter.conf
    sed -i 's;#ALLOWHIDDENDIR="/dev/.static";ALLOWHIDDENDIR="/dev/.static";' /etc/rkhunter.conf
    sed -i 's;MAIL-ON-WARNING="";MAIL-ON-WARNING="root@localhost";' /etc/rkhunter.conf
    echo "SCRIPTWHITELIST=/usr/bin/unhide.rb" >> /etc/rkhunter.conf

    mkdir -p /etc/apt/apt.conf
    cp -v "$STOCK/apt-rkhunter" /etc/apt/apt.conf/98-rkhunter

    if [ -f /etc/ssh/sshd_config ]; then
        echo PermitRootLogin no >> /etc/ssh/sshd_config
    fi
}

doxmpp() {
    # doxmpp <nom d'hote>
    local NOMDHOTE="$1"
    local SSLCONFIG=""
    local prosodyconf='/etc/prosody/prosody.cfg.lua'

    rapport << EOF
Pour que tout fonctionne bien, il serait bon de créer les champs DNS suivants : 
- Un champ de type A : xmpp.mondomaine.com
- Des champs de type SRV vers xmpp.mondomaine.com comme ceci : 
    _xmpp-client._tcp.domaine.net. 18000 IN SRV 0 5 5222 xmpp.domaine.net.
    _xmpp-server._tcp.domaine.net. 18000 IN SRV 0 5 5269 xmpp.domaine.net.
EOF

    installapt prosody liblua5.1-sec

    cp -v "$STOCK/prosody.cfg.lua" "${prosodyconf}"

    # ssl
    dosslcert "$NOMDHOTE"
    local SSLCONFIG="\"/etc/ssl/private/$NOMDHOTE.pem\""

    process "$STOCK/prosody.cfg.lua" > "$prosodyconf"

    service prosody restart

    rapport << EOF
---
prosody installé et configuré
Pensez à ouvrir les ports 5222 et 5269.

* Site : http://prosody.im
EOF
}

doowncloud(){
# doowncloud <nom d'hote> </repertoire/pour/owncloud> 
    local domaineconf="/etc/nginx/conf.d/owncloud.conf"
    local NOMDHOTE="$1"
    local ROOTOFHTTP="$2"
    local SSLCERT=""

    installapt nginx php5 php5-gd php-xml-parser php5-intl curl libcurl3 php5-curl openssl ssl-cert php5-dev php5-fpm php5-cli php5-sqlite php5-common php5-cgi sqlite php-pear php-apc bzip2 libav-tools php5-mcrypt php5-imagick php5-json bzip2

    prepwebserver 0 "/$ROOTOFHTTP" "$NOMDHOTE"
    process "$STOCK/nginx-owncloud.conf" > "${domaineconf}"
    phpuploadlimit

    # owncloud
    echo -e "Téléchargeons le dernier owncloud"
    wget -c -O $TEMP/lastowncloud.tar.bz2 "http://download.owncloud.org/community/owncloud-7.0.1.tar.bz2"
    tar xvjf $TEMP/lastowncloud.tar.bz2 -C "/$ROOTOFHTTP"
    mkdir -p "/$ROOTOFHTTP/owncloud/"{apps,data,config}
    chown -R www-data:www-data "/$ROOTOFHTTP/owncloud/"{apps,data,config}

    service nginx restart
    service php5-fpm restart

    rapport << EOF
---
owncloud installé"
Ouvrez dans un navigateur https://$NOMDHOTE pour terminer la configuration

* Site : http://owncloud.org
EOF
}

dodropcenter(){
    #dodropcenter <nom d'hote> </repertoire/contenant/dropcenter>
    local domaineconf="/etc/nginx/conf.d/dropcenter.conf"
    local NOMDHOTE="$1"
    local ROOTOFHTTP="$2"
    local SSLCERT=""

    installapt nginx php5 openssl ssl-cert php5-fpm php-apc  unzip

    prepwebserver 0 "/$ROOTOFHTTP" "$NOMDHOTE"
    process "$STOCK/nginx-dropcenter.conf" > "${domaineconf}"
    phpuploadlimit

    # dropcenter
    echo -e "Téléchargeons le dernier dropcenter"
    wget -O $TEMP/lastdropcenter.zip "https://github.com/ldleman/dropcenter/archive/master.zip"
    unzip $TEMP/lastdropcenter.zip -d "/$ROOTOFHTTP"

    finwebserver 0 "/$ROOTOFHTTP" 
    chmod 755 "/$ROOTOFHTTP/dropcenter-master/uploads"

    rapport << EOF
---
dropcenter installé
Ouvrez dans un navigateur https://$NOMDHOTE pour terminer la configuration

Si vous souhaitez augmenter la taille limite des fichiers chargés, modifiez la ligne suivante dans le fichier ${domaineconf}
    client_max_body_size 1000M;
ainsi que dans le fichier /etc/php5/fpm/php.ini
    upload_max_filesize = 1000M
    post_max_size = 1000M;

* Site : http://projet.idleman.fr/dropcenter/
EOF
}

dopluxml(){
    #dopluxml <nom d'hote> </dossier/contenant/pluxml>
    local domaineconf="/etc/nginx/conf.d/pluxml.conf"
    local NOMDHOTE="$1"
    local ROOTOFHTTP="$2"
    local SSLCERT=""

    installapt nginx php5 openssl ssl-cert php5-fpm php-apc php5-gd unzip
    prepwebserver 0 "/$ROOTOFHTTP" "$NOMDHOTE"
    process "$STOCK/nginx-pluxml.conf" > "${domaineconf}"

    # pluxml
    echo -e "Téléchargeons le dernier pluxml"
    wget -O $TEMP/lastpluxml.zip "http://telechargements.pluxml.org/download.php"
    unzip $TEMP/lastpluxml.zip -d "/$ROOTOFHTTP"

    finwebserver 0 "/$ROOTOFHTTP" 

    rapport << EOF
---
pluxml installé
Ouvrez dans un navigateur https://$NOMDHOTE pour terminer la configuration

Site : http://www.pluxml.org/
EOF
}

doblogotext(){
    #doblogotext <nom d'hote> </dossier/contenant/blogotext>
    local domaineconf="/etc/nginx/conf.d/blogotext.conf"
    local NOMDHOTE="$1"
    local ROOTOFHTTP="$2"
    local SSLCERT=""

    installapt nginx php5 openssl ssl-cert php5-fpm php-apc php5-gd unzip sqlite php5-sqlite
    prepwebserver 0 "/$ROOTOFHTTP" "$NOMDHOTE"
    process "$STOCK/nginx-blogotext.conf" > "${domaineconf}"
    phpuploadlimit

    # blogotext
    echo "Téléchargeons le dernier blogotext"
    wget -O $TEMP/lastblogotext.zip "http://lehollandaisvolant.net/blogotext/blogotext.zip"
    unzip $TEMP/lastblogotext.zip -d "/$ROOTOFHTTP"

    finwebserver 0 "/$ROOTOFHTTP" 

    rapport << EOF
---
blogotext installé
Ouvrez dans un navigateur https://$NOMDHOTE pour terminer la configuration

* Site : http://lehollandaisvolant.net/blogotext/
EOF
}

dottrss(){
    # dottrss <nom d'hote> </dossier/contenant/ttrss> <mot de passe de la base de donnée postgresql>
    local domaineconf="/etc/nginx/conf.d/ttrss.conf"
    local NOMDHOTE="$1"
    local ROOTOFHTTP="$2"
    local SSLCERT=""
    local BDDPW="$3"

    installapt nginx php5 openssl ssl-cert php5-fpm php-apc php-pear php5-pgsql postgresql postgresql-client postgresql-client-common php-db php5-curl php5-gd
    prepwebserver 0 "/$ROOTOFHTTP" "$NOMDHOTE"

    process "$STOCK/nginx-ttrss.conf" > "${domaineconf}"

    # ttrss
    echo "Téléchargeons le dernier tinytinyrss"
    wget -c -O $TEMP/ttrss.tar.gz "https://github.com/gothfox/Tiny-Tiny-RSS/archive/1.12.tar.gz"
    mkdir -p $TEMP/ttrss
    tar xvf $TEMP/ttrss.tar.gz -C $TEMP/ttrss
    mv $TEMP/ttrss/Tiny-Tiny-RSS-*/* "/$ROOTOFHTTP"

    # postgresql config
    preppgsql "$BDDPW"
    createdbpgsql "ttrss" "$BDDPW"

    finwebserver 0 "/$ROOTOFHTTP"

    rapport << EOF
---
Tiny Tiny RSS installé
Ouvrez dans un navigateur https://$NOMDHOTE

Database server hostname est : localhost
Le nom de la base postgresql est : ttrss
Le nom d'utilisateur à renseigner est : www-data

* Site : http://tt-rss.org/redmine/projects/tt-rss/wiki
EOF
}

dokriss() {
    # dokriss <nom d'hote> </repertoire/contenant/kriss>
    echo "installation de kriss"
    local domaineconf="/etc/nginx/conf.d/kriss.conf"
    local NOMDHOTE="$1"
    local ROOTOFHTTP="$2"
    local SSLCERT=""

    installapt php5 php-apc php5-fpm php5-curl nginx openssl ssl-cert
    prepwebserver 0 "/$ROOTOFHTTP" "$NOMDHOTE"
    process "$STOCK/nginx-kriss.conf" > "${domaineconf}"

    wget -O "/$ROOTOFHTTP/index.php" http://raw.github.com/tontof/kriss_feed/master/index.php

    finwebserver 0 "/$ROOTOFHTTP" 

    rapport << EOF
---
kriss installé
Ouvrez dans un navigateur http://$NOMDHOTE pour terminer la configuration

* Site : https://github.com/tontof/kriss_feed
EOF
}

dotor() {
    # dotor <nickname> <bwrate> <bwburst> <pseudo> <email>
    echo -e "installation de tor"
    installapt tor

    local NICKNAME="$1"
    local BWRATE="$2"
    local BWBURST="$3"
    local PSEUDO="$4"
    local EMAIL="$5"


    process "$STOCK/torrc" > /etc/tor/torrc
    service tor restart

    rapport << EOF
---
Tor installé
Pensez à ouvrir le port 9001

* Site : https://www.torproject.org/
EOF
}

dopico(){
    # dopico <nom d'hote> </dossier/contenant/pico> <mot de passe>
    local domaineconf="/etc/nginx/conf.d/pico.conf"
    local NOMDHOTE="$1"
    local ROOTOFHTTP="$2"
    local PICO_PASSWD="$(echo -n "${3}" |sha1sum |cut -d' ' -f1)"
    local SSLCERT=""

    installapt nginx php5 openssl ssl-cert php5-fpm php-apc unzip 
    prepwebserver 0 "/$ROOTOFHTTP" "$NOMDHOTE"
    process "$STOCK/nginx-pico.conf" > "${domaineconf}"

    # pico
    echo "Téléchargeons le dernier pico"
    wget -c -O $TEMP/pico.zip "https://github.com/gilbitron/Pico/archive/master.zip"
    unzip $TEMP/pico.zip -d $TEMP/pico
    mv $TEMP/pico/Pico-master/* "/$ROOTOFHTTP"

    echo "Téléchargement du plugin pico_editor"
    wget -c -O $TEMP/pico_editor.zip "https://github.com/gilbitron/Pico-Editor-Plugin/archive/master.zip"

    mkdir -p "/$ROOTOFHTTP/plugins/pico_editor"
    unzip $TEMP/pico_editor.zip -d $TEMP/pico_editor
    mv $TEMP/pico_editor/Pico-Editor-Plugin-master/* "/$ROOTOFHTTP/plugins/pico_editor/"
    process "$STOCK/pico_editor_config" > "/$ROOTOFHTTP/plugins/pico_editor/pico_editor_config.php"

    finwebserver 0 "/$ROOTOFHTTP" 

    rapport << EOF
---
pico installé
Ouvrez dans un navigateur https://$NOMDHOTE/admin pour poster votre premier message 
et consultez votre site à https://$NOMDHOTE .

* Site : http://pico.dev7studios.com/
EOF
}

doroundcube(){
    #doroundcube <nom d'hote> </dossier/contenant/roundcube> 
    local domaineconf="/etc/nginx/conf.d/roundcube.conf"
    local NOMDHOTE="$1"
    local ROOTOFHTTP="$2"
    local SSLCERT=""

    installapt nginx php5 php-pear php5-sqlite openssl ssl-cert php5-fpm php-apc php5-mcrypt php5-intl php5-dev php5-gd aspell libmagic-dev sqlite

    prepwebserver 0 "/$ROOTOFHTTP" "$NOMDHOTE"
    process "$STOCK/nginx-roundcube.conf" > "${domaineconf}"

    # roundcube
    echo "Téléchargeons le dernier roundcube"
    wget -c -O $TEMP/roundcube.tar.gz "http://sourceforge.net/projects/roundcubemail/files/roundcubemail/1.0.0/roundcubemail-1.0.0.tar.gz/download"
    mkdir -p $TEMP/roundcubetmp
    tar xvf $TEMP/roundcube.tar.gz -C $TEMP/roundcubetmp
    mv $TEMP/roundcubetmp/roundcubemail*/* "/$ROOTOFHTTP"

    finwebserver 0 "/$ROOTOFHTTP" 

    rapport << EOF
---
roundcube installé
Ouvrez dans un navigateur https://$NOMDHOTE/installer pour terminer l'installation

Après l'installation, supprimez le dossier $ROOTOFHTTP/installer avec la commande : 
	rm -r $ROOTOFHTTP/installer
* Site : http://roundcube.net
EOF

}

doroundcube-pgsql(){
    # doroundcube-pgsql <nom d'hote> </dossier/contenant/roundcube> <Mot de passe pour la base de données>
    local domaineconf="/etc/nginx/conf.d/roundcube.conf"
    local NOMDHOTE="$1"
    local ROOTOFHTTP="$2"
    local SSLCERT=""
    local BDDPW="$3"

    installapt nginx php5 php-pear openssl ssl-cert php5-fpm php-apc php5-mcrypt php5-intl php5-dev php5-gd aspell libmagic-dev php5-pgsql postgresql postgresql-client postgresql-client-common 

    prepwebserver 0 "/$ROOTOFHTTP" "$NOMDHOTE"
    process "$STOCK/nginx-roundcube.conf" > "${domaineconf}"

    # roundcube
    echo "Téléchargeons le dernier roundcube"
    wget -c -O $TEMP/roundcube.tar.gz "http://sourceforge.net/projects/roundcubemail/files/roundcubemail/1.0.0/roundcubemail-1.0.0.tar.gz/download"
    mkdir -p $TEMP/roundcubetmp
    tar xvf $TEMP/roundcube.tar.gz -C $TEMP/roundcubetmp
    mv $TEMP/roundcubetmp/roundcubemail*/* "/$ROOTOFHTTP"

    # postgresql config
    preppgsql "$BDDPW"
    createdbpgsql "roundcubemail" "$BDDPW"

    finwebserver 0 "/$ROOTOFHTTP" 

    rapport << EOF
---
roundcube installé
Ouvrez dans un navigateur https://$NOMDHOTE/installer pour terminer l'installation

Après l'installation, supprimez le dossier $ROOTOFHTTP/installer avec la commande : 
	rm -r $ROOTOFHTTP/installer

Database server hostname est : localhost
Le nom de la base postgresql est : roundcubemail
Le nom d'utilisateur à renseigner est : www-data

* Site : http://roundcube.net
EOF
}


dorainloop(){
    # dorainloop <nom d'hote> </dossier/contenant/rainloop> 
    local domaineconf="/etc/nginx/conf.d/rainloop.conf"
    local NOMDHOTE="$1"
    local ROOTOFHTTP="$2"
    local SSLCERT=""

    installapt nginx php5 php-pear php5-sqlite openssl ssl-cert php5-fpm php-apc php5-curl unzip
    prepwebserver 0 "/$ROOTOFHTTP" "$NOMDHOTE"
    process "$STOCK/nginx-rainloop.conf" > "${domaineconf}"

    # rainloop
    echo "Téléchargeons le dernier rainloop"
    wget -c -O $TEMP/rainloop.zip "http://repository.rainloop.net/v2/webmail/rainloop-latest.zip"
    mkdir -p $TEMP/rainlooptmp
    unzip $TEMP/rainloop.zip -d $TEMP/rainlooptmp
    mv $TEMP/rainlooptmp/rainloop-webmail-master/* "/$ROOTOFHTTP"

    finwebserver 0 "/$ROOTOFHTTP" 

    rapport << EOF
---
rainloop installé
Ouvrez dans un navigateur https://$NOMDHOTE?admin pour terminer la configuration.
Par défaut, le nom d'utilisateur est "admin"
le mot de passe est "12345".

Ouvrez dans un navigateur https://$NOMDHOTE pour consulter l'interface.

* Site : http://rainloop.net
EOF

}

dowallabag(){
    # dowallabag <nom d'hote> </dossier/contenant/wallabag> 
    local domaineconf="/etc/nginx/conf.d/wallabag.conf"
    local NOMDHOTE="$1"
    local ROOTOFHTTP="$2"
    local SSLCERT=""

    installapt nginx php5 php5-sqlite openssl ssl-cert php5-fpm php-apc php5-curl unzip php5-mcrypt php5-tidy php5-cli curl
    prepwebserver 0 "/$ROOTOFHTTP" "$NOMDHOTE"
    process "$STOCK/nginx-wallabag.conf" > "${domaineconf}"

    # wallabag
    echo "Téléchargeons le dernier wallabag"
    wget -c -O $TEMP/wallabag.zip "http://wllbg.org/latest"
    mkdir -p $TEMP/wallabagtmp
    unzip $TEMP/wallabag.zip -d $TEMP/wallabagtmp
    mv $TEMP/wallabagtmp/wallabag-*/* "/$ROOTOFHTTP"

    # Twig
    cd "$ROOTOFHTTP"
    curl -s http://getcomposer.org/installer | php
    php composer.phar install

    finwebserver 0 "/$ROOTOFHTTP" 

    rapport << EOF
---
wallabag installé
Ouvrez dans un navigateur https://$NOMDHOTE pour terminer l'installation

* Site : https://www.wallabag.org
* Applications : https://www.wallabag.org/downloads/
EOF

}

dojirafeau(){
# dojirafeau <nom d'hote> </dossier/contenant/jirafeau> 
local domaineconf="/etc/nginx/conf.d/jirafeau.conf"
    local NOMDHOTE="$1"
    local ROOTOFHTTP="$2"
    local DOCROOT="$3"
    local SSLCERT=""

    installapt nginx php5 openssl ssl-cert php5-fpm php-apc 
    prepwebserver 0 "/$ROOTOFHTTP" "$NOMDHOTE"
    process "$STOCK/nginx-jirafeau.conf" > "${domaineconf}"
    phpuploadlimit

    # jyraphe
    echo "Téléchargeons le dernier jirafeau"
    mkdir -p $TEMP/jirafeau
    wget -c -O $TEMP/jirafeau.zip "https://gitlab.com/mojo42/Jirafeau/repository/archive.zip"
    unzip $TEMP/jirafeau.zip -d $TEMP/jirafeau
    
    mv $TEMP/jirafeau/Jirafeau.git/* "/$ROOTOFHTTP"

    chown -R www-data:www-data "/$ROOTOFHTTP"

    service nginx restart
    service php5-fpm restart

    rapport << EOF
---
jirafeau installé
Ouvrez dans un navigateur https://$NOMDHOTE/install.php
pour terminer l'installation

* Site : https://gitlab.com/mojo42/Jirafeau/wikis/home
EOF
}



dojyraphe(){
    # dojyraphe <nom d'hote> </dossier/contenant/jyraphe> </dossier/contenant/les/documents>
    local domaineconf="/etc/nginx/conf.d/jyraphe.conf"
    local NOMDHOTE="$1"
    local ROOTOFHTTP="$2"
    local DOCROOT="$3"
    local SSLCERT=""

    installapt nginx php5 openssl ssl-cert php5-fpm php-apc 
    prepwebserver 0 "/$ROOTOFHTTP" "$NOMDHOTE"
    process "$STOCK/nginx-jyraphe.conf" > "${domaineconf}"
    phpuploadlimit

    # jyraphe
    echo "Téléchargeons le dernier jyraphe"
    mkdir -p $TEMP/jyraphe
    wget -c -O $TEMP/jyraphe.tar.gz "http://download.gna.org/jyraphe/jyraphe-0.5.tar.gz"
    tar xvf $TEMP/jyraphe.tar.gz -C $TEMP/jyraphe
    
    mv $TEMP/jyraphe/jyraphe/pub/* "/$ROOTOFHTTP"
    rm "/$ROOTOFHTTP/install.php"

    mkdir -p "$DOCROOT/"{files,links,trash}

    process "$STOCK/jyraphe_config.php" > "/$ROOTOFHTTP/lib/config.local.php"

    chown -R www-data:www-data "/$ROOTOFHTTP"
    chown -R www-data:www-data "/$DOCROOT"

    service nginx restart
    service php5-fpm restart

    rapport << EOF
---
jyraphe installé
Ouvrez dans un navigateur https://$NOMDHOTE

* Site : http://home.gna.org/jyraphe/
EOF
}

dozerobin(){
    # dozerobin <nom d'hote> </dossier/contenant/zerobin>
    local domaineconf="/etc/nginx/conf.d/zerobin.conf"
    local NOMDHOTE="$1"
    local ROOTOFHTTP="$2"

    installapt nginx php5 php5-fpm php-apc php5-gd unzip
    prepwebserver 0 "/$ROOTOFHTTP" "$NOMDHOTE"
    process "$STOCK/nginx-zerobin.conf" > "${domaineconf}"

    # zerobin
    echo "Téléchargeons le dernier zerobin"
    wget -c -O $TEMP/zerobin.zip "https://github.com/sebsauvage/ZeroBin/archive/master.zip"
    mkdir -p $TEMP/zerobin
    unzip $TEMP/zerobin.zip -d $TEMP/zerobin
    mv $TEMP/zerobin/ZeroBin-master/* "/$ROOTOFHTTP"
    
    finwebserver 0 "/$ROOTOFHTTP" 

    rapport << EOF
---
ZeroBin installé
Ouvrez dans un navigateur https://$NOMDHOTE

* Site : http://sebsauvage.net/wiki/doku.php?id=php:zerobin
EOF
}

doshaarli(){
    # doshaarli <nom d'hote> </dossier/contenant/shaarli>
    local domaineconf="/etc/nginx/conf.d/shaarli.conf"
    local NOMDHOTE="$1"
    local ROOTOFHTTP="$2"
    local SSLCERT=""

    installapt nginx php5 openssl ssl-cert php5-fpm php-apc unzip
    prepwebserver 0 "/$ROOTOFHTTP" "$NOMDHOTE"
    process "$STOCK/nginx-shaarli.conf" > "${domaineconf}"

    # shaarli
    echo "Téléchargeons le dernier shaarli"
    wget -c -O $TEMP/shaarli.zip "https://github.com/sebsauvage/Shaarli/archive/master.zip"
    mkdir -p $TEMP/shaarli
    unzip $TEMP/shaarli.zip -d $TEMP/shaarli
    mv $TEMP/shaarli/Shaarli-master/* "/$ROOTOFHTTP"
    
    finwebserver 0 "/$ROOTOFHTTP" 

    rapport << EOF
---
Shaarli installé
Ouvrez dans un navigateur https://$NOMDHOTE

* Site : http://sebsauvage.net/wiki/doku.php?id=php:shaarli
EOF
}

dojotter(){
    # dojotter <nom d'hote> </dossier/contenant/jotter>
    local domaineconf="/etc/nginx/conf.d/jotter.conf"
    local NOMDHOTE="$1"
    local ROOTOFHTTP="$2"
    local SSLCERT=""

    installapt nginx php5 openssl ssl-cert php5-fpm php-apc unzip
    prepwebserver 0 "/$ROOTOFHTTP" "$NOMDHOTE"
    process "$STOCK/nginx-jotter.conf" > "${domaineconf}"

    # jotter
    echo "Téléchargeons le dernier jotter"
    wget -c -O $TEMP/jotter.zip "https://github.com/yosko/jotter/archive/master.zip"
    mkdir -p $TEMP/jotter
    unzip $TEMP/jotter.zip -d $TEMP/jotter
    mv $TEMP/jotter/jotter-master/* "/$ROOTOFHTTP"
    
    finwebserver 0 "/$ROOTOFHTTP" 
    mkdir -p "/$ROOTOFHTTP/data"
    mkdir -p "/$ROOTOFHTTP/cache"
    chmod a+w "/$ROOTOFHTTP/data"
    chmod a+w "/$ROOTOFHTTP/cache"

    rapport << EOF
---
Jotter installé
Ouvrez dans un navigateur https://$NOMDHOTE

* Site : https://github.com/yosko/jotter
EOF
}



donononsenseforum(){
    # donononsenseforum <nom d'hote> </dossier/contenant/nononsenseforum>
    local domaineconf="/etc/nginx/conf.d/nononsenseforum.conf"
    local NOMDHOTE="$1"
    local ROOTOFHTTP="$2"
    local SSLCERT=""

    installapt nginx php5 openssl ssl-cert php5-fpm php-apc unzip

    prepwebserver 0 "/$ROOTOFHTTP" "$NOMDHOTE"
    process "$STOCK/nginx-nononsenseforum.conf" > "${domaineconf}"

    # nononsenseforum
    echo "Téléchargeons le dernier nononsenseforum"
    wget -c -O $TEMP/nononsenseforum.zip "https://github.com/Kroc/NoNonsenseForum/archive/master.zip"
    mkdir -p $TEMP/nononsenseforum
    unzip $TEMP/nononsenseforum.zip -d $TEMP/nononsenseforum
    mv $TEMP/nononsenseforum/NoNonsenseForum-master/* "/$ROOTOFHTTP/nnsf"

    # Config users without htaccess
    cp -v "$STOCK/nnsf-config.php" "/$ROOTOFHTTP/nnsf/config.php"
    mkdir -p "/$ROOTOFHTTP/users"

    finwebserver 0 "/$ROOTOFHTTP" 

    rapport << EOF
---
NoNonsenseForum installé
Ouvrez dans un navigateur https://$NOMDHOTE

Vous pouvez le configurer en modifiant le fichier config.php présent dans $ROOTOFHTTP/nnsf

* Site : http://camendesign.com/nononsense_forum
EOF
}

dofluxbb(){
    # dofluxbb <nom d'hote> </dossier/contenant/fluxbb> <mot de passe de la base de donnée postgresql>
    local domaineconf="/etc/nginx/conf.d/fluxbb.conf"
    local NOMDHOTE="$1"
    local ROOTOFHTTP="$2"
    local SSLCERT=""
    local BDDPW="$3"

    installapt nginx php5 openssl ssl-cert php5-fpm php-apc php-pear php5-pgsql postgresql postgresql-client postgresql-client-common php-db
    prepwebserver 0 "/$ROOTOFHTTP" "$NOMDHOTE"

    process "$STOCK/nginx-fluxbb.conf" > "${domaineconf}"

    # fluxbb
    echo "Téléchargeons le dernier fluxbb"
    wget -c -O $TEMP/fluxbb.tar.gz "http://fluxbb.org/download/releases/1.5.6/fluxbb-1.5.6.tar.gz"
    mkdir -p $TEMP/fluxbb
    tar xvf $TEMP/fluxbb.tar.gz -C $TEMP/fluxbb
    mv $TEMP/fluxbb/fluxbb-*/* "/$ROOTOFHTTP"

    # postgresql config
    preppgsql "$BDDPW"
    createdbpgsql "fluxbb" "$BDDPW"

    finwebserver 0 "/$ROOTOFHTTP"

    rapport << EOF
---
FluxBB installé
Ouvrez dans un navigateur https://$NOMDHOTE

Database server hostname est : localhost
Le nom de la base postgresql est : fluxbb
Le nom d'utilisateur à renseigner est : www-data

* Site : http://fluxbb.org
EOF
}

dophpbb(){
    # dophpbb <nom d'hote> </dossier/contenant/phpbb> <Mot de passe pour la base de données>
    local domaineconf="/etc/nginx/conf.d/phpbb.conf"
    local NOMDHOTE="$1"
    local ROOTOFHTTP="$2"
    local SSLCERT=""
    local BDDPW="$3"

    installapt nginx php5 openssl ssl-cert php5-fpm php-apc php5-pgsql postgresql postgresql-client postgresql-client-common php5-gd imagemagick php5-curl unzip php-db

    prepwebserver 0 "/$ROOTOFHTTP" "$NOMDHOTE"

    process "$STOCK/nginx-phpbb.conf" > "${domaineconf}"

    # phpbb
    echo "Téléchargeons le dernier phpbb"
    wget -c -O $TEMP/phpbb.zip "https://www.phpbb.com/files/release/phpBB-3.0.12.zip"
    mkdir -p $TEMP/phpbb
    unzip $TEMP/phpbb.zip -d "$TEMP/phpbb"
    mv $TEMP/phpbb/phpBB3/* "/$ROOTOFHTTP"

    # language pack
    # ajouter un menu pour choisir la langue?
    wget -O $TEMP/phpbb-fr.zip "https://www.phpbb.com/customise/db/download/id_91611"
    mkdir -p $TEMP/phpbb-fr
    unzip $TEMP/phpbb-fr.zip -d "$TEMP/phpbb-fr"
    cp -r $TEMP/phpbb-fr/french*/* "/$ROOTOFHTTP"

    # postgresql config
    preppgsql "$BDDPW"
    createdbpgsql "phpbb" "$BDDPW"

    finwebserver 0 "/$ROOTOFHTTP"

    rapport << EOF
---
phpBB installé
Ouvrez dans un navigateur https://$NOMDHOTE

Database server hostname est : localhost
Le nom de la base postgresql est : phpbb
Le nom d'utilisateur à renseigner est : www-data

* Site : https://www.phpbb.com
EOF
}

dopydio(){
# dopydio <nom d'hote> </repertoire/pour/pydio> 
    local domaineconf="/etc/nginx/conf.d/pydio.conf"
    local NOMDHOTE="$1"
    local ROOTOFHTTP="$2"
    local SSLCERT=""

    installapt nginx php5 php5-fpm php5-gd php5-cli php5-mcrypt unzip sqlite php5-sqlite php-db

    prepwebserver 0 "/$ROOTOFHTTP" "$NOMDHOTE"
    process "$STOCK/nginx-pydio.conf" > "${domaineconf}"
    phpuploadlimit

    # pydio
    echo -e "Téléchargeons le dernier pydio"
    wget -c -O $TEMP/pydio.zip "http://sourceforge.net/projects/ajaxplorer/files/latest/download?source=files"
    mkdir -p $TEMP/pydio
    unzip $TEMP/pydio.zip -d "$TEMP/pydio"
    mv -v $TEMP/pydio/pydio-core*/* "/$ROOTOFHTTP"

    finwebserver 0 "/$ROOTOFHTTP"

    rapport << EOF
---
pydio installé"
Ouvrez dans un navigateur https://$NOMDHOTE pour profiter

* Site : http://pyd.io/
EOF
}



dortorrent(){
    # dortorrent <nom hote> <username> <mot de passe>
    local domaineconf="/etc/nginx/conf.d/torrent.conf"
    local NOMDHOTE="$1"
    local SSLCERT=""
    local TORRENTUSER="$2"
    local TORRENTDIR="/home/$TORRENTUSER/SEEDBOX"
    local TORRENTPWD="$3"
    local ROOTOFHTTP="$TORRENTDIR/rutorrent"

    installapt rtorrent screen nginx apache2-utils

    useradd -m "$TORRENTUSER"

    # rtorrent
    mkdir -p "$TORRENTDIR"/{download,session,torrents,rutorrent}
    process "$STOCK/rtorrent-init" > /etc/init.d/rtorrent
    process "$STOCK/rtorrent.rc" > /home/$TORRENTUSER/.rtorrent.rc
    chown -R $TORRENTUSER:$TORRENTUSER "$TORRENTDIR"
    chmod +x /etc/init.d/rtorrent
    update-rc.d rtorrent defaults

    # rutorrent
    wget -c -O "$TEMP/rutorrent.tar.gz" "https://bintray.com/artifact/download/novik65/generic/rutorrent-3.6.tar.gz"
    tar xvf $TEMP/rutorrent.tar.gz -C "/$ROOTOFHTTP"
    chown -R www-data:www-data "$ROOTOFHTTP"
    chmod 777 "$TORRENTDIR/download"
    htpasswd -b -c "$ROOTOFHTTP/.htpasswd" "$TORRENTUSER" "$TORRENTPWD"
    chown root:www-data "$ROOTOFHTTP/.htpasswd"
    chmod 640  "$ROOTOFHTTP/.htpasswd"

    createwwwdata
    dosslcert "$NOMDHOTE"
    SSLCERT="
    ssl_certificate /etc/ssl/private/$1.pem;
    ssl_certificate_key /etc/ssl/private/$1.pem;"

    process "$STOCK/nginx-torrent.conf" > "$domaineconf"
    cp -v "$STOCK/nginx-php.conf" /etc/nginx/conf.d/php
    service nginx restart

    /etc/init.d/rtorrent start
    rapport << EOF
---
Seedbox installée
Vous pouvez accéder à l'interface de gestion des torrents à l'adresse : 
    https://$NOMDHOTE
Vous pouvez récupérer les téléchargements à l'adresse : 
    https://$NOMDHOTE/downloads
Tous les fichiers .torrents présents dans le dossier 
$TORRENTDIR/torrents seront automatiquement ajoutés.
EOF
}

dotransmission(){
    # dotransmission <nom hote> <username> <mot de passe> <repertoire de telechargement>
    local domaineconf="/etc/nginx/conf.d/transmission.conf"
    local NOMDHOTE="$1"
    local SSLCERT=""
    local TORRENTUSER="$2"
    local TORRENTPWD="$3"
    local DOWNDIR="$4"

    installapt transmission-daemon nginx apache2-utils

    mkdir -p "$DOWNDIR"
    mkdir -p "$DOWNDIR"/torrents

    service transmission-daemon stop
    process "$STOCK/transmission-settings.json" > /etc/transmission-daemon/settings.json
    chown debian-transmission:debian-transmission /etc/transmission-daemon/settings.json
    chmod 600 /etc/transmission-daemon/settings.json

    dosslcert "$NOMDHOTE"
    SSLCERT="
    ssl_certificate /etc/ssl/private/$1.pem;
    ssl_certificate_key /etc/ssl/private/$1.pem;"

    process "$STOCK/nginx-transmission.conf" > "${domaineconf}"

    service transmission-daemon start
    service nginx restart

    rapport << EOF
---
Seedbox installée
Vous pouvez accéder à l'interface de gestion des torrents à l'adresse : 
    https://$NOMDHOTE/transmission
Vous pouvez récupérer les téléchargements à l'adresse : 
    https://$NOMDHOTE/downloads
Tous les torrents placés dans ce dossier seront ajoutés : 
    https://$DOWNDIR/torrents
EOF
}

dodokuwiki() {
    # dodokuwiki <nom d'hote> </dossier/contenant/dokuwiki>
    local domaineconf="/etc/nginx/conf.d/dokuwiki.conf"
    local NOMDHOTE="$1"
    local ROOTOFHTTP="$2"
    local SSLCERT=""

    installapt nginx php5 openssl ssl-cert php5-fpm php-apc php5-gd imagemagick php-geshi

    prepwebserver 0 "/$ROOTOFHTTP" "$NOMDHOTE"
    process "$STOCK/nginx-dokuwiki.conf" > "${domaineconf}"
    phpuploadlimit

    # dokuwiki
    echo "Téléchargeons le dernier dokuwiki"
    mkdir -p $TEMP/dokuwikitmp
    wget -c -O $TEMP/dokuwiki.tgz "http://download.dokuwiki.org/src/dokuwiki/dokuwiki-stable.tgz"
    tar xvf $TEMP/dokuwiki.tgz -C "$TEMP/dokuwikitmp"
    mv $TEMP/dokuwikitmp/dokuwiki-*/* "/$ROOTOFHTTP"

    finwebserver 0 "/$ROOTOFHTTP" 

    rapport << EOF
---
Dokuwiki installé
Ouvrez dans un navigateur https://$NOMDHOTE/install.php pour terminer l'installation.

Il faudra ensuite supprimer le fichier $ROOTOFHTTP/install.php

* Site : https://www.dokuwiki.org/dokuwiki
EOF
}

domediawiki() {
    # domediawiki <nom d'hote> 
    local domaineconf="/etc/nginx/conf.d/mediawiki.conf"
    local NOMDHOTE="$1"
    local SSLCERT=""

    installapt nginx php5 openssl ssl-cert php5-fpm php-apc php5-gd mediawiki sqlite php5-sqlite
    cp -v "$STOCK/nginx-php.conf" /etc/nginx/conf.d/php

    dosslcert "$NOMDHOTE"
    SSLCERT="
    ssl_certificate /etc/ssl/private/$NOMDHOTE.pem;
    ssl_certificate_key /etc/ssl/private/$NOMDHOTE.pem;"

    process "$STOCK/nginx-mediawiki.conf" > "${domaineconf}"
    phpuploadlimit

    service nginx restart

    rapport << EOF
---
Mediawiki installé
Ouvrez dans un navigateur https://$NOMDHOTE/mediawiki

* Site : https://www.mediawiki.org
EOF
}

dotinytodo(){
    #dotinytodo <nom d'hote> </repertoire/contenant/mytinytodo>
    local domaineconf="/etc/nginx/conf.d/mytinytodo.conf"
    local NOMDHOTE="$1"
    local ROOTOFHTTP="$2"
    local SSLCERT=""

    installapt nginx php5 openssl ssl-cert php5-fpm php-apc  unzip sqlite php5-sqlite
    cp -v "$STOCK/nginx-php.conf" /etc/nginx/conf.d/php

    prepwebserver 0 "/$ROOTOFHTTP" "$NOMDHOTE"
    process "$STOCK/nginx-mytinytodo.conf" > "${domaineconf}"

    # dropcenter
    echo -e "Téléchargeons le dernier mytinytodo"
    wget -O $TEMP/mytinytodo.zip "http://www.mytinytodo.net/latest.php"
    mkdir -p $TEMP/mytinytodo
    unzip $TEMP/mytinytodo.zip -d $TEMP/mytinytodo
    mv $TEMP/mytinytodo/mytinytodo/* "/$ROOTOFHTTP"

    finwebserver 0 "/$ROOTOFHTTP" 

    rapport << EOF
---
mytinytodo installé
Ouvrez dans un navigateur https://$NOMDHOTE pour terminer la configuration

* Site : http://www.mytinytodo.net/
EOF
}

dokanboard(){
    #dokanboard <nom d'hote> </dossier/contenant/kanboard>
    local domaineconf="/etc/nginx/conf.d/kanboard.conf"
    local NOMDHOTE="$1"
    local ROOTOFHTTP="$2"
    local SSLCERT=""

    installapt nginx php5 openssl ssl-cert php5-fpm php-apc unzip sqlite php5-sqlite
    prepwebserver 0 "/$ROOTOFHTTP" "$NOMDHOTE"
    process "$STOCK/nginx-kanboard.conf" > "${domaineconf}"

    # kanboard
    echo "Téléchargeons le dernier kanboard"
    wget -O $TEMP/kanboard.zip "http://kanboard.net/kanboard-latest.zip"
    mkdir -p $TEMP/kanboardtemp
    unzip $TEMP/kanboard.zip -d $TEMP/kanboardtemp
    mv $TEMP/kanboardtemp/kanboard/* "/$ROOTOFHTTP"

    finwebserver 0 "/$ROOTOFHTTP" 

    rapport << EOF
---
kanboard installé
Ouvrez dans un navigateur https://$NOMDHOTE pour terminer la configuration

Les identifiants sont par défaut admin/admin. Changez très vite le mot de passe!

* Site : http://kanboard.net
EOF
}

dounbound(){
    # dounbound <auto-resolv.conf 0:oui, 1:non> 
    
    installapt unbound unbound-anchor
    cp -v "$STOCK/unbound.conf" /etc/unbound/unbound.conf
    wget ftp://FTP.INTERNIC.NET/domain/named.cache -O /var/lib/unbound/root.hints

    chmod +x "$STOCK/unbound_yoyo_antispam.sh"
    $STOCK/unbound_yoyo_antispam.sh

    if [ $1 -eq 0 ]; then
        echo "prepend domain-name-servers 127.0.0.1;" >> /etc/dhcp/dhclient.conf
    fi
    
    service unbound restart

    rapport << EOF
---
Unbound installé
Pour utiliser votre propre serveur DNS, assurez-vous que dans le fichier
/etc/resolv.conf se trouve la ligne

    nameserver 127.0.0.1

* Site : https://unbound.net/
* Lecture conseillée : https://calomel.org/unbound_dns.html
EOF
}


domonitorix(){
    # domonitorix
    installapt rrdtool perl libwww-perl libmailtools-perl libmime-lite-perl librrds-perl libdbi-perl libxml-simple-perl libhttp-server-simple-perl libconfig-general-perl libio-socket-ssl-perl
    wget -c -O /tmp/monitorix.deb http://www.monitorix.org/monitorix_3.6.0-izzy1_all.deb
    dpkg -i /tmp/monitorix.deb
    apt-get install -f

rapport << EOF
---
Monitorix installé
Ouvrez un navigateur à l'adresse http://localhost:8080/monitorix
ou à l'adresse http://$ip_du_serveur:8080/monitorix

* Site : http://www.monitorix.org
EOF
}

doopenvpn(){
    # doopenvpn <nom d'hote> <IP> <PORT> <clients>
    # variables identiques à celles pour ssl
    # merci à https://github.com/Nyr/openvpn-install/blob/master/openvpn-install.sh
    local NOMDHOTE="$1"
    local IP="$2"
    local PORT="$3"
    local CLIENTS="$4"

    if [[ ! -e /dev/net/tun ]]; then
        die "TUN/TAP n'est pas disponible"
    fi

    installapt openvpn openssl

    # Génération des certificats et clefs
    cp -R /usr/share/doc/openvpn/examples/easy-rsa/ /etc/openvpn
    # changement de répertoire
    cd /etc/openvpn/easy-rsa/2.0/
    # chiffrement plus sûr
	sed -i 's|export KEY_SIZE=1024|export KEY_SIZE=2048|' /etc/openvpn/easy-rsa/2.0/vars

    # pas très propre, mais comme c'est des scripts ça doit le faire.
    echo "export KEY_COUNTRY=\"$SSLCOUNTRY\"" >> /etc/openvpn/easy-rsa/2.0/vars
    echo "export KEY_PROVINCE=\"$SSLSTATE\"" >> /etc/openvpn/easy-rsa/2.0/vars
    echo "export KEY_CITY=\"$SSLLOCATION\"" >> /etc/openvpn/easy-rsa/2.0/vars
    echo "export KEY_ORG=\"$NOMDHOTE\"" >> /etc/openvpn/easy-rsa/2.0/vars
    echo "export KEY_EMAIL=\"$SSLemailAddress\"" >> /etc/openvpn/easy-rsa/2.0/vars

    # on fabrique les pki
	. /etc/openvpn/easy-rsa/2.0/vars
	. /etc/openvpn/easy-rsa/2.0/clean-all
    #./build-ca
	export EASY_RSA="${EASY_RSA:-.}"
	"$EASY_RSA/pkitool" --initca $*
	"$EASY_RSA/pkitool" --server server
    # un certificat par client
    for CLIENT in $(echo $CLIENTS |sed "s; ;\n;g"); do
        export KEY_CN=\"$CLIENT\" 
        export EASY_RSA="${EASY_RSA:-.}"
        "$EASY_RSA/pkitool" $CLIENT
    done
	. /etc/openvpn/easy-rsa/2.0/build-dh

    # configuration du serveur
    ln -s /etc/openvpn/easy-rsa/2.0/keys/ /etc/openvpn/
    process "$STOCK/openvpn.conf" > "/etc/openvpn/server.conf"

	# Obtain the resolvers from resolv.conf and use them for OpenVPN
	#grep -v '#' /etc/resolv.conf | grep 'nameserver' | grep -E -o '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | while read line; do
	#	echo "push \"dhcp-option DNS $line\"" >> server.conf
	#done

	# ip forward
    sed -i 's|#net.ipv4.ip_forward=1|net.ipv4.ip_forward=1|' /etc/sysctl.conf
	# Pas de reboot nécessaire
	echo 1 > /proc/sys/net/ipv4/ip_forward

	# Config d'iptables
	iptables -t nat -A POSTROUTING -s 10.8.0.0/24 -j SNAT --to $IP
	# même règle à chaque reboot
	sed -i "/# By default this script does nothing./a\iptables -t nat -A POSTROUTING -s 10.8.0.0/24 -j SNAT --to $IP" /etc/rc.local

	/etc/init.d/openvpn restart

    # configuration des clients
    for CLIENT in $(echo $CLIENTS |sed "s; ;\n;g"); do
        mkdir -p $TEMP/ovpn-$CLIENT
        cp /usr/share/doc/openvpn/examples/sample-config-files/client.conf $TEMP/ovpn-$CLIENT/$CLIENT.conf
        sed -i "s|remote my-server-1 1194|remote $IP $PORT|" $TEMP/ovpn-$CLIENT/$CLIENT.conf
        cp /etc/openvpn/easy-rsa/2.0/keys/ca.crt $TEMP/ovpn-$CLIENT
        cp /etc/openvpn/easy-rsa/2.0/keys/$CLIENT.crt $TEMP/ovpn-$CLIENT
        cp /etc/openvpn/easy-rsa/2.0/keys/$CLIENT.key $TEMP/ovpn-$CLIENT
        cd $TEMP/ovpn-$CLIENT
        sed -i "s|cert client.crt|cert $CLIENT.crt|" $CLIENT.conf
        sed -i "s|key client.key|key $CLIENT.key|" $CLIENT.conf
        tar -czf ../ovpn-$CLIENT.tar.gz $CLIENT.conf ca.crt $CLIENT.crt $CLIENT.key
        cd $TEMP
        rm -rf ovpn-$CLIENT
        mv "$TEMP/ovpn-$CLIENT.tar.gz" $CURDIR/
    done




rapport << EOF
---
Openvpn installé

* Pensez à ouvrir le port pour le serveur : $PORT
* Installez le paquet openvpn sur les machines qui devront se connecter au serveur
Les configurations pour les clients à décompresser dans /etc/openvpn sont disponibles ici : 
$CURDIR

* Site : https://openvpn.net
EOF
}

dodotclear(){
# dodotclear <nom d'hote> </repertoire/pour/dotclear> 
    local domaineconf="/etc/nginx/conf.d/dotclear.conf"
    local NOMDHOTE="$1"
    local ROOTOFHTTP="$2"
    local SSLCERT=""

    installapt nginx php5 php5-gd php5-fpm php5-sqlite php-db

    prepwebserver 0 "/$ROOTOFHTTP" "$NOMDHOTE"
    process "$STOCK/nginx-dotclear.conf" > "${domaineconf}"
    phpuploadlimit

    # automatic dotclear install
    echo -e "Téléchargeons le dernier dotclear"
    wget -O "$ROOTOFHTTP/dotclear2-loader.php" "http://download.dotclear.net/loader/dotclear2-loader.php"
    chown -R www-data:www-data "/$ROOTOFHTTP/"

    service nginx restart
    service php5-fpm restart

    rapport << EOF
---
dotclear installé"
Ouvrez dans un navigateur https://$NOMDHOTE/dotclear2-loader.php pour terminer l'installation

* Site : http://dotclear.org
EOF
}

dobaikal() {
  # dobaikal <nom d'hote> </repertoire/contenant/baikal>
    echo "installation de baikal"
    local domaineconf="/etc/nginx/conf.d/baikal.conf"
    local NOMDHOTE="$1"
    local ROOTOFHTTP="$2"

    installapt php5 php-apc php5-fpm php5-sqlite sqlite nginx 
    cp -v "$STOCK/nginx-php.conf" /etc/nginx/conf.d/php
    createwwwdata
    mkdir -p "/$ROOTOFHTTP/"

    process "$STOCK/nginx-baikal.conf" > "${domaineconf}"

    wget -c -O $TEMP/baikal.tgz "http://baikal-server.com/get/baikal-regular-0.2.7.tgz"
    
    mkdir -p $TEMP/baikaltmp
    tar xvf $TEMP/baikal.tgz -C $TEMP/baikaltmp
    mv $TEMP/baikaltmp/baikal-regular*/* "/$ROOTOFHTTP"
    touch "/$ROOTOFHTTP/Specific/ENABLE_INSTALL"

    finwebserver 0 "/$ROOTOFHTTP" 

    rapport << EOF
---
baikal installé
Ouvrez dans un navigateur http://$NOMDHOTE pour terminer la configuration

* Site : http://baikal-server.com
EOF

}

work() {
# work <fichier contenant les tâches à réaliser>
    if [ ! -f "$1" ]; then
        die "$1 non trouvé"
    fi

    verbose mkdir -p "$TEMP"
    while read -u 3 line; do
        eval "$line"
    done 3< "${1}"
    verbose rm -rf "$TEMP"
    
    rapport << EOF
---
*AVERTISSEMENT*
Vous venez d'installer un ou des services : super!
Il est cependant *vivement recommandé* de vous documenter un minimum sur ce(s) service(s) afin de pouvoir résoudre des problèmes futurs, le(s) mettre à jour, et assurer la sécurité de votre serveur.
Amusez vous bien!
EOF

    echo "Messages enregistrés dans $RAPPORT"
    echo "Au revoir o/"
}

showhelp() {
    echo "* Host@home - version $VERSION *"
    echo "utilisation : la commande suivant doit être lancée avec les droits super utilisateur"
    echo "  $0 <fichier_de_configuration.cfg>"
    echo "Le fichier de configuration contient des instructions qui seront exécutées automatiquement"
    echo "Voir le fichier hah.cfg comme exemple."
    echo "---"
    echo "Autres options : "
    echo "-h : Affiche ce message d'aide"
    exit 0
}


