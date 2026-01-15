# Name..........: Makefile.am
# Part of.......: @PROGRAM@

# 1. Define the Scripts to be installed in /usr/local/bin
bin_SCRIPTS = src/ki7mt-lab-db-init src/ki7mt-lab-env

# 2. Define the DDL directory (Relative to datadir)
# This creates /usr/local/share/ki7mt-ai-lab-core/ddl/
ddldir = $(datadir)/$(PACKAGE)/ddl

# 3. List the generated SQL files to be installed in that directory
dist_ddl_DATA = \
	src/01-wspr_schema.sql \
	src/02-solar_indices.sql \
	src/03-solar_silver.sql \
	src/04-data_mgmt.sql

# 4. Documentation files to include in the distribution
# Note: COPYING is handled by %license in RPM spec, so it's in EXTRA_DIST only
dist_doc_DATA = README.md AUDIT_LOG.md

# 5. Source template files and license to include in the distribution tarball
EXTRA_DIST = \
	src/01-wspr_schema.sql.in \
	src/02-solar_indices.sql.in \
	src/03-solar_silver.sql.in \
	src/04-data_mgmt.sql.in \
	src/ki7mt-lab-db-init.in \
	src/ki7mt-lab-env.in \
	autogen.sh \
	COPYING

# 6. Clean up the generated files during 'make clean'
CLEANFILES = $(bin_SCRIPTS) $(dist_ddl_DATA)

# 7. Ensure scripts are executable after installation
install-exec-hook:
	chmod +x $(DESTDIR)$(bindir)/ki7mt-lab-db-init
	chmod +x $(DESTDIR)$(bindir)/ki7mt-lab-env