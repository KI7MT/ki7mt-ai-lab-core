Name:           ki7mt-ai-lab-core
Version:        1.1.3
Release:        1%{?dist}
Summary:        Core database schemas for the KI7MT AI Lab

License:        GPL-3.0-or-later
URL:            https://github.com/KI7MT/ki7mt-ai-lab-core
Source0:        https://github.com/KI7MT/%{name}/archive/v%{version}.tar.gz

BuildArch:      noarch

Requires:       clickhouse-server >= 23.0
Requires:       clickhouse-client >= 23.0

%description
Core database schemas and initialization scripts for the KI7MT AI Lab
WSPR/Solar data analysis project. Includes ClickHouse DDL schemas
optimized for 10+ billion rows of propagation data.

%prep
%autosetup -n %{name}-%{version}

%build
# Nothing to build - noarch package

%install
# Create directories
install -d %{buildroot}%{_bindir}
install -d %{buildroot}%{_datadir}/%{name}/ddl

# Install and process scripts (substitute @PROGRAM@ and @VERSION@)
for script in ki7mt-lab-db-init ki7mt-lab-env; do
    sed -e 's|@PROGRAM@|%{name}|g' \
        -e 's|@VERSION@|%{version}|g' \
        src/${script} > %{buildroot}%{_bindir}/${script}
    chmod 755 %{buildroot}%{_bindir}/${script}
done

# Install and process DDL files
for sql in src/*.sql; do
    basename=$(basename "$sql")
    sed -e 's|@PROGRAM@|%{name}|g' \
        -e 's|@VERSION@|%{version}|g' \
        -e 's|@COPYRIGHT@|GPL-3.0-or-later|g' \
        "$sql" > %{buildroot}%{_datadir}/%{name}/ddl/${basename}
done

%files
%license COPYING
%doc README
%{_bindir}/ki7mt-lab-db-init
%{_bindir}/ki7mt-lab-env
%dir %{_datadir}/%{name}
%dir %{_datadir}/%{name}/ddl
%{_datadir}/%{name}/ddl/*.sql

%changelog
* Thu Jan 16 2026 Greg Beam <ki7mt@outlook.com> - 1.1.3-1
- Switch to GitHub archive Source0 for COPR builds
- Add --push flag to bump-version script
