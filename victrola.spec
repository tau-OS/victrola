Name:           victrola
Version:        1.0
Release:        4%{?dist}
Summary:        Play your music, in an elegant way.

License:        GPLv3
URL:            https://tauos.co

Source0:        %{NAME}-%{VERSION}.tar.gz
Source1:        README.md
Source2:        COPYING

Requires:       gtk4
Requires:       libhelium
Requires:       gstreamer1

BuildRequires:  pkgconfig(gstreamer-1.0)
BuildRequires:  pkgconfig(gstreamer-tag-1.0)
BuildRequires:  pkgconfig(gtk4)
BuildRequires:  pkgconfig(gee-0.8)
BuildRequires:  libhelium-devel

BuildRequires:  desktop-file-utils
BuildRequires:  gettext-devel
BuildRequires:  meson
BuildRequires:  vala

%description
Play your music, in an elegant way.

%prep
%autosetup

%build
%meson
%meson_build

%install
%meson_install

# Install licenses
mkdir -p licenses
install -pm 0644 %SOURCE1 licenses/LICENSE

install -pm 0644 %SOURCE2 README.md

%files
%{_bindir}/co.tauos.Victrola
%{_datadir}/dbus-1/*
%{_datadir}/glib-2.0/*
%{_datadir}/icons/*
%{_datadir}/metainfo/*
%{_datadir}/applications/*
%doc README.md
%license licenses/LICENSE

%changelog
* Tue Jun 14 2022 Jamie Murphy <jamie@fyralabs.com> - 1.0-1
- Initial Release
