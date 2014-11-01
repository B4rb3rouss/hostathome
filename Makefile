USRBIN=./usr/bin
DOC=./usr/share/doc/hostathome
HAH=./usr/share/hostathome
STOCK=$(HAH)/stock

all:
	mkdir -p $(USRBIN)
	mkdir -p $(DOC)
	mkdir -p $(STOCK)
	cp hah-engine.sh $(HAH)/hah-engine.sh
	cp hostathome-dialog.sh $(USRBIN)/hostathome
	cp -r ./stock/* $(STOCK)
	cp AUTHORS $(DOC)
	cp ReadMe.md $(DOC)/README
	cp LICENCE $(DOC)/copyright
	cd .. && dpkg-deb --build hostathome

