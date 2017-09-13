APP_NAME=lib
PACKAGE=acf-$(APP_NAME)
VERSION=0.10.1

APP_DIST=\
	*.lua\


EXTRA_DIST=README Makefile

DISTFILES=$(APP_DIST) $(EXTRA_DIST)

TAR=tar

P=$(PACKAGE)-$(VERSION)
tarball=$(P).tar.bz2
install_dir=$(DESTDIR)/$(luadir)

all:
clean:
	rm -rf $(tarball) $(P)

dist: $(tarball)

install:
	mkdir -p "$(install_dir)"
	cp -a $(APP_DIST) "$(install_dir)"
	# compatibility symlinks
	for lib in $(APP_DIST); do \
		ln -sf acf/$$lib "$(install_dir)"/../$$lib; \
	done

$(tarball):	$(DISTFILES)
	rm -rf $(P)
	mkdir -p $(P)
	cp -a $(DISTFILES) $(P)
	$(TAR) -jcf $@ $(P)
	rm -rf $(P)

# target that creates a tar package, unpacks is and install from package
dist-install: $(tarball)
	$(TAR) -jxf $(tarball)
	$(MAKE) -C $(P) install DESTDIR=$(DESTDIR)
	rm -rf $(P)

include config.mk

.PHONY: all clean dist install dist-install
