PREFIX=$(HOME)/.local
#PREFIX=/usr/local

BINDIR=$(PREFIX)/bin
APPSDIR=$(PREFIX)/share/applications

mkdir:
	mkdir -p $(BINDIR) $(APPSDIR)

install: mkdir
	cp -f playtag $(BINDIR)
	cp -f vlc+playtag.desktop $(APPSDIR)

lninstall: mkdir
	ln -fs $(abspath playtag) $(BINDIR)
	ln -fs $(abspath vlc+playtag.desktop) $(APPSDIR)

uninstall:
	rm -f $(BINDIR)/playtag $(APPSDIR)/vlc+playtag.desktop

.PHONY: mkdir install lninstall uninstall


README.html: README.md
	pandoc -s -f markdown_github $^ -o $@

clean:
	rm -f README.html
.PHONY: clean
