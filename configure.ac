# ==============================================================================
# Name..........: configure.ac
# Project.......: ki7mt-ai-lab-core
# Version.......: 1.0.0
# Purpose.......: Autoconf configuration for KI7MT AI Lab Core schemas
# Target OS.....: Rocky Linux 9.x / RHEL 9.x (el9)
# Author........: Greg Beam, KI7MT
# ==============================================================================
# Process this file with -*- autoconf -*- to produce the configure script
# ==============================================================================
AC_PREREQ([2.69])
AC_INIT([ki7mt-ai-lab-core],[1.0.0],[https://github.com/KI7MT/ki7mt-ai-lab-core/issues],[],[https://github.com/KI7MT/ki7mt-ai-lab-core])
AC_CONFIG_AUX_DIR([build-aux])
AM_INIT_AUTOMAKE([foreign -Wall -Werror])

AC_MSG_NOTICE([ki7mt-ai-lab-core - Core Database Schemas for the KI7MT AI Lab])

# ==============================================================================
# Lab Metadata (substituted into templates)
# ==============================================================================
LAB_AUTHOR="Greg Beam, KI7MT"
LAB_COPYRIGHT="Copyright (C) 2024-2026 Greg Beam, KI7MT"
LAB_LICENSE="GPL-3.0-or-later"

AC_SUBST([PROGRAM], ["$PACKAGE_NAME"])
AC_SUBST([VERSION], ["$PACKAGE_VERSION"])
AC_SUBST([AUTHORS], ["$LAB_AUTHOR"])
AC_SUBST([COPYRIGHT], ["$LAB_COPYRIGHT"])
AC_SUBST([LICENSE], ["$LAB_LICENSE"])

# ==============================================================================
# Lab Dependencies
# ==============================================================================

# 1. Check for ClickHouse Client (required for db-init script)
AC_PATH_PROG([CLICKHOUSE], [clickhouse-client], [no])
if test "$CLICKHOUSE" = "no"; then
   AC_MSG_ERROR([clickhouse-client is required but not found. Please install clickhouse-common-static.])
fi

# 2. Check for Python3 (for future notebook automation)
AM_PATH_PYTHON([3.8], [], [AC_MSG_WARN([python3 (>= 3.8) not found. Some features disabled.])])

# 3. Generate Build Timestamp
BUILD_DATE=$(date "+%Y-%m-%d %H:%M:%S")
AC_SUBST([BUILD_DATE])

# ==============================================================================
# Storage Path Configuration (RAID-0 NVMe Defaults)
# ==============================================================================

# WSPR Data Directory
AC_ARG_WITH([wspr-data],
  [AS_HELP_STRING([--with-wspr-data=DIR], [Location of WSPR data (default: /mnt/ai-stack/wspr-data)])],
  [WSPR_DATA_DIR="$withval"],
  [WSPR_DATA_DIR="/mnt/ai-stack/wspr-data"])
AC_SUBST([WSPR_DATA_DIR])

# Solar Data Directory
AC_ARG_WITH([solar-data],
  [AS_HELP_STRING([--with-solar-data=DIR], [Location of Solar data (default: /mnt/ai-stack/solar-data)])],
  [SOLAR_DATA_DIR="$withval"],
  [SOLAR_DATA_DIR="/mnt/ai-stack/solar-data"])
AC_SUBST([SOLAR_DATA_DIR])

# ClickHouse Data Directory
AC_ARG_WITH([clickhouse-data],
  [AS_HELP_STRING([--with-clickhouse-data=DIR], [Location of ClickHouse data (default: /mnt/ai-stack/clickhouse)])],
  [CLICKHOUSE_DATA_DIR="$withval"],
  [CLICKHOUSE_DATA_DIR="/mnt/ai-stack/clickhouse"])
AC_SUBST([CLICKHOUSE_DATA_DIR])

# ==============================================================================
# Output Files
# ==============================================================================
# Autotools processes .in files -> output files via AC_CONFIG_FILES
# ==============================================================================

AC_CONFIG_FILES([
    Makefile
    src/ki7mt-lab-db-init
    src/ki7mt-lab-env
    database/clickhouse/01-wspr_schema.sql
    database/clickhouse/02-solar_indices.sql
    database/clickhouse/03-solar_silver.sql
    database/clickhouse/04-data_mgmt.sql
    database/clickhouse/05-geo_functions.sql
])
AC_OUTPUT

# ==============================================================================
# Configuration Summary
# ==============================================================================
AC_MSG_NOTICE([

  ==============================================================================
  Configuration Complete: $PACKAGE_NAME v$PACKAGE_VERSION
  ==============================================================================

  Build Tools:
    Python..........: $PYTHON
    ClickHouse......: $CLICKHOUSE

  Storage Paths (RAID-0 NVMe):
    WSPR Data.......: $WSPR_DATA_DIR
    Solar Data......: $SOLAR_DATA_DIR
    ClickHouse Data.: $CLICKHOUSE_DATA_DIR

  Installation Paths:
    Prefix..........: $prefix
    Binaries........: $bindir
    Schemas.........: $datadir/ki7mt/schema

  Next Steps:
    make              # Process templates
    sudo make install # Install to system

  Override paths with:
    ./configure --with-wspr-data=/custom/path \\
                --with-solar-data=/custom/path \\
                --with-clickhouse-data=/custom/path

  ==============================================================================

])
