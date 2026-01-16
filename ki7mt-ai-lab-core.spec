Name:           ki7mt-ai-lab-core
Version:        1.0.0
Release:        1%{?dist}
Summary:        Core database schemas for the KI7MT AI Lab

License:        GPL-3.0-or-later
URL:            https://github.com/KI7MT/ki7mt-ai-lab-core
Source0:        %{name}-%{version}.tar.gz

BuildArch:      noarch
BuildRequires:  autoconf
BuildRequires:  automake
BuildRequires:  make

Requires:       clickhouse-server >= 23.0
Requires:       clickhouse-client >= 23.0

%description
Core database schemas for the KI7MT AI Lab WSPR/Solar project.

%prep
%autosetup
./autogen.sh

%build
%configure
%make_build

%install
%make_install

%files
%license COPYING
%doc AUTHORS ChangeLog NEWS README
%{_bindir}/ki7mt-lab-db-init
%{_bindir}/ki7mt-lab-env
%dir %{_datadir}/ki7mt
%dir %{_datadir}/ki7mt/schema
%{_datadir}/ki7mt/schema/01-wspr_schema.sql
%{_datadir}/ki7mt/schema/02-solar_indices.sql
%{_datadir}/ki7mt/schema/03-solar_silver.sql
%{_datadir}/ki7mt/schema/04-data_mgmt.sql
%{_datadir}/ki7mt/schema/05-geo_functions.sql

%changelog
* Wed Jan 15 2025 Greg Beam <ki7mt@yahoo.com> - 1.0.0-1
- Initial release
