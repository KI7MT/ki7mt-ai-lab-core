# ==============================================================================
# Name..........: Makefile.am
# Project.......: ki7mt-ai-lab-core
# Version.......: 1.0.0
# Purpose.......: Automake configuration for KI7MT AI Lab Core schemas
# Target OS.....: Rocky Linux 9.x / RHEL 9.x (el9)
# Author........: Greg Beam, KI7MT
# ==============================================================================
# Installation Paths:
#   Binaries......: $(bindir)             -> /usr/bin or /usr/local/bin
#   Schemas.......: $(datadir)/ki7mt/schema -> /usr/share/ki7mt/schema
# ==============================================================================

# ==============================================================================
# 1. BINARY SCRIPTS (installed to $(bindir))
# ==============================================================================
bin_SCRIPTS = \
	src/ki7mt-lab-db-init \
	src/ki7mt-lab-env

# ==============================================================================
# 2. SQL SCHEMA FILES (installed to $(datadir)/ki7mt/schema)
# ==============================================================================
# Custom directory for schema files (FHS compliant)
schemadir = $(datadir)/ki7mt/schema

# Generated .sql files to install
dist_schema_DATA = \
	database/clickhouse/01-wspr_schema.sql \
	database/clickhouse/02-solar_indices.sql \
	database/clickhouse/03-solar_silver.sql \
	database/clickhouse/04-data_mgmt.sql \
	database/clickhouse/05-geo_functions.sql

# ==============================================================================
# 3. DOCUMENTATION FILES
# ==============================================================================
dist_doc_DATA = README.md

# ==============================================================================
# 4. DISTRIBUTION EXTRAS
# ==============================================================================
# Source templates and license included in 'make dist' tarball
EXTRA_DIST = \
	database/clickhouse/01-wspr_schema.sql.in \
	database/clickhouse/02-solar_indices.sql.in \
	database/clickhouse/03-solar_silver.sql.in \
	database/clickhouse/04-data_mgmt.sql.in \
	database/clickhouse/05-geo_functions.sql.in \
	src/ki7mt-lab-db-init.in \
	src/ki7mt-lab-env.in \
	rpm/ki7mt-ai-lab-core.spec \
	autogen.sh \
	COPYING

# ==============================================================================
# 5. CLEANUP
# ==============================================================================
# Remove generated files during 'make clean'
CLEANFILES = \
	$(bin_SCRIPTS) \
	database/clickhouse/01-wspr_schema.sql \
	database/clickhouse/02-solar_indices.sql \
	database/clickhouse/03-solar_silver.sql \
	database/clickhouse/04-data_mgmt.sql \
	database/clickhouse/05-geo_functions.sql

# ==============================================================================
# 6. POST-INSTALL HOOK
# ==============================================================================
# Ensure scripts are executable after installation
install-exec-hook:
	chmod +x $(DESTDIR)$(bindir)/ki7mt-lab-db-init
	chmod +x $(DESTDIR)$(bindir)/ki7mt-lab-env

# ==============================================================================
# 7. CUSTOM TARGETS
# ==============================================================================

