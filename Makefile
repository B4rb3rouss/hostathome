VERSION=0.8
USRBIN=./hostathome-$(VERSION)/usr/bin
DOC=./hostathome-$(VERSION)/usr/share/doc/hostathome
HAH=./hostathome-$(VERSION)/usr/share/hostathome
STOCK=$(HAH)/stock



all:
	cd .. && tar cvzf hostathome_$(VERSION).orig.tar.gz hostathome/
	mv ../hostathome_$(VERSION).orig.tar.gz .
	mkdir -p $(USRBIN)
	mkdir -p $(DOC)
	mkdir -p $(STOCK)
	cp hah-engine.sh $(HAH)/hah-engine.sh
	cp hostathome-dialog.sh $(USRBIN)/hostathome
	cp -r ./stock/* $(STOCK)
	cp AUTHORS $(DOC)
	cp README.md $(DOC)/README
	cp LICENSE $(DOC)/copyright
	cd hostathome-$(VERSION) && dh_make -e thuban@yeuxdelibad.net -s -c gpl3
	cd hostathome-$(VERSION) && dh_fixperms
	cd hostathome-$(VERSION) && dh_md5sums
	sed -i "s/Section: unknown/Section: misc/" hostathome-$(VERSION)/debian/control
	sed -i "s;Homepage: <insert the upstream URL, if relevant>;Homepage: http://yeuxdelibad.net/Programmation/Hostathome.html;" hostathome-$(VERSION)/debian/control
	sed -i "s/Description:.*/Description: Script to install your own server at home \n    Ease the installation of a server\n    with some services such as http, ssh, sftp\n    mail or webapps like owncloud or webmails.\n    Basic security is also supported with fail2ban/" hostathome-$(VERSION)/debian/control
	cd hostathome-$(VERSION) && dpkg-buildpackage 

clean:
	rm -rf hostathome-$(VERSION)
	rm hostathome_$(VERSION).orig.tar.gz 
