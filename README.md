# t3code-copr

Unofficial Fedora/Copr wrapper package for T3 Code nightly.

This repository packages the upstream Linux x64 AppImage from
[`pingdotgg/t3code`](https://github.com/pingdotgg/t3code) as an RPM named
`t3code-nightly`. It does not build T3 Code from source and does not vendor the
AppImage into git.

The wrapper approach keeps the repo small while still giving Fedora users a
DNF-managed install and update flow, GNOME launcher integration, and fewer
Flatpak sandbox frictions for local developer tooling.

## Package Layout

The RPM installs:

```text
/opt/t3code/T3Code.AppImage
/usr/bin/t3code
/usr/share/applications/t3code.desktop
/usr/share/icons/hicolor/512x512/apps/t3code.png
```

The icon is extracted from the upstream AppImage during RPM build when possible.
No upstream icon assets are committed here because their redistribution terms
should be confirmed before vendoring. If extraction stops working, keep the
package functional and treat icon handling as the explicit TODO.

## Build Locally

Install basic RPM tooling:

```bash
sudo dnf install rpm-build rpmdevtools python3 desktop-file-utils
```

Create a source RPM:

```bash
rpmdev-setuptree
spectool -g -R t3code-nightly.spec
cp t3code-wrapper.sh t3code.desktop LICENSE README.md ~/rpmbuild/SOURCES/
rpmbuild -bs t3code-nightly.spec
```

Optionally build in `mock` for Fedora:

```bash
sudo dnf install mock
sudo usermod -aG mock "$USER"
newgrp mock
mock -r fedora-rawhide-x86_64 --rebuild ~/rpmbuild/SRPMS/t3code-nightly-*.src.rpm
```

For a local binary build without `mock`:

```bash
rpmbuild -bb t3code-nightly.spec
sudo dnf install ~/rpmbuild/RPMS/x86_64/t3code-nightly-*.rpm
```

Verify the installed files:

```bash
rpm -ql t3code-nightly
test -x /opt/t3code/T3Code.AppImage
test -x /usr/bin/t3code
desktop-file-validate /usr/share/applications/t3code.desktop
t3code
```

## Copr Setup

Intended Copr configuration:

1. Create a Copr project named `t3code-nightly`.
2. Add this GitHub repository as an SCM/Git package source.
3. Point Copr at `t3code-nightly.spec`.
4. Select the `make srpm` SRPM build method. The checked-in `.copr/Makefile`
   downloads the pinned upstream AppImage from `Source0` before creating the
   source RPM. It passes `--target x86_64` because Copr may run the SRPM
   generator on a non-x86_64 builder even though the package is x86_64-only.
5. Enable internet access during builds so the pinned upstream AppImage can be
   downloaded.
6. Enable webhook/autorebuild if supported.
7. Alternatively, trigger Copr builds manually after the GitHub Action updates
   the spec.

Once Copr is configured:

```bash
sudo dnf copr enable <user>/t3code-nightly
sudo dnf install t3code-nightly
```

Update through DNF:

```bash
sudo dnf upgrade
```

## Nightly Updates

`update-nightly.sh` checks GitHub Releases for the newest T3 Code nightly
prerelease, finds the Linux x64 AppImage, normalizes the upstream tag into an
RPM-safe version, and updates `t3code-nightly.spec` only when a newer pinned
release URL is available.

Run it manually:

```bash
sudo dnf install python3
./update-nightly.sh
git diff
```

The GitHub Actions workflow runs the same script every 6 hours and on manual
dispatch. It commits and pushes only when the spec changed.

## Licensing

The packaging files in this repository are licensed under the MIT License.
T3 Code itself is distributed by upstream. This wrapper package does not change
or relicense upstream T3 Code or its AppImage contents.
