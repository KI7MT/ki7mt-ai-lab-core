SUBDIRS = src

dist_doc_DATA = AUTHORS COPYING ChangeLog NEWS README

EXTRA_DIST = autogen.sh ki7mt-ai-lab-core.spec

# clean-local: for rebuild cycles
clean-local:
	-rm -rf $(PACKAGE)-$(VERSION)
	-rm -f $(PACKAGE)-*.tar.gz

# distclean-local: removes everything (pristine source state)
distclean-local:
	-rm -rf autom4te.cache
	-rm -rf build-aux
	-rm -f aclocal.m4 configure
	-rm -f Makefile.in src/Makefile.in
