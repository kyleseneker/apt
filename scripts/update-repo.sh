#!/usr/bin/env bash
set -euo pipefail

DIST="$(realpath "$1")"
SITE="$(realpath "$2")"
SUITE="${SUITE:-trixie}"
ARCHES="${ARCHES:-amd64}"
COMPONENT=main
: "${APT_SIGNING_KEY:?APT_SIGNING_KEY must hold the armored private signing key}"

for deb in "$DIST"/*.deb; do
  source_name="$(dpkg-deb --field "$deb" Source | cut -d' ' -f1)"
  source_name="${source_name:-$(dpkg-deb --field "$deb" Package)}"
  dir="$SITE/pool/$COMPONENT/${source_name:0:1}/$source_name"
  target="$dir/$(basename "$deb")"
  if [ -e "$target" ]; then
    cmp -s "$deb" "$target" || { echo "refusing to replace $target with a different build" >&2; exit 1; }
    continue
  fi
  mkdir -p "$dir"
  cp "$deb" "$target"
done

cp "$(dirname "$0")/../kyleseneker-apt.asc" "$SITE/"
touch "$SITE/.nojekyll"

cd "$SITE"
for arch in $ARCHES; do
  index="dists/$SUITE/$COMPONENT/binary-$arch"
  mkdir -p "$index"
  apt-ftparchive --arch "$arch" packages "pool/$COMPONENT" > "$index/Packages"
  gzip -9nkf "$index/Packages"
done

release="$(mktemp)"
apt-ftparchive \
  -o APT::FTPArchive::Release::Origin=kyleseneker \
  -o APT::FTPArchive::Release::Label=kyleseneker \
  -o APT::FTPArchive::Release::Suite="$SUITE" \
  -o APT::FTPArchive::Release::Codename="$SUITE" \
  -o APT::FTPArchive::Release::Architectures="$ARCHES" \
  -o APT::FTPArchive::Release::Components="$COMPONENT" \
  release "dists/$SUITE" > "$release"
mv "$release" "dists/$SUITE/Release"

GNUPGHOME="$(mktemp -d)"
export GNUPGHOME
printf '%s\n' "$APT_SIGNING_KEY" | gpg --batch --quiet --import
gpg --batch --yes --clearsign --output "dists/$SUITE/InRelease" "dists/$SUITE/Release"
gpg --batch --yes --armor --detach-sign --output "dists/$SUITE/Release.gpg" "dists/$SUITE/Release"
rm -rf "$GNUPGHOME"
