#!/bin/bash
CURDIR="$(echo $(dirname $(readlink -f $0)))"
#debian
if [ -f /usr/share/hostathome/hah-engine.sh ]; then
    . /usr/share/hostathome/hah-engine.sh
else
    . "$CURDIR/hah-engine.sh"
fi

# gettext
#. gettext.sh
#export TEXTDOMAIN=hostathome
#export TEXTDOMAINDIR=/usr/share/locale

# Global variables
SSLCOUNTRY=""
SSLSTATE=""
SSLLOCATION=""
SSLORGANISATION=""
SSLCOMMONNAME=""
SSLemailAddress=""
SSLFIRSTRUN=""

dgetinfo() {
    #dgetinfo <variable> <message> <titre> <default>
    local rep=""
    while [ -z "$rep" ]; do
        dialog --title "$3" --inputbox "$2" 20 60 "$4" 2> "$tmpfile"
        rep="$(<"$tmpfile")"
    done
    assign "$1" <<< $rep 
}

info_ssl() {
    while [ -z "$SSLCOUNTRY" ]; do
        dialog --title "Configuration de SSL" --inputbox "Code du pays (ex : FR)" 20 60 2> "$tmpfile"
        SSLCOUNTRY="$(<"$tmpfile")"
    done
    while [ -z "$SSLSTATE" ]; do
        dialog --title "Configuration de SSL" --inputbox "Nom du pays? (ex : France)" 20 60 2> "$tmpfile"
        SSLSTATE="$(<"$tmpfile")"
    done
    while [ -z "$SSLLOCATION" ]; do
        dialog --title "Configuration de SSL" --inputbox "Ville? (ex : Paris)" 20 60 2> "$tmpfile"
        SSLLOCATION="$(<"$tmpfile")"
    done
    while [ -z "$SSLemailAddress" ]; do
        dialog --title "Configuration de SSL" --inputbox "Votre addresse de courriel?" 20 60 2> "$tmpfile"
        SSLemailAddress="$(<"$tmpfile")"
    done
    if [ ! -z "$SSLFIRSTRUN" ]; then
        dialog --title "Configuration de SSL" --inputbox "Nom de l'organisation? (peut être laissé vide)" 20 60 2> "$tmpfile"
        SSLORGANISATION="$(<"$tmpfile")"
        dialog --title "Configuration de SSL" --inputbox "Votre nom? (peut être laissé vide)" 20 60 2> "$tmpfile"
        SSLCOMMONNAME="$(<"$tmpfile")"
    fi
    SSLFIRSTRUN="non"
}

info_nginx() {
# met la commande de configuration de nginx dans $1
    # dohttp_nginx <nom d'hote> </emplacement/du/site> <php 0 pour oui/1 pour non> <SSL (1:N, 2:O, 3:O avec redirection)>
    local NOMDHOTE=""
    local ROOTOFHTTP=""
    local DOPHP=""
    local SSL=""

    # Nom de domaine
    dgetinfo NOMDHOTE "Quel est votre nom de domaine (sans http://)? (ex : mondomaine.com) " "Configuration de nginx"

    # Racine du site
    dgetinfo ROOTOFHTTP "Dossier contenant votre site? (ex : /srv/www/supersite) " "Configuration de nginx"

    # PHP
    dialog --title "Configuration de nginx" --yesno "Voulez-vous utiliser php? " 20 60
    DOPHP=$?

    # SSL
    while ! [[ $SSL =~ ^[0-9]+$ ]]; do
        dialog --backtitle "SSL" \
        --radiolist 'Voulez-vous installer le support de ssl? (https)' 20 60 5 \
        "1" "Non, http seul" on\
        "2" "Oui, https seul" off\
        "3" "oui, avec http redirigé vers https" off 2> "$tmpfile"
        SSL="$(<"$tmpfile")"
    done
    if [ "$SSL" = "2" -o "$SSL" = "3" ]; then
        info_ssl
    fi
    assign "$1" <<< "dohttp_nginx $NOMDHOTE $ROOTOFHTTP $DOPHP $SSL"
}