# Lint target - Validate SQL syntax using clickhouse-format
.PHONY: lint
lint:
	@printf "\033[0;34m[LINT]\033[0m Validating SQL schema files...\n"
	@for sql in $(srcdir)/database/clickhouse/*.sql.in; do \
		base=$$(basename $$sql .sql.in); \
		printf "  Checking $$base... "; \
		temp=$$(mktemp --suffix=.sql); \
		sed 's/@[A-Z_]*@/placeholder/g' $$sql > $$temp; \
		if clickhouse-format --query "$$(cat $$temp)" >/dev/null 2>&1; then \
			printf "\033[0;32mOK\033[0m\n"; \
		else \
			printf "\033[1;33mSKIP\033[0m (complex DDL)\n"; \
		fi; \
		rm -f $$temp; \
	done
	@printf "\033[0;32m[OK]\033[0m SQL lint complete\n"

# RPM build target (for local development)
.PHONY: rpm
rpm: dist
	@printf "\033[0;34m[RPM]\033[0m Building RPM from distribution tarball...\n"
	@mkdir -p $(HOME)/rpmbuild/{BUILD,BUILDROOT,RPMS,SOURCES,SPECS,SRPMS}
	@cp $(PACKAGE)-$(VERSION).tar.gz $(HOME)/rpmbuild/SOURCES/
	@cp $(srcdir)/rpm/$(PACKAGE).spec $(HOME)/rpmbuild/SPECS/
	rpmbuild -ba $(HOME)/rpmbuild/SPECS/$(PACKAGE).spec
	@printf "\033[0;32m[OK]\033[0m RPM build complete\n"
	@printf "\033[0;34m[INFO]\033[0m RPM location: $(HOME)/rpmbuild/RPMS/noarch/\n"

# ==============================================================================
# 8. LOCAL CLEAN TARGET
# ==============================================================================
# Removes all Autotools-generated artifacts for a fresh local rebuild.
# Does not affect git or prepare for COPR - just cleans build artifacts.
#
# Usage: make local-clean
# ==============================================================================
.PHONY: local-clean
local-clean:
	@printf "\033[0;34m[LOCAL-CLEAN]\033[0m Removing build artifacts...\n"
	@# Run distclean if Makefile exists
	@if [ -f Makefile ]; then \
		$(MAKE) distclean 2>/dev/null || true; \
	fi
	@# Remove Autotools-generated files
	@rm -f  configure configure~ aclocal.m4 Makefile.in
	@rm -f  config.log config.status config.h config.h.in stamp-h1
	@rm -f  install-sh missing compile depcomp ltmain.sh
	@rm -f  Makefile
	@rm -f  $(PACKAGE)-*.tar.gz
	@# Remove Autotools cache directories
	@rm -rf autom4te.cache build-aux
	@# Remove generated SQL files
	@rm -f  database/clickhouse/*.sql
	@# Remove generated scripts
	@rm -f  src/ki7mt-lab-db-init src/ki7mt-lab-env
	@printf "\033[0;32m[OK]\033[0m Clean complete. Run ./autogen.sh to rebuild.\n"

# ==============================================================================
# 9. COPR CLEAN TARGET
# ==============================================================================
# Removes ALL Autotools-generated artifacts for pristine COPR SCM submission.
# After running this, only source files remain (suitable for git commit/push).
#
# Files preserved:
#   - autogen.sh, configure.ac, Makefile.am (Autotools source)
#   - database/clickhouse/*.sql.in (SQL templates)
#   - src/*.in (script templates)
#   - rpm/*.spec, README.md, COPYING (documentation)
#
# Usage: make copr-clean
# ==============================================================================
.PHONY: copr-clean
copr-clean:
	@printf "\033[0;34m[COPR-CLEAN]\033[0m Removing all Autotools-generated artifacts...\n"
	@# Run distclean if Makefile exists (handles most cleanup)
	@if [ -f Makefile ]; then \
		$(MAKE) distclean 2>/dev/null || true; \
	fi
	@# Remove Autotools-generated files
	@rm -f  configure configure~ aclocal.m4 Makefile.in
	@rm -f  config.log config.status config.h config.h.in stamp-h1
	@rm -f  install-sh missing compile depcomp ltmain.sh
	@rm -f  Makefile
	@rm -f  $(PACKAGE)-*.tar.gz
	@# Remove Autotools cache directories
	@rm -rf autom4te.cache build-aux
	@# Remove generated SQL files
	@rm -f  database/clickhouse/*.sql
	@# Remove generated scripts
	@rm -f  src/ki7mt-lab-db-init src/ki7mt-lab-env
	@# Remove any backup files
	@find . -name "*~" -type f -delete 2>/dev/null || true
	@find . -name "*.bak" -type f -delete 2>/dev/null || true
	@printf "\033[0;32m[OK]\033[0m Repository is now pristine for COPR SCM.\n"
	@printf "\n"
	@printf "  Remaining source files:\n"
	@printf "    - autogen.sh, configure.ac, Makefile.am\n"
	@printf "    - database/clickhouse/*.sql.in\n"
	@printf "    - src/*.in\n"
	@printf "    - rpm/ki7mt-ai-lab-core.spec\n"
	@printf "    - README.md, COPYING\n"
	@printf "\n"
	@printf "  To rebuild: ./autogen.sh && make\n"
	@printf "\n"
