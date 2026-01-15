# ==============================================================================
# Name..........: ki7mt-ai-lab-core.spec
# Version.......: 1.0.0
# Purpose.......: RPM spec file for KI7MT AI Lab Core package
# Target OS.....: Rocky Linux 9.x / RHEL 9.x
# Author........: Greg Beam, KI7MT
# ==============================================================================

Name:           ki7mt-ai-lab-core
Version:        1.0.0
Release:        1%{?dist}
Summary:        Core foundation for the KI7MT AI Lab WSPR/Solar Project

License:        GPL-3.0-or-later
URL:            https://github.com/KI7MT/ki7mt-ai-lab-core
Source0:        %{name}-%{version}.tar.gz

BuildArch:      noarch
BuildRequires:  autoconf
BuildRequires:  automake
BuildRequires:  python3 >= 3.8

Requires:       clickhouse-server
Requires:       clickhouse-client
Requires:       bash >= 4.0

%description
ki7mt-ai-lab-core provides the foundational database schemas, environment
configuration, and initialization scripts for the KI7MT AI Lab. This package
sets up the ClickHouse database with optimized schemas for storing 10+ billion
WSPR (Weak Signal Propagation Reporter) spot records and solar flux indices.

Features:
- 15-column WSPR schema optimized for NVMe RAID-0 storage
- LowCardinality string columns for efficient compression
- Idempotent database initialization (safe to run multiple times)
- Environment variables for RAID-0 mount path configuration
- Solar indices schema for propagation correlation analysis

%prep
%setup -q

%build
%configure
%make_build

%install
%make_install

# Create required directories
mkdir -p %{buildroot}%{_localstatedir}/log/%{name}

%post
# ==============================================================================
# POST-INSTALL: Initialize ClickHouse database
# ==============================================================================
# Check if ClickHouse is available before attempting initialization
if systemctl is-active --quiet clickhouse-server; then
    echo "Initializing KI7MT AI Lab database schemas..."
    if %{_bindir}/ki7mt-lab-db-init --auto-confirm; then
        echo "Database initialization complete."
    else
        echo "WARNING: Database initialization failed. Run manually:"
        echo "  sudo ki7mt-lab-db-init"
    fi
else
    echo "NOTE: ClickHouse server is not running."
    echo "      Start ClickHouse and run database initialization:"
    echo "        sudo systemctl start clickhouse-server"
    echo "        sudo ki7mt-lab-db-init"
fi

%postun
# Cleanup on complete removal (not upgrade)
if [ $1 -eq 0 ]; then
    echo "NOTE: Database schemas in ClickHouse were NOT removed."
    echo "      To remove manually:"
    echo "        clickhouse-client --query='DROP DATABASE IF EXISTS wspr'"
fi

%files
%license COPYING
%doc README.md AUDIT_LOG.md
%{_bindir}/ki7mt-lab-db-init
%{_bindir}/ki7mt-lab-env
%{_datadir}/%{name}/ddl/*.sql
%dir %{_datadir}/%{name}
%dir %{_datadir}/%{name}/ddl
%dir %{_localstatedir}/log/%{name}

%changelog
* Tue Jan 14 2026 Greg Beam <ki7mt@yahoo.com> - 1.0.0-1
- Initial RPM release
- 15-column WSPR schema with LowCardinality optimizations
- Idempotent database initialization script
- RAID-0 NVMe path configuration support
- Solar indices schema for propagation analysis
