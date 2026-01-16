AC_INIT([ki7mt-ai-lab-core], [1.0.0], [ki7mt@yahoo.com])
AC_CONFIG_AUX_DIR([build-aux])
AC_CONFIG_SRCDIR([src/01-wspr_schema.sql.in])
AM_INIT_AUTOMAKE([foreign -Wall -Werror])

AC_SUBST([PROGRAM], [$PACKAGE_NAME])
AC_SUBST([VERSION], [$PACKAGE_VERSION])
AC_SUBST([COPYRIGHT], ["2024-2026 Greg Beam, KI7MT"])

AC_CONFIG_FILES([
    Makefile
    src/Makefile
    src/01-wspr_schema.sql
    src/02-solar_indices.sql
    src/03-solar_silver.sql
    src/04-data_mgmt.sql
    src/05-geo_functions.sql
    src/ki7mt-lab-db-init
    src/ki7mt-lab-env
])

AC_OUTPUT