info_postfix() {
    local NOMDHOTE="$1"
    local DOMAIN="$2"

    dialog --msgbox "Un serveur de courriel a besoin de 2 champs DNS : \n\
       - Un champ de type A : mail.server.net . C'est le nom d'hôte vous permettant ensuite de récupérer vos mails.\n\
       - Un champ de type MX pointant vers le A précédent. C'est en général le nom de domaine porté dans les adresses : machin@domain.net\n\
   Ainsi, lorqu'on vous écrit à machin@domain.net, c'est directement relié à l'hôte mail.server.net" 20 60

    dgetinfo NOMDHOTE "Quel est votre nom de domaine (sans http://)? (ex : mondomaine.com)" "Configuration de postfix"
    dgetinfo DOMAIN "Quel est votre nom d'hote (sans http://)? (ex : smtp.mondomaine.com)"  "Configuration de postfix"
    assign "$1" <<< "dopostfix $NOMDHOTE $DOMAIN"
}

info_sftp() {
    local PORT=""
    local CHROOTDIR=""
    local USER=""
    local HTTPSHARE=""

    # port?
    while ! [[ $PORT =~ ^[0-9]+$ ]]; do
        dialog --title "Quel est le port utilisé pour ssh (22)" --inputbox "port?" 20 60 2> "$tmpfile"
        PORT="$(<"$tmpfile")"
    done
    # répertoire de chroot
    while [ -z "$CHROOTDIR" ]; do
        dialog --title "Emplacement du dossier contenant les documents du sftp (/media/sftp)" --inputbox "dossier?" 20 60 2> "$tmpfile"
        CHROOTDIR="$(<"$tmpfile")"
    done

    # Utilisateurs
    while [ -z "$USER" ]; do
        dialog --title "Quels sont les utilisateurs de ssh (séparés par un espace)" --inputbox "Utilisateurs?" 20 60 2> "$tmpfile"
        USER="$(<"$tmpfile")"
    done

    dialog --title "Configuration de sftp" --yesno "\
    Souhaitez-vous proposer un accès aux documents via un navigateur web? (http://votreserveur.com/~utilisateur)\
        Notez que cela suppose avoir installé nginx avec ce script" 20 60
    HTTPSHARE=$?

    assign "$1" <<< "dosftp $PORT $CHROOTDIR \"$USER\" $HTTPSHARE"
}

info_site() {
    local NOMDHOTE=""
    local ROOTOFHTTP=""
    dgetinfo NOMDHOTE "Quel est votre nom de domaine (sans http://)? (ex : $2.mondomaine.com) " "Configuration de $2"
    dgetinfo ROOTOFHTTP "Dossier contenant votre site? (ex : /srv/www/$2)/ N'oubliez pas le premier /" "Configuration de $2"

    assign "$1" <<< "$NOMDHOTE $ROOTOFHTTP"
}

info_tor() {
    # surnom
    while [ -z "$NICKNAME" ]; do
        dialog --title "Surnom de votre noeud tor pour vous identifier sur le réseau" --inputbox "Surnom?" 20 60 2> "$tmpfile"
        NICKNAME="$(<"$tmpfile")"
    done
    # Adresse de contact
    while [ -z "$EMAIL" ]; do
        dialog --title "Adresse électronique de contact? (bibi@mail.com)" --inputbox "email?" 20 60 2> "$tmpfile"
        EMAIL="$(<"$tmpfile")"
    done
    # pseudo
    while [ -z "$PSEUDO" ]; do
        dialog --title "Votre pseudonyme de contact" --inputbox "Pseudo?" 20 60 2> "$tmpfile"
        PSEUDO="$(<"$tmpfile")"
    done

    while ! [[ $BWRATE =~ ^[0-9]+$ ]]; do
        dialog --title "Bande passante à réserver? (en kB/s)" --inputbox "Bande passante? (en kB/s)" 20 60 2> "$tmpfile"
        BWRATE="$(<"$tmpfile")"
    done
    while ! [[ $BWBURST =~ ^[0-9]+$ ]]; do
        dialog --title "Bande passante maximale à réserver en cas d'éclat? (en kB/s)" --inputbox "Bande passante max? (en kB/s)" 20 60 2> "$tmpfile"
        BWBURST="$(<"$tmpfile")"
    done

    assign "$1" <<< "dotor $NICKNAME $BWRATE $BWBURST $PSEUDO $EMAIL"
}

