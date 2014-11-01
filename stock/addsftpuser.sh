#!/bin/sh

### Création d'un utilisateur, qui n'a pas de shell
# et ne peut donc nuire au serveur
# On ne lui crée pas de /home/utilisateur non plus.
adduser --shell /bin/false --no-create-home "$1"

### On ajoute l'utilisateur au groupe sftpusers
usermod -a -G sftpusers "$1"

### On crée le répertoire utilisateur dans le chroot
mkdir -p "${CHROOTDIR}/home/$1"

### Accès seulement (pas d'ecriture) au dossier de l'utilisateur
chmod 555 "${CHROOTDIR}/home/$1"

### Création des dossiers public et prive
mkdir -p "${CHROOTDIR}/home/$1/public"
mkdir -p "${CHROOTDIR}/home/$1/prive"

### Seul l'utilisateur a le droit d'aller dans prive
chmod 700 "${CHROOTDIR}/home/$1/prive"

### public accessible par tous
chmod 755 "${CHROOTDIR}/home/$1/public"

### On rend l'utilisateur propriétaire de son répertoire
chown -R $1:$1 "${CHROOTDIR}/home/$1"

# ajout de l'utilisateur pour sshd_config
sed -i "s/AllowUsers.*/& $1/" /etc/ssh/sshd_config

service ssh restart

exit 0
