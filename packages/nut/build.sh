#!/usr/bin/env bash
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=packages/nut/version.env
. "$here/version.env"
OUT="$(realpath -m "${1:-dist}")"

export DEBIAN_FRONTEND=noninteractive
export DEBFULLNAME="kyleseneker apt repository"
export DEBEMAIL="apt@invalid"

apt-get update
apt-get install -y --no-install-recommends \
  build-essential ca-certificates curl debian-keyring devscripts dpkg-dev equivs

work="$(mktemp -d)"
cd "$work"
dget --extract "https://deb.debian.org/debian/pool/main/n/nut/nut_${NUT_DEBIAN_VERSION}.dsc"
cd "nut-${NUT_DEBIAN_VERSION%-*}"

dch --force-bad-version --newversion "${NUT_DEBIAN_VERSION}${LOCAL_REVISION}" --distribution trixie --force-distribution \
  "Rebuild of Debian ${NUT_DEBIAN_VERSION} for trixie."
for patch in "$here"/patches/*.patch; do
  [ -e "$patch" ] || continue
  cp "$patch" debian/patches/
  basename "$patch" >> debian/patches/series
  dch --append "Apply $(sed -n 's/^Subject: //p' "$patch")"
done
mk-build-deps --install --remove --tool 'apt-get -y --no-install-recommends' debian/control
dpkg-buildpackage -us -uc -b

mkdir -p "$OUT"
for deb in ../*.deb; do
  case "$deb" in *-dbgsym_*) continue ;; esac
  cp "$deb" "$OUT/$(basename "$deb" | tr '~+' '-.')"
done
