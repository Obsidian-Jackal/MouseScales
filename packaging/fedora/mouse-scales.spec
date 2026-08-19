Name:           mouse-scales
Version:        0.1.0
Release:        1%{?dist}
Summary:        Can set pointer speed and extra scale past the desktop slider
License:        BSD-3-Clause
URL:            https://github.com/Obsidian-Jackal/MouseScales
Source0:        %{name}-%{version}.tar.gz

BuildRequires:  meson
BuildRequires:  ninja-build
BuildRequires:  gcc
BuildRequires:  pkgconfig(gtk4)
BuildRequires:  vala
BuildRequires:  desktop-file-utils
BuildRequires:  gtk4
Requires:       gtk4
Recommends:     xinput

%description
GTK4 tool that can set pointer speed and extra scale past the desktop slider
maximum. On X11 it uses libinput Coordinate Transformation Matrix via
xinput. On Wayland it can set reported DPI and optional Hyprland/Sway
extras.

%prep
%autosetup

%build
%meson
%meson_build

%install
%meson_install
desktop-file-validate %{buildroot}%{_datadir}/applications/mouse-scales.desktop

%files
%license LICENSE
%{_bindir}/mouse-scales
%{_datadir}/applications/mouse-scales.desktop
%{_datadir}/icons/hicolor/*/apps/org.obsidian_jackal.MouseScales.png

%changelog
* Mon Aug 17 2026 Obsidian Jackal <enkouyami@gmail.com> - 0.1.0-1
- Initial package with application icons.
