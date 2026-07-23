Name:           t3code-nightly
Version:        0.0.29~nightly.20260723.885
Release:        1%{?dist}
Summary:        Unofficial RPM wrapper for the T3 Code nightly AppImage

License:        MIT AND LicenseRef-Upstream-T3Code
URL:            https://github.com/pingdotgg/t3code
# This package intentionally wraps the upstream AppImage. Do not replace this
# with a "latest" URL: the pinned release URL keeps each RPM build auditable.
Source0:        https://github.com/pingdotgg/t3code/releases/download/v0.0.29-nightly.20260723.885/T3-Code-0.0.29-nightly.20260723.885-x86_64.AppImage
Source1:        t3code-wrapper.sh
Source2:        t3code.desktop
Source3:        LICENSE
Source4:        README.md
Source5:        io.github.pingdotgg.t3code.metainfo.xml

# The upstream AppImage is x86_64-only. Use ExclusiveArch instead of
# BuildArch: x86_64 so Copr can create the SRPM in its source-build
# environment and then build the binary RPM only for x86_64 chroots.
ExclusiveArch:  x86_64
BuildRequires:  desktop-file-utils
BuildRequires:  appstream
Requires:       fuse-libs

# AppImages are self-contained ELF payloads. Fedora's normal brp strip scripts
# can treat the AppImage launcher as a regular ELF binary and strip off the
# embedded filesystem, producing a tiny broken RPM. Keep the upstream artifact
# byte-for-byte intact and avoid dependency/provides scanning inside it.
%global debug_package %{nil}
%global __strip /bin/true
%global __requires_exclude_from ^/opt/t3code/T3Code\\.AppImage$
%global __provides_exclude_from ^/opt/t3code/T3Code\\.AppImage$

%description
T3 Code nightly packaged as an unofficial Fedora RPM wrapper around the
upstream Linux x64 AppImage.

This package does not build T3 Code from source. It installs the upstream
AppImage under /opt/t3code, a small launcher wrapper in /usr/bin, and desktop
integration files for GNOME and other freedesktop.org-compatible desktops.

%prep
# No source unpack or build preparation is needed. Source0 is the upstream
# AppImage artifact from a pinned nightly release.

%build
# No source build steps. This RPM wraps the upstream AppImage as distributed.

%install
install -Dpm0755 %{SOURCE0} %{buildroot}/opt/t3code/T3Code.AppImage
install -Dpm0755 %{SOURCE1} %{buildroot}%{_bindir}/t3code
install -Dpm0644 %{SOURCE2} %{buildroot}%{_datadir}/applications/t3code.desktop
install -Dpm0644 %{SOURCE3} %{buildroot}%{_licensedir}/%{name}/LICENSE
install -Dpm0644 %{SOURCE4} %{buildroot}%{_docdir}/%{name}/README.md
install -Dpm0644 %{SOURCE5} %{buildroot}%{_datadir}/metainfo/io.github.pingdotgg.t3code.metainfo.xml

# Extract the application icon from the AppImage at build time so this
# repository does not need to vendor an upstream image asset with unclear terms.
# If upstream changes the AppImage layout and no icon can be found, fail clearly
# so icon handling can be updated intentionally.
chmod +x %{buildroot}/opt/t3code/T3Code.AppImage
if %{buildroot}/opt/t3code/T3Code.AppImage --appimage-extract > /dev/null 2>&1; then
  icon_path="$(find squashfs-root -type f -path '*/hicolor/512x512/apps/*.png' | sort -V | tail -n 1 || true)"
  if [ -z "$icon_path" ]; then
    icon_path="$(find squashfs-root -type f \( -iname 't3code.png' -o -iname 't3-code.png' -o -iname '*.png' \) | sort -V | tail -n 1 || true)"
  fi
  if [ -n "$icon_path" ]; then
    install -Dpm0644 "$icon_path" %{buildroot}%{_datadir}/icons/hicolor/512x512/apps/t3code.png
  fi
fi
rm -rf squashfs-root

test -f %{buildroot}%{_datadir}/icons/hicolor/512x512/apps/t3code.png

desktop-file-validate %{buildroot}%{_datadir}/applications/t3code.desktop
appstreamcli validate --no-net %{buildroot}%{_datadir}/metainfo/io.github.pingdotgg.t3code.metainfo.xml

%files
%license %{_licensedir}/%{name}/LICENSE
%doc %{_docdir}/%{name}/README.md
/opt/t3code/T3Code.AppImage
%{_bindir}/t3code
%{_datadir}/applications/t3code.desktop
%{_datadir}/metainfo/io.github.pingdotgg.t3code.metainfo.xml
%{_datadir}/icons/hicolor/512x512/apps/t3code.png

%changelog
* Sat Jul 04 2026 Kyle Evans <kyledevans@users.noreply.github.com> - 0.0.29~nightly.20260703.720-5
- Disable the bundled AppImage updater by default so DNF owns application updates.

* Sat Jul 04 2026 Kyle Evans <kyledevans@users.noreply.github.com> - 0.0.29~nightly.20260703.720-4
- Add AppStream metadata so software centers can identify T3 Code as an application.

* Sat Jul 04 2026 Kyle Evans <kyledevans@users.noreply.github.com> - 0.0.29~nightly.20260703.720-3
- Require fuse-libs so the AppImage can load libfuse.so.2 at runtime.

* Sat Jul 04 2026 Kyle Evans <kyledevans@users.noreply.github.com> - 0.0.29~nightly.20260703.720-2
- Preserve the upstream AppImage during RPM post-processing.

* Sat Jul 04 2026 Kyle Evans <kyledevans@users.noreply.github.com> - 0.0.29~nightly.20260703.720-1
- Initial wrapper package for upstream T3 Code nightly AppImage.
