USRBIN=./deb/usr/bin
DOC=./deb/usr/share/doc/hostathome
HAH=./deb/usr/share/hostathome
STOCK=$(HAH)/stock

all:
	mkdir -p $(USRBIN)
	mkdir -p $(DOC)
	mkdir -p $(STOCK)
	cp hah-engine.sh $(HAH)/hah-engine.sh
	cp hostathome-dialog.sh $(USRBIN)/hostathome
	cp -r ./stock/* $(STOCK)
	cp AUTHORS $(DOC)
	cp README.md $(DOC)/README
	cp LICENSE $(DOC)/copyright
	dpkg-deb --build deb hostathome.deb

