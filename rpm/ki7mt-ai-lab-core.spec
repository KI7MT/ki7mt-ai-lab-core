# ==============================================================================
# Name..........: ki7mt-ai-lab-core.spec
# Version.......: 1.0.0
# Purpose.......: RPM spec file for KI7MT AI Lab Core package
# Target OS.....: Rocky Linux 9.x / RHEL 9.x (el9)
# COPR Ready....: Yes (SCM integration compatible)
# Build System..: Autotools (configure/make/make install)
# Author........: Greg Beam, KI7MT
# ==============================================================================

Name:           ki7mt-ai-lab-core
Version:        1.0.0
Release:        1%{?dist}
Summary:        Core database schemas for the KI7MT AI Lab WSPR/Solar Project

License:        GPL-3.0-or-later
URL:            https://github.com/KI7MT/ki7mt-ai-lab-core

# COPR SCM Integration - Dynamic source tarball
Source0:        %{name}-%{version}.tar.gz

BuildArch:      noarch

# Build dependencies (Rocky Linux 9 / RHEL 9)
BuildRequires:  autoconf
BuildRequires:  automake
BuildRequires:  make
BuildRequires:  sed
BuildRequires:  coreutils
BuildRequires:  python3 >= 3.8

# Runtime dependencies - Hardened for production lab
Requires:       clickhouse-server >= 23.0
Requires:       clickhouse-client >= 23.0
Requires:       bash >= 4.4

# Weak dependencies for optional features
Recommends:     clickhouse-common-static

%description
ki7mt-ai-lab-core provides the foundational database schemas for the KI7MT AI
Lab. This package installs optimized ClickHouse schemas designed to handle 10+
billion WSPR (Weak Signal Propagation Reporter) spot records with associated
solar flux indices for propagation correlation analysis.

Schema Components:
  01-wspr_schema.sql    - 15-column immutable raw WSPR spots table
  02-solar_indices.sql  - Solar flux indices (SSN, SFI, Ap/Kp)
  03-solar_silver.sql   - Aggregated solar metrics views
  04-data_mgmt.sql      - Database maintenance procedures
  05-geo_functions.sql  - Maidenhead grid UDFs (placeholder)

Utility Scripts:
  ki7mt-lab-db-init     - Database initialization script
  ki7mt-lab-env         - Environment configuration

Target Hardware:
  - AMD Ryzen 9 9950X3D (128GB RAM)
  - Samsung 990 Pro NVMe RAID-0 (8TB)
  - ClickHouse v23+ with LZ4 compression

Installation Path:
  Schemas: %{_datadir}/ki7mt/schema/
  Binaries: %{_bindir}/

# ==============================================================================
# Prep - Extract source tarball
# ==============================================================================
%prep
%autosetup -n %{name}-%{version}

# ==============================================================================
# Build - Autotools configure and make
# ==============================================================================
%build
%configure
%make_build

# ==============================================================================
# Install - Autotools make install
# ==============================================================================
%install
%make_install

# ==============================================================================
# Post-install script
# ==============================================================================
%post
echo ""
echo "================================================================================"
echo "  KI7MT AI Lab Core - Installation Complete"
echo "================================================================================"
echo ""
echo "  SQL schemas installed to: %{_datadir}/ki7mt/schema/"
echo "  Utility scripts installed to: %{_bindir}/"
echo ""
echo "  QUICK START:"
echo "  ------------------------------------------------------------------------------"
echo ""
echo "  1. Ensure ClickHouse server is running:"
echo "     $ sudo systemctl start clickhouse-server"
echo ""
echo "  2. Initialize the database (applies all schemas in order):"
echo "     $ ki7mt-lab-db-init"
echo ""
echo "  3. Or apply schemas manually:"
echo "     $ for sql in %{_datadir}/ki7mt/schema/*.sql; do"
echo "         clickhouse-client < \"\$sql\""
echo "       done"
echo ""
echo "  4. Verify the installation:"
echo "     $ clickhouse-client --query=\"SHOW TABLES FROM wspr\""
echo ""
echo "  NOTE: Views require base tables. Apply schemas in numerical order."
echo ""
echo "================================================================================"
echo ""

# ==============================================================================
# Post-uninstall script
# ==============================================================================
%postun
if [ $1 -eq 0 ]; then
    echo ""
    echo "================================================================================"
    echo "  KI7MT AI Lab Core - Package Removed"
    echo "================================================================================"
    echo ""
    echo "  NOTE: Database schemas in ClickHouse were NOT removed."
    echo ""
    echo "  To manually drop the database and all data:"
    echo "    $ clickhouse-client --query=\"DROP DATABASE IF EXISTS wspr\""
    echo ""
    echo "  WARNING: This will permanently delete all WSPR spot data!"
    echo ""
    echo "================================================================================"
    echo ""
fi

# ==============================================================================
# Files manifest
# ==============================================================================
%files
%license COPYING
%doc README.md

# Binary scripts
%{_bindir}/ki7mt-lab-db-init
%{_bindir}/ki7mt-lab-env

# Schema directory and files
%dir %{_datadir}/ki7mt
%dir %{_datadir}/ki7mt/schema
%{_datadir}/ki7mt/schema/01-wspr_schema.sql
%{_datadir}/ki7mt/schema/02-solar_indices.sql
%{_datadir}/ki7mt/schema/03-solar_silver.sql
%{_datadir}/ki7mt/schema/04-data_mgmt.sql
%{_datadir}/ki7mt/schema/05-geo_functions.sql

# ==============================================================================
# Changelog
# ==============================================================================
%changelog
* Wed Jan 15 2025 Greg Beam <ki7mt@yahoo.com> - 1.0.0-1
- Initial RPM release for Rocky Linux 9 (el9)
- COPR SCM integration ready
- Autotools build system (configure/make/make install)
- 15-column WSPR schema with LowCardinality optimizations
- Solar indices schema for propagation correlation
- Geo functions placeholder for Maidenhead UDFs
- ki7mt-lab-db-init utility for database initialization
- ki7mt-lab-env utility for environment configuration
- Hardened dependencies (clickhouse-client required)
- FHS-compliant installation to %{_datadir}/ki7mt/schema/
