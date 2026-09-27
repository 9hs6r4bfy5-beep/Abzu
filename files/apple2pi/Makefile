DESTDIR=/usr/local
BINDIR=$(DESTDIR)/bin
SBINDIR=$(DESTDIR)/sbin
SHAREDIR=/usr/share/a2pi

BIN=a2joy a2joymou a2joypad a2mon a2term fusea2pi a2pidcmd dskread dskwrite bload brun nibread dskformat eddread
SBIN=a2pid

A2PIDEFS=-DSETSERCLK

all: $(BIN) $(SBIN)

a2pid: a2pid.c gpclk.c
	$(CC) $(A2PIDEFS) a2pid.c -o a2pid

fusea2pi: fusea2pi.c a2lib.c
	$(CC) -I/usr/include/fuse3 -D_FILE_OFFSET_BITS=64 fusea2pi.c -lfuse3 -o fusea2pi

clean:
	-rm -f $(BIN) $(SBIN) *~ *.tar.gz

install:
	-mkdir -p $(BINDIR)
	cp $(BIN) a2mount a2setvd $(BINDIR)
	-mkdir -p $(SBINDIR)
	cp $(SBIN) $(SBINDIR)
	-mkdir -p $(SHAREDIR)
	cp -R ../share/* $(SHAREDIR)
	ln -s $(SHAREDIR)/A2PI-1.8.PO $(SHAREDIR)/A2VD1.PO
	ln -s $(SHAREDIR)/UTILS.PO $(SHAREDIR)/A2VD2.PO

uninstall:
	cd $(BINDIR); rm -f $(BIN) a2mount a2setvd
	cd $(SBINDIR); rm -f $(SBIN)
