#!/usr/bin/env bash
set -euo pipefail

python_bin="${PYTHON:-python3}"

if ! command -v "$python_bin" >/dev/null 2>&1; then
  if command -v python >/dev/null 2>&1; then
    python_bin="python"
  else
    printf 'update-nightly: python3 is required\n' >&2
    exit 1
  fi
fi

"$python_bin" <<'PY'
from __future__ import annotations

import json
import re
import sys
import urllib.error
import urllib.request
from pathlib import Path

REPO = "pingdotgg/t3code"
SPEC_FILE = Path("t3code-nightly.spec")
METAINFO_FILE = Path("io.github.pingdotgg.t3code.metainfo.xml")
API_URL = f"https://api.github.com/repos/{REPO}/releases?per_page=50"


def fail(message: str) -> None:
    print(f"update-nightly: {message}", file=sys.stderr)
    raise SystemExit(1)


def fetch_releases() -> list[dict]:
    request = urllib.request.Request(
        API_URL,
        headers={
            "Accept": "application/vnd.github+json",
            "User-Agent": "t3code-copr-updater",
        },
    )
    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            return json.load(response)
    except urllib.error.HTTPError as exc:
        fail(f"GitHub API request failed with HTTP {exc.code}")
    except urllib.error.URLError as exc:
        fail(f"GitHub API request failed: {exc.reason}")


def is_nightly(release: dict) -> bool:
    tag = release.get("tag_name") or ""
    name = release.get("name") or ""
    text = f"{tag} {name}".lower()
    return "nightly" in text


def find_release(releases: list[dict]) -> dict:
    for release in releases:
        if is_nightly(release) and release.get("prerelease"):
            return release
    for release in releases:
        if is_nightly(release):
            return release
    fail(f"no prerelease/nightly release found for {REPO}")


def find_appimage_asset(release: dict) -> dict:
    candidates = []
    for asset in release.get("assets") or []:
        name = asset.get("name") or ""
        if not re.search(r"\.AppImage$", name, re.IGNORECASE):
            continue
        if not re.search(r"(x86_64|x64|amd64|linux)", name, re.IGNORECASE):
            continue
        candidates.append(asset)

    if not candidates:
        fail(f"no Linux x64 AppImage asset found for release {release.get('tag_name')}")

    def score(asset: dict) -> tuple[int, str]:
        name = asset.get("name") or ""
        preferred = 0 if re.search(r"(x86_64|x64|amd64)", name, re.IGNORECASE) else 1
        return preferred, name

    return sorted(candidates, key=score)[0]


def normalize_version(tag: str) -> str:
    raw = tag.removeprefix("v")
    # RPM versions cannot contain hyphens. Use '~' before nightly so pre-release
    # ordering remains lower than a future stable version with the same base.
    raw = raw.replace("-nightly.", "~nightly.", 1)
    raw = raw.replace("-", ".")
    return raw


def replace_line(text: str, field: str, value: str) -> str:
    pattern = rf"^{field}:\s+.*$"
    replacement = f"{field}:        {value}"
    updated, count = re.subn(pattern, replacement, text, count=1, flags=re.MULTILINE)
    if count != 1:
        fail(f"could not update {field} in {SPEC_FILE}")
    return updated


def release_date(release: dict, tag: str) -> str:
    published_at = release.get("published_at") or ""
    if re.match(r"^\d{4}-\d{2}-\d{2}T", published_at):
        return published_at[:10]

    match = re.search(r"nightly\.(\d{4})(\d{2})(\d{2})", tag)
    if match:
        return f"{match.group(1)}-{match.group(2)}-{match.group(3)}"

    fail(f"could not determine release date for {tag}")


def update_metainfo(version: str, date: str) -> None:
    if not METAINFO_FILE.is_file():
        fail(f"missing {METAINFO_FILE}")

    text = METAINFO_FILE.read_text(encoding="utf-8")
    pattern = r'<release version="[^"]+" date="[^"]+" />'
    replacement = f'<release version="{version}" date="{date}" />'
    updated, count = re.subn(pattern, replacement, text, count=1)
    if count != 1:
        fail(f"could not update release metadata in {METAINFO_FILE}")
    METAINFO_FILE.write_text(updated, encoding="utf-8", newline="\n")


def main() -> None:
    if not SPEC_FILE.is_file():
        fail(f"run from the repository root; missing {SPEC_FILE}")

    releases = fetch_releases()
    release = find_release(releases)
    asset = find_appimage_asset(release)

    tag = release.get("tag_name") or ""
    asset_name = asset.get("name") or ""
    source_url = asset.get("browser_download_url") or ""
    if not tag:
        fail("selected release has no tag_name")
    if not source_url:
        fail(f"matching asset {asset_name} has no browser_download_url")

    version = normalize_version(tag)
    date = release_date(release, tag)
    rpm_release = "1%{?dist}"

    text = SPEC_FILE.read_text(encoding="utf-8")
    current_source = re.search(r"^Source0:\s+(\S+)", text, re.MULTILINE)
    current_version = re.search(r"^Version:\s+(\S+)", text, re.MULTILINE)

    if (
        current_source
        and current_source.group(1) == source_url
        and current_version
        and current_version.group(1) == version
    ):
        update_metainfo(version, date)
        print(f"Already current: {tag} ({asset_name})")
        return

    updated = replace_line(text, "Version", version)
    updated = replace_line(updated, "Release", rpm_release)
    updated = replace_line(updated, "Source0", source_url)

    SPEC_FILE.write_text(updated, encoding="utf-8", newline="\n")
    update_metainfo(version, date)
    print(f"Updated {SPEC_FILE} to {tag}")
    print(f"Asset: {asset_name}")


if __name__ == "__main__":
    main()
PY
