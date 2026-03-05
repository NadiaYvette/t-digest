PKGNAME = t-digest
VERSION = 0.1.0
IDENTIFIER = io.github.NadiaYvette.t-digest
INSTALL_DIR = /usr/local/share/$(PKGNAME)
DOC_DIR = /usr/local/share/doc/$(PKGNAME)
LICENSE_DIR = /usr/local/share/licenses/$(PKGNAME)

SRCROOT = ../..
BUILDDIR = build
STAGEDIR = $(BUILDDIR)/stage
PKGDIR = $(BUILDDIR)/pkg
DMGDIR = $(BUILDDIR)/dmg

.PHONY: all clean pkg dmg stage

all: pkg

stage:
	@echo "Staging files..."
	mkdir -p $(STAGEDIR)$(INSTALL_DIR)/ruby
	mkdir -p $(STAGEDIR)$(INSTALL_DIR)/haskell
	mkdir -p $(STAGEDIR)$(INSTALL_DIR)/common-lisp
	mkdir -p $(STAGEDIR)$(INSTALL_DIR)/scheme
	mkdir -p $(STAGEDIR)$(INSTALL_DIR)/sml
	mkdir -p $(STAGEDIR)$(INSTALL_DIR)/ada
	mkdir -p $(STAGEDIR)$(INSTALL_DIR)/prolog
	mkdir -p $(STAGEDIR)$(INSTALL_DIR)/mercury
	mkdir -p $(STAGEDIR)$(DOC_DIR)
	mkdir -p $(STAGEDIR)$(LICENSE_DIR)

	# Ruby
	cp $(SRCROOT)/ruby/tdigest.rb $(STAGEDIR)$(INSTALL_DIR)/ruby/

	# Haskell
	cp $(SRCROOT)/haskell/TDigest.hs $(STAGEDIR)$(INSTALL_DIR)/haskell/
	cp $(SRCROOT)/haskell/Main.hs $(STAGEDIR)$(INSTALL_DIR)/haskell/

	# Common Lisp
	cp $(SRCROOT)/common-lisp/tdigest.lisp $(STAGEDIR)$(INSTALL_DIR)/common-lisp/
	cp $(SRCROOT)/common-lisp/demo.lisp $(STAGEDIR)$(INSTALL_DIR)/common-lisp/

	# Scheme
	cp $(SRCROOT)/scheme/tdigest.scm $(STAGEDIR)$(INSTALL_DIR)/scheme/
	cp $(SRCROOT)/scheme/demo.scm $(STAGEDIR)$(INSTALL_DIR)/scheme/

	# SML
	cp $(SRCROOT)/sml/tdigest.sml $(STAGEDIR)$(INSTALL_DIR)/sml/
	cp $(SRCROOT)/sml/demo.sml $(STAGEDIR)$(INSTALL_DIR)/sml/
	cp $(SRCROOT)/sml/demo.mlb $(STAGEDIR)$(INSTALL_DIR)/sml/

	# Ada
	cp $(SRCROOT)/ada/tdigest.ads $(STAGEDIR)$(INSTALL_DIR)/ada/
	cp $(SRCROOT)/ada/tdigest.adb $(STAGEDIR)$(INSTALL_DIR)/ada/
	cp $(SRCROOT)/ada/demo.adb $(STAGEDIR)$(INSTALL_DIR)/ada/

	# Prolog
	cp $(SRCROOT)/prolog/tdigest.pl $(STAGEDIR)$(INSTALL_DIR)/prolog/
	cp $(SRCROOT)/prolog/demo.pl $(STAGEDIR)$(INSTALL_DIR)/prolog/

	# Mercury
	cp $(SRCROOT)/mercury/tdigest.m $(STAGEDIR)$(INSTALL_DIR)/mercury/
	cp $(SRCROOT)/mercury/demo.m $(STAGEDIR)$(INSTALL_DIR)/mercury/

	# License
	if [ -f $(SRCROOT)/LICENSE ]; then \
		cp $(SRCROOT)/LICENSE $(STAGEDIR)$(LICENSE_DIR)/; \
	fi

pkg: stage
	@echo "Building macOS installer package..."
	mkdir -p $(PKGDIR)
	pkgbuild \
		--root $(STAGEDIR) \
		--identifier $(IDENTIFIER) \
		--version $(VERSION) \
		--ownership recommended \
		$(PKGDIR)/$(PKGNAME)-$(VERSION).pkg

dmg: pkg
	@echo "Building disk image..."
	mkdir -p $(DMGDIR)
	cp $(PKGDIR)/$(PKGNAME)-$(VERSION).pkg $(DMGDIR)/
	if [ -f $(SRCROOT)/LICENSE ]; then \
		cp $(SRCROOT)/LICENSE $(DMGDIR)/; \
	fi
	hdiutil create \
		-volname "$(PKGNAME)-$(VERSION)" \
		-srcfolder $(DMGDIR) \
		-ov \
		-format UDZO \
		$(BUILDDIR)/$(PKGNAME)-$(VERSION).dmg

clean:
	rm -rf $(BUILDDIR)