dialogmenu() {
    # Compatibilité
    export TERM=xterm
    # Commande à éxécuter
    local COMMAND=""
    # fichier temporaire pour menu
    tmpmenu="$(tempfile)"
    trap "rm -f $tmpmenu" EXIT
    # fichier temporaire pour le script
    tmpfile="$(tempfile)"
    trap "rm -f $tmpfile" EXIT
    # fichier temporaire des tâches à réaliser
    tmpwork="$(tempfile)"
    trap "rm -f $tmpwork" EXIT

    dialog --clear\
        --separate-output \
        --backtitle "Host@home - Installez votre serveur à la maison. $VERSION" \
        --checklist 'Tâche(s) à accomplir: \n(<espace> pour cocher, <↑> et <↓> pour déplacer le curseur, <tabulation> pour choisir le bouton, <Entrée> pour valider)' 25 65 18 \
        preparation "Prépare le serveur en le mettant à jour" on\
        securite "sécurité minimale du serveur" on\
        http_nginx "Installer un serveur http(s) (nginx)" off\
        sftp "Partage de fichiers sécurisé avec sftp" off\
        openvpn "Serveur vpn" off\
        postfix "Serveur de courriel postfix" off\
        squirrelmail "Webmail  (squirrelmail)" off\
        rainloop "Webmail (rainloop)" off\
        wallabag "Application de Read-it-later" off\
        owncloud "Hébergez votre nuage" off\
        dropcenter "Déposez et partagez vos documents" off \
        pydio "Partage de fichiers (Ajaxplorer)" off\
        jyrafeau "Hébergement et partage de documents" off\
        jyraphe "Hébergement et partage de documents" off\
        xmpp "Votre serveur jabber/xmpp" off\
        pluxml "Blog/CMS" off\
        blogotext "Blog" off\
        pico "Un CMS léger utilisant markdown" off\
        kriss "Simple lecteur de flux" off\
        TinyTinyRSS "Lecteur de flux" off\
        mytinytodo "Gestion simple de listes todo" off\
        jotter "Gestion simple de listes todo" off\
        kanboard "Tableau de tâches" off\
        ZeroBin "Pastebin/discussion encrypté" off\
        Shaarli "Clone de delicious" off\
        NoNonsenseForum "Un forum très simple" off\
        fluxBB "Un forum" off\
        phpBB "Un autre forum" off\
        rtorrent "Seedbox avec rtorrent" off \
        transmission "Seedbox avec transmission" off \
        DokuWiki "Simple wiki" off\
        MediaWiki "Wiki complet [complexe]" off\
        Baikal "Serveur CalDAV+CardDAV" off\
        tor "Relais tor" off\
        monitorix "Supervisation du serveur" off\
        unbound "[avancé] Serveur DNS" off\
        roundcube "[avancé] Webmail avec sqlite" off\
        roundcube-pgsql "[avancé] Webmail avec postgresql" off 2> "$tmpmenu"
    retval=$?

    case $retval in
        1 | 255) echo "Rien à faire";;
        0) 
            while read line; do
                case "$line" in 
                    "preparation") echo "dopreparation" >> "$tmpwork" ;;
                    "http_nginx") 
                        info_nginx COMMAND 
                        echo "$COMMAND" >> "$tmpwork" 
                        ;;
                    "postfix") 
                        info_postfix COMMAND 
                        echo "$COMMAND" >> "$tmpwork" 
                        ;;
                    "squirrelmail") 
                        info_ssl
                        local NDD=""
                        dgetinfo NDD "Quel est votre nom de domaine (sans http://)? (ex : webmail.mondomaine.com) " "Configuration du webmail"
                        echo "dosquirrelmail $NDD" >> "$tmpwork"
                        ;;
                    "roundcube") 
                        info_ssl
                        info_site COMMAND "roundcube" 
                        echo "doroundcube $COMMAND" >> "$tmpwork"
                        ;;
                    "roundcube-pgsql") 
                        local MDP=""
                        info_ssl
                        info_site COMMAND "roundcube" 
                        dgetinfo MDP "Mot de passe de la base Postgresql?" "Configuration de roundcube"
                        echo "doroundcube-pgsql $COMMAND $MDP" >> "$tmpwork"
                        ;;
                    "rainloop") 
                        info_ssl
                        info_site COMMAND "rainloop" 
                        echo "dorainloop $COMMAND" >> "$tmpwork"
                        ;;
                    "wallabag") 
                        info_ssl
                        info_site COMMAND "wallabag" 
                        echo "dowallabag $COMMAND" >> "$tmpwork"
                        ;;
                    "sftp") 
                        info_sftp COMMAND 
                        echo "$COMMAND" >> "$tmpwork" 
                        ;;
                    "owncloud") 
                        info_ssl
                        info_site COMMAND "owncloud" 
                        echo "doowncloud $COMMAND" >> "$tmpwork"
                        ;;
                    "dotclear") 
                        info_ssl
                        info_site COMMAND "dotclear" 
                        echo "dodotclear $COMMAND" >> "$tmpwork"
                        ;;
                    "xmpp") 
                        dialog --msgbox "Pour que tout fonctionne bien, il serait bon de créer les champs DNS suivants : \n\
                        - Un champ de type A : xmpp.mondomaine.com\n\
                        - Des champs de type SRV vers xmpp.mondomaine.com comme ceci : \n\
                        _xmpp-client._tcp.domaine.net. 18000 IN SRV 0 5 5222 xmpp.domaine.net.\n\
                        _xmpp-server._tcp.domaine.net. 18000 IN SRV 0 5 5269 xmpp.domaine.net."
                        info_ssl
                        local NDD=""
                        dgetinfo NDD "Quel est votre nom de domaine (sans http://)? (ex : xmpp.domaine.com) " "Configuration de xmpp"
                        echo "doxmpp $NDD" >> "$tmpwork"
                        ;;
                    "pluxml")
                        info_ssl
                        info_site COMMAND "pluxml" 
                        echo "dopluxml $COMMAND" >> "$tmpwork"
                        ;;
                    "pico")
                        info_ssl
                        info_site COMMAND "pico" 

                        local PW=''
                        dgetinfo PW "Mot de passe pour pico?" "Choix d'un mot de passe"

                        echo "dopico $COMMAND $PW" >> "$tmpwork"
                        ;;
                    "blogotext") 
                        info_ssl
                        info_site COMMAND "blogotext" 
                        echo "doblogotext $COMMAND" >> "$tmpwork"
                        ;;
                    "kriss") 
                        info_ssl
                        info_site COMMAND "kriss" 
                        echo "dokriss $COMMAND" >> "$tmpwork" ;;
                    "TinyTinyRSS")
                        local MDP=""
                        info_ssl
                        info_site COMMAND "Tiny Tiny RSS" 
                        dgetinfo MDP "Mot de passe de la base Postgresql?" "Configuration de TT-RSS"
                        echo "dottrss $COMMAND $MDP" >> "$tmpwork"
                        ;;
                    "mytinytodo") 
                        info_ssl
                        info_site COMMAND "mytinytodo" 
                        echo "dotinytodo $COMMAND" >> "$tmpwork" ;;
                    "jotter") 
                        info_ssl
                        info_site COMMAND "jotter" 
                        echo "dojotter $COMMAND" >> "$tmpwork" ;;
                    "kanboard") 
                        info_ssl
                        info_site COMMAND "kanboard" 
                        echo "dokanboard $COMMAND" >> "$tmpwork" ;;
                    "tor")
                        info_tor COMMAND
                         echo "$COMMAND" >> "$tmpwork" ;;
                    "dropcenter")
                        info_ssl
                        info_site COMMAND "dropcenter" 
                        echo "dodropcenter $COMMAND" >> "$tmpwork"
                        ;;
                    "ZeroBin")
                        info_site COMMAND "ZeroBin" 
                        echo "dozerobin $COMMAND" >> "$tmpwork"
                        ;;
                    "Shaarli")
                        info_ssl
                        info_site COMMAND "Shaarli" 
                        echo "doshaarli $COMMAND" >> "$tmpwork"
                        ;;
                    "pydio")
                        info_ssl
                        info_site COMMAND "Pydio" 
                        echo "dopydio $COMMAND" >> "$tmpwork"
                        ;;
                    "NoNonsenseForum")
                        info_ssl
                        info_site COMMAND "NoNonsenseForum" 
                        echo "donononsenseforum $COMMAND" >> "$tmpwork"
                        ;;
                    "fluxBB")
                        local MDP=""
                        info_ssl
                        info_site COMMAND "FluxBB" 
                        dgetinfo MDP "Mot de passe de la base Postgresql?" "Configuration de fluxBB"
                        echo "dofluxbb $COMMAND $MDP" >> "$tmpwork"
                        ;;
                    "phpBB")
                        local MDP=""
                        info_ssl
                        info_site COMMAND "phpBB" 
                        dgetinfo MDP "Mot de passe de la base Postgresql?" "Configuration de phpBB"
                        echo "dophpbb $COMMAND $MDP" >> "$tmpwork"
                        ;;
                    "DokuWiki")
                        info_ssl
                        info_site COMMAND "DokuWiki" 
                        echo "dodokuwiki $COMMAND" >> "$tmpwork"
                        ;;
                    "MediaWiki") 
                        info_ssl
                        local NDD=""
                        dgetinfo NDD "Quel est votre nom de domaine (sans http://)? (ex : wiki.mondomaine.com) " "Configuration de mediawiki"
                        echo "domediawiki $NDD" >> "$tmpwork"
                        ;;
                    "Baikal") 
                        local NDD=""
                        info_site COMMAND "Baikal" 
                        echo "dobaikal $COMMAND" >> "$tmpwork"
                        ;;
                    "rtorrent")
                        local NDD=""
                        local USERNAME=""
                        local MDP=""
                        info_ssl
                        dgetinfo NDD "Nom de domaine pour rtorrent?" "Configuration de rtorrent"
                        dgetinfo USERNAME "Utilisateur pour rtorrent?" "Configuration de rtorrent"
                        dgetinfo MDP "Mot de passe pour rtorrent?" "Configuration de rtorrent"
                        echo "dortorrent $NDD $USERNAME $MDP" >> "$tmpwork"
                        ;;
                    "transmission")
                        local NDD=""
                        local USERNAME=""
                        local MDP=""
                        local DOWNDIR=""
                        info_ssl
                        dgetinfo NDD "Nom de domaine pour transmission?" "Configuration de transmission"
                        dgetinfo USERNAME "Utilisateur pour transmission?" "Configuration de transmission"
                        dgetinfo MDP "Mot de passe pour transmission?" "Configuration de transmission"
                        dgetinfo DOWNDIR "Dossier de téléchargement (ex : /media/downloads)?" "Configuration de transmission"
                        echo "dotransmission $NDD $USERNAME $MDP $DOWNDIR" >> "$tmpwork"
                        ;;

                    "jyraphe")
                        local DOCROOT=""
                        info_ssl
                        info_site COMMAND "jyraphe"
                        dgetinfo DOCROOT "Ce dossier doit être en dehors du serveur web"\
                            "Dossier contenant les documents chargés"
                        echo "dojyraphe $COMMAND $DOCROOT" >> "$tmpwork"
                        ;;
                    "jyrafeau")
                        info_ssl
                        info_site COMMAND "jyrafeau"
                        echo "dojyrafeau $COMMAND" >> "$tmpwork"
                        ;;
                    "unbound")
                        dialog --title "Configuration pour unbound" --yesno "Votre serveur reçoit-il son IP automatiquement avec dhclient? " 20 60
                        local AUTODHCP=$?
                        echo "dounbound $AUTODHCP" >> "$tmpwork"
                        ;;
                    "monitorix")
                        echo "domonitorix" >> "$tmpwork"
                        ;;
                    "openvpn")
                        info_ssl
                        local NDD=""
                        local IP=$(ifconfig | grep 'inet addr:' | grep -v inet6 | grep -vE '127\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | cut -d: -f2 | awk '{ print $1}' | head -1)
                        if [[ "$IP" = "" ]]; then
                            IP=$(wget -qO- ipv4.icanhazip.com)
                        fi
                        local PORT=""
                        local CLIENTS=""

                        dgetinfo NDD "Quel est votre nom de domaine (sans http://)? (ex : truc.domaine.org)" "Configuration openvpn"
                        dgetinfo IP "Quelle est l'IP de l'interface sur laquelle vous voulez OpenVPN?" "Configuration openvpn" "$IP"
                        dgetinfo PORT "Quel port utiliser pour OpenVPN?" "Configuration openvpn" "1194"
                        dgetinfo CLIENTS "Quels sont les clients à créer? (ex : client1 client2 client3) (séparés par des espaces)" "Configuration openvpn"
                        echo "doopenvpn $NDD $IP $PORT \"$CLIENTS\"" >> "$tmpwork"
                        ;;

                esac
            done < "$tmpmenu"

            #securité à faire à la fin
            if [ -n "$(grep -o "securite" "$tmpmenu")" ];then
                echo "dosecurite" >> "$tmpwork" 
            fi

            work "$tmpwork" 2>&1 | tee -a "$LOGFILE" 
            dialog --msgbox "Configuration terminée. \n\
Des informations importantes concernant les ports à ouvrir et les mises à jour futures sont présentes dans le fichier $RAPPORT" 20 60
        ;;
    esac
}

if [ "$1" = "-h" ]; then
    showhelp
fi

if [ "$(id -u)" -ne 0 ]; then
    die "Vous devez éxécuter le script avec les droits superutilisateur (root). Essayez 'sudo $0'"
fi

if [ -f "$1" ]; then
    work "$1" 2>&1 | tee -a "$LOGFILE" 
    exit 0
fi

which dialog >/dev/null || (echo "dialog non trouvé -> On l'installe" && installapt dialog)

dialogmenu

exit 0
