# ------------------------------------------------------------------------------
# Process this file with -*- autoconf -*- to produce the configure script
# ------------------------------------------------------------------------------
AC_PREREQ([2.69])
AC_INIT([ki7mt-ai-lab-core],[1.0.0],[https://github.com/KI7MT/ki7mt-ai-lab-core/issues],[],[https://github.com/KI7MT/ki7mt-ai-lab-core])
AM_INIT_AUTOMAKE([foreign -Wall -Werror])

AC_MSG_NOTICE([ki7mt-ai-lab-core - Infrastructure & Data Plane for the AI Lab.])

# Lab Metadata
LAB_AUTHOR="Greg Beam, KI7MT"
LAB_COPYRIGHT="Copyright (C) 2014-2026 Greg Beam, KI7MT"
LAB_LICENSE="GPL-3"

# Substitution Variables
AC_SUBST([PROGRAM], ["$PACKAGE_NAME"])
AC_SUBST([VERSION], ["$PACKAGE_VERSION"])
AC_SUBST([AUTHORS], ["$LAB_AUTHOR"])
AC_SUBST([COPYRIGHT], ["$LAB_COPYRIGHT"])
AC_SUBST([LICENSE], ["$LAB_LICENSE"])

# --- Lab Dependencies ---

# 1. Check for ClickHouse Client (The primary data driver)
AC_PATH_PROG([CLICKHOUSE], [clickhouse-client], [no])
if test "$CLICKHOUSE" = "no"; then
   AC_MSG_ERROR([clickhouse-client is required but not found. Please install clickhouse-common-static.])
fi

# 2. Check for Python3 (For Phase 8/9 Notebook automation)
AM_PATH_PYTHON([3.8], [], [AC_MSG_ERROR([python3 (>= 3.8) is required but not found.])])

# 3. Generate Build Timestamp
BUILD_DATE=$(date "+%Y-%m-%d %H:%M:%S")
AC_SUBST([BUILD_DATE])

# Configure WSPR Data Directory
AC_ARG_WITH([wspr-data],
  [AS_HELP_STRING([--with-wspr-data=DIR], [Location of WSPR data (default: /opt/wspr-mcp/data)])],
  [WSPR_DATA_DIR="$withval"],
  [WSPR_DATA_DIR="/opt/wspr-mcp/data"])
AC_SUBST([WSPR_DATA_DIR])

# Configure Solar Data Directory
AC_ARG_WITH([solar-data],
  [AS_HELP_STRING([--with-solar-data=DIR], [Location of Solar data (default: /opt/solar-mcp/data)])],
  [SOLAR_DATA_DIR="$withval"],
  [SOLAR_DATA_DIR="/opt/solar-mcp/data"])
AC_SUBST([SOLAR_DATA_DIR])

# --- Output ---
AC_CONFIG_FILES([
    Makefile
    src/ki7mt-lab-db-init
    src/ki7mt-lab-env
    src/01-wspr_schema.sql
    src/02-solar_indices.sql
    src/03-solar_silver.sql
    src/04-data_mgmt.sql
])
AC_OUTPUT

AC_MSG_NOTICE([

  Configuration Complete:
  Program....: $PACKAGE_NAME
  Version....: $PACKAGE_VERSION
  Python.....: $PYTHON
  ClickHouse.: $CLICKHOUSE

])