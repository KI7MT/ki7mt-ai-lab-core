bin_SCRIPTS = \
    ki7mt-lab-db-init \
    ki7mt-lab-env

schemadir = $(datadir)/ki7mt/schema
schema_DATA = \
    01-wspr_schema.sql \
    02-solar_indices.sql \
    03-solar_silver.sql \
    04-data_mgmt.sql \
    05-geo_functions.sql

EXTRA_DIST = \
    01-wspr_schema.sql.in \
    02-solar_indices.sql.in \
    03-solar_silver.sql.in \
    04-data_mgmt.sql.in \
    05-geo_functions.sql.in \
    ki7mt-lab-db-init.in \
    ki7mt-lab-env.in

CLEANFILES = $(bin_SCRIPTS) $(schema_DATA)

install-exec-hook:
	chmod +x $(DESTDIR)$(bindir)/ki7mt-lab-db-init
	chmod +x $(DESTDIR)$(bindir)/ki7mt-lab-env
