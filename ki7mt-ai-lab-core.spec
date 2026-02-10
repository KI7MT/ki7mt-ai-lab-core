Name:           ki7mt-ai-lab-core
Version:        2.3.2
Release:        1%{?dist}
Summary:        Core database schemas for the KI7MT AI Lab

License:        GPL-3.0-or-later
URL:            https://github.com/KI7MT/ki7mt-ai-lab-core
# Hardcoded Source avoids rpkg naming conflicts
Source0:        https://github.com/KI7MT/ki7mt-ai-lab-core/archive/v%{version}.tar.gz

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
install -d %{buildroot}%{_datadir}/%{name}/scripts

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

# Install population scripts
for sh in scripts/populate_*.sh; do
    install -m 755 "$sh" %{buildroot}%{_datadir}/%{name}/scripts/
done

%post
echo "------------------------------------------------------------"
echo " KI7MT AI Lab Core v%{version} installed successfully."
echo " To finalize the database schema and version stamp, run:"
echo "   ki7mt-lab-db-init --stamp-version"
echo "------------------------------------------------------------"

%files
%license COPYING
%doc README.md
%{_bindir}/ki7mt-lab-db-init
%{_bindir}/ki7mt-lab-env
%dir %{_datadir}/%{name}
%dir %{_datadir}/%{name}/ddl
%dir %{_datadir}/%{name}/scripts
%{_datadir}/%{name}/ddl/*.sql
%{_datadir}/%{name}/scripts/*.sh

%changelog
* Sat Feb 08 2026 Greg Beam <ki7mt@yahoo.com> - 2.3.1-1
- Medallion architecture: rename spots_raw->bronze, model_features->silver, training->gold
- Update README with 15 DDL schemas, convert tables to code blocks for COPR

* Sat Feb 07 2026 Greg Beam <ki7mt@yahoo.com> - 2.3.0-1
- DDL audit: renumber all DDL files to sequential 01-15 (resolve 04/05 conflicts)
- Add DDL for wspr.silver (08) and v_quality_distribution MV (09)
- Add populate_signatures.sh and populate_v6_clean.sh population scripts
- Drop wspr.training_set_v1 (empty, obsolete V1 dev iteration)
- Every ClickHouse table now has a corresponding DDL file
- Align version across all lab packages at 2.3.0

* Wed Feb 04 2026 Greg Beam <ki7mt@yahoo.com> - 2.2.0-1
- Align version across all lab packages at 2.2.0 for Phase 4.1

* Tue Feb 03 2026 Greg Beam <ki7mt@yahoo.com> - 2.1.0-1
- Align version across all lab packages at 2.1.0

* Mon Jan 20 2025 Greg Beam <ki7mt@yahoo.com> - 2.0.3-1
- Sync version across all lab packages
- Fix maintainer email in changelog

* Sun Jan 18 2025 Greg Beam <ki7mt@yahoo.com> - 2.0.0-1
- Major version bump to align with ki7mt-ai-lab-apps v2.0.0

* Fri Jan 17 2025 Greg Beam <ki7mt@yahoo.com> - 1.1.7-1
- Add 01-wspr_schema_v2.sql: 17-column schema synchronized with CUDA wspr_structs.h
- Use FixedString(N) for direct GPU memory mapping
- Add mode and column_count columns
- Change band to Int32 to match live database
- Add migration ALTER statements for v1 to v2 upgrade
- Add schema validation function wspr.fn_validate_schema_v2()

* Fri Jan 17 2025 Greg Beam <ki7mt@yahoo.com> - 1.1.6-1
- Add spec changelog for v1.1.5 and v1.1.6

* Fri Jan 17 2025 Greg Beam <ki7mt@yahoo.com> - 1.1.5-1
- Version sync with ki7mt-ai-lab-cuda

* Fri Jan 16 2025 Greg Beam <ki7mt@yahoo.com> - 1.1.4-1
- Hardcode Source0 URL to avoid rpkg naming conflicts

* Fri Jan 16 2025 Greg Beam <ki7mt@yahoo.com> - 1.1.3-1
- Switch to GitHub archive Source0 for COPR builds
- Add --push flag to bump-version script
