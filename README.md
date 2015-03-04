# Hostathome : l'auto-hébergement facile

Host@home est un simple script shell permettant d'installer le plus
simplement possible son serveur à la maison et donc s'*auto-héberger*.
Il fonctionne avec [debian](http://debian.org) wheezy,
[raspbian](http://www.raspbian.org) et sans doute sur ses dérivées.

L'objectif est le suivant : n'importe qui, avec peu de connaissances en
réseau/serveur/linux devrait pouvoir auto-héberger chez soi les services
dont il a besoin, afin de favoriser un internet décentralisé et les
libertés de chacun. Hostathome doit alors permettre : 

- D'être facile d'utilisation,
- Proposer des programmes légers pouvant tourner sur un maximum de
  machines même de récupération,
- Fournir une configuration de base pour les services,
- Sécuriser au maximum le serveur, ce qui ne doit pas être une prise de
  tête pour le débutant,
- Être conçu de façon à pouvoir ajouter facilement le support de
  nouveaux services.

Pour une utilisation optimale de votre serveur, il est pratique d'avoir
un nom de domaine. Pour plus d'infos, voir [cette partie](#DNS).

- [Page
  "officielle"](http://yeuxdelibad.net/Programmation/Hostathome.html)
- [Hostathome sur github](https://github.com/Ikse/hostathome)

## Sommaire

- [Sécurité par défaut](#secu)
- [Services proposés](#services)
- [Installation](#installation)
- [Utilisation](#utilisation)
- [Configuration](#configuration)
- [Commentaires](#commentaires)
- [Contribuez](#contribuez)
- [Application non supportée](#nonsupportee)
- [Astuces](#DNS)
- [Liens](#liens)
- [Captures d'écran](#scrot)


## Sécurité par défaut <a id="secu"></a>
La fonction qui permet de sécuriser le serveur installer et configure
par défaut : 

- [Fail2ban](http://www.isalo.org/wiki.debian-fr/Fail2ban)
- [Portsentry](http://www.isalo.org/wiki.debian-fr/index.php?title=Portsentry)
- Le parefeu ufw. Voir [sur ce
  wiki](http://wiki.debian-facile.org/doc:systeme:ufw) pour des
  explications sur la modifications de règles.
- Rkhunter pour lutter contre les rootkits.

## Services proposés <a id="services"></a>
Actuellement, le script permet d'installer et d'*auto-héberger* les
services listés ci-dessous. D'autres viendront à l'avenir selon vos
suggestions. Notez que toutes les "webapps", services accessibles via
navigateur internet sont installés avec nginx comme serveur http.

- Installation de services stantards sur un seul nom de domaine. Les
  services sont : 
    - Dropcenter : Mettre des fichiers en ligne (pseudo-cloud) 
    - Kriss : Un lecteur de flux rss
    - Shaarli : Pour partager vos liens/prendre des notes
    - Blogotext : Votre blog
    - Zerobin : Pour coller du texte/discuter de façon privée
    - Dokuwiki : Votre wiki
- un site web via http et/ou https (nginx),
- Un serveur de partage de fichiers avec sftp,
- Serveur VPN avec [OpenVPN](http://openvpn.net),
- Installation de [owncloud](http://owncloud.org), 
- Installation de [Pydio](http://pyd.io) anciennement Ajaxplorer, pour
  l'hébergement de fichiers,
- Un serveur de courriel avec [postfix](http://www.postfix.org) + postgrey + [dovecot](http://www.dovecot.org),
- Un webmail, pour consulter son courrier via navigateur
  ([squirrelmail](http://squirrelmail.org), [rainloop](http://rainloop.net)) ou [roundcube](http://roundcube.net/),
- Un serveur xmpp (jabber) avec [prosody](https://prosody.im),
- Installation de [dropcenter](http://projet.idleman.fr/dropcenter/)
  pour partager les fichiers. N'hésitez pas à installer ensuite
  [dropnew](http://projet.idleman.fr/dropcenter/?page=DropNews) pour
  synchroniser vos fichiers,
- Installation de [pluxml](http://www.pluxml.org/) un moteur de
  blog/CMS,
- Installation de
  [blogoText](http://lehollandaisvolant.net/blogotext/fr/) un moteur de
  blog léger,
- Installation de [Kriss](http://tontof.net/kriss/feed/) un lecteur de
  flux rss très simple, ou de 
  [Tiny Tiny RSS](http://tt-rss.org/redmine/projects/tt-rss/wiki),
- Installation d'un relais [tor](https://www.torproject.org) pour
  participer au réseau,
- Installation de [wallabag](https://www.wallabag.org/) pour sauver des
  pages à lire plus tard,
- Installation de [pico](http://pico.dev7studios.com/), un CMS très
  simple + son éditeur en ligne,
- Installation de [jyraphe](http://home.gna.org/jyraphe/) ou [jirafeau](https://gitlab.com/mojo42/Jirafeau/wikis/home)
, pour déposer
  des fichiers trop lourds à envoyer par mail, et donner le lien de
  téléchargement à un ami,
- Installation de forums ([NoNonsenseForum](http://camendesign.com/nononsense_forum) un forum minimaliste, [FluxBB](http://fluxbb.org/), [phpBB](https://www.phpbb.com/)),
- Installation de
  [Shaarli](http://sebsauvage.net/wiki/doku.php?id=php:shaarli) le
  delicious-like de sebsauvage,
- Installation de
  [ZeroBin](http://sebsauvage.net/wiki/doku.php?id=php:zerobin), le pastebin de sebsauvage,
- Installation d'une seedbox torrent
  ([rtorrent](http://libtorrent.rakshasa.no/) et
  [rutorrent](https://code.google.com/p/rutorrent/)), ou avec
  [transmission](https://www.transmissionbt.com).
- Installation de wikis comme [DokuWiki](https://www.dokuwiki.org/dokuwiki) ou
  [MediaWiki](https://www.mediawiki.org),
- Installation de gestionnaires de listes de tâches : 
[mytinytodo](http://www.mytinytodo.net), 
  [jotter](http://www.yosko.net/article31/jotter-notebook-manager), 
  [kanboard](http://kanboard.net),
- Installation d'un serveur DNS [unbound](http://www.unbound.net),
- Installation de [monitorix](http://www.monitorix.org) pour superviser votre serveur.
- Installation de [Baikal](http://baikal-server.com), un serveur CalDAV et CardDAV

## Installation <a id="installation"></a>

Récupérez la dernière archive
[hostathome-last.tar.gz](http://yeuxdelibad.net/DL/hostathome-last.tar.gz) et décompressez-la avec la commande  : 

    wget http://yeuxdelibad.net/DL/hostathome-last.tar.gz
    tar -xvf hostathome-last.tar.gz
    cd hostathome
    ./hostathome-dialog.sh

Pour profiter de la toute dernière version du script,
vus devrez cependant avoir le paquet *git* d'installé
pour pouvoir accéder à la commande `git`. Récupérez-le avec les commandes
suivantes : 

    git clone https://github.com/Ikse/hostathome.git
  

##Utilisation <a id="utilisation"></a>
Lancez le script simplement `./hostathome-dialog.sh` avec les droits
superutilisateur, puis suivez les
instructions. Le script vous posera alors quelques questions pour
connaître l'emplacement géographique du serveur (certificats ssl
obligent), le dossier où vous souhaitez installer vos services webs, le
[nom de domaine](#DNS) pour accéder à votre site...

Vous pouvez aussi utiliser le script de façon automatisée afin de
simplifier des installations multiples, sur plusieurs serveurs par
exemple.

Pour cela, lancez le script ainsi `./hostathome-dialog.sh config.cfg` où
config.cfg est le fichier de configuration contenant les instructions.
Un exemple est fournit avec le script, il suffit de regarder dans
`hah.cfg`.

Dans tous les cas, **pensez à lire le fichier RAPPORT** créé par le
script après l'avoir utilisé.


##Configuration <a id="configuration"></a>
Certains services nécessitent une configuration manuelle de votre part.
Ces informations sont indiquées dans le fichier RAPPORT généré lors de
l'utilisation de hostathome.

Pour ouvrir les ports de votre routeur, cela dépend du modèle fourni par votre FAI. Plus d'informations [par
ici](https://craym.eu/tutoriels/utilitaires/ouvrir_les_ports_de_sa_box.html)

Voici donc les opérations à effectuer après l'installation de certains
services : 

- Site internet (nginx) : ouvrir et rediriger les ports 80 et 443
- Tor : ouvrir et rediriger le port 9001
- Courriel (postfix) : 
        - ouvrir et rediriger les ports 25, 587, 143, 993.
        - Ajoutez les champs DNS indiqués par le script dans les Zones DNS de votre registrar. La procédure dépend de
        ce dernier. Chez OVH par exemple, cela se passe dans le manager.
        - Pour ajouter une nouvelle adresse de courriel, créez un nouvel utilisateur. 
        Par exemple, pour avoir `toto@$votredomaine.com`, créez l'utilisateur `toto` avec la commande
                `adduser toto`
        - Vous pouvez ensuite configurer un client email. Pour la
          réception, il faut choisir IMAP avec SSL port 993. Pour
          l'envoi, vous pouvez choisir soit le port 25 habituel, ou bien
          le port 587 si votre FAI bloque le 25.
- Tous les services sur https (blogotext, pluxml...) : rediriger et
  ouvrir le port 443
- XMPP : ajouter les zones DNS indiquées chez votre registrar, et ouvrir/rediriger les ports 5222 et 5269. Il vous suffira ensuite d'utiliser un  [client](https://fr.wikipedia.org/wiki/Liste_de_clients_XMPP) comme [gajim](http://gajim.org)
- Le webmail rainloop : Allez sur votre site dans un navigateur à
  l'adresse https://votredomaine?admin (il faut juste rajouter `?admin`,
  puis connectez-vous à l'interface de configuration avec les
  identifiants suivants : 
    - Identifiant : admin
    - Mot de passe (à changer au plus vite) : 12345
- NoNonsenseForum peut être configuré en éditant le fichier config.php
  présent dans le dossier d'installation
- kanboard : les identifiants par défaut sont admin/admin
- Pour la seedbox avec rtorrent, vos téléchargements seront acessibles
  en ajoutant "/downloads" à l'adresse de l'interface web. Exemple
  "https://monrtorrent.domaine.com/downloads",
- Pour augmenter la taille limite des fichiers en upload pour php (Dropcenter, blogotext, owncloud, jyraphe, mediawiki, dokuwiki, pydio), modifiez la ligne suivante dans le fichier de configuration nginx, par exemple/etc/nginx/conf.d/dropcenter.conf

    `client_max_body_size 1000M;`

ainsi que dans le fichier /etc/php5/fpm/php.ini

    `upload_max_filesize = 1000M`
    `post_max_size = 1000M;`


##Vos commentaires <a id="commentaires"></a>
N'hésitez pas à rapporter les bugs, donner des
idées, proposer de nouveaux services ou à
demander de l'aide soit [en me contactant
directement](/Divers/Contact.html) ou bien en ouvrant un fil [sur le
forum](http://forum.yeuxdelibad.net).

##Contribuez! <a id="contribuez"></a>
Il est normalement facile d'ajouter des services à ce script. 
N'hésitez donc pas à contribuer en [me contactant](/Divers/Contact.html)
pour obtenir les droits d'écriture sur le dépôt.

Vous pouvez aussi participer [au dépôt
github](https://github.com/Ikse/hostathome)

##Mon application préférée n'est pas supportée <a id="nonsupportee"></a>

Vous pouvez alors contribuer.

Sinon, peut-être fait-elle partie de cette liste : 

- [seafile](http://www.seafile.com) est excellent pour partager les documents.
  Cependant, il n'est disponible que pour certaines architectures, ce
  qui ne convient pas à la "philosophie" du script.
- [Cozycloud](http://cozy.io) -> L'installation et la mise à jour est un vrai bazar à l'heure actuelle (23/04/14),

## Astuce <a id="DNS"></a>

Pour contacter votre serveur, il est bien plus pratique de taper
"machinbidule.net" que "145.332.210.45" qui est l'ip du serveur ici.
(j'invente hein...).  "machinbidule.net" s'appelle un nom de domaine, ou
enregistrement DNS : en gros, c'est un truc qui dit "tu veux aller à
machinbidule.net? En fait, c'est à l'adresse ip 145.332.210.45". Bien
sûr, ça se passe entre les machines du réseau, et c'est bien plus
pratique pour nous les humains.

Pour en bénéficier, vous pouvez en louer chez des registres comme
[Gandi](www.gandi.net) ou [OVH](www.ovh.com).

Cependant pour commencer je vous conseille des gratuits comme
[no-ip](www.no-ip.com).

Dans tous les cas, la lecture de [cette
page](http://wiki.auto-hebergement.fr/domaines/obtenir_un_domaine) n'est
pas à exclure, c'est sur le wiki d'auto-hébergement.

Petite astuce : il est très pratique d'avoir des sous-domaines. Par
exemple, votre domaine est *mondomaine.com*. Afin de mieux gérer vos
services, vous pouvez créer des sous-domaines du type
*owncloud.mondomaine.com*, *forum.mondomaine.com* ...

Pour cela, créez un champ DNS de type CNAME. Faites-le pointer vers le
nom de domaine principal *mondomaine.com*, et donnez-lui le nom que vous
voulez, par exemple *forum.mondomaine.com*.


## Liens divers <a id="liens"></a>
- [Installation détaillée d'un
  serveur](/Logiciel-libre/Installation_et_securisation_d_un_serveur_auto-heberge.html)
- [YUNoHost](http://yunohost.org) facilite aussi l'auto-hébergement
- [Hostathome sur
  linuxfr](https://linuxfr.org/users/thuban-0/journaux/host-home-faciliter-l-auto-hebergement)

Passez faire un tour sur le wiki
[d'auto-hébergement](http://wiki.auto-hebergement.fr), notamment pour
acquérir un [nom de
domaine](http://wiki.auto-hebergement.fr/domaines/obtenir_un_domaine),
et configurer [votre
routeur et parefeu](http://wiki.auto-hebergement.fr/r%C3%A9seau/routeur/configuration).

##Captures d'écran <a id="scrot"></a>

Petites captures d'écran pour vous montrer : 

[![hostathome1-thumb.jpg](/Images/hostathome1-thumb.jpg)](/Images/hostathome1.png)
[![hostathome2-thumb.jpg](/Images/hostathome2-thumb.jpg)](/Images/hostathome2.png)
[![hostathome3-thumb.jpg](/Images/hostathome3-thumb.jpg)](/Images/hostathome3.png)
