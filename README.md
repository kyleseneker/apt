# apt

A signed APT repository for Debian packages rebuilt for
[homelab](https://github.com/kyleseneker/homelab), served at
<https://kyleseneker.github.io/apt>.

| Package | Version | Suite | Reason |
|---------|---------|-------|--------|
| `nut` | `2.8.5-1~homelab13+2` | trixie, amd64 | Debian's 2.8.5-1 rebuilt for trixie. 2.8.5 stops `usbhid-ups` reconnecting on transient USB I/O errors ([homelab ADR-031](https://github.com/kyleseneker/homelab/blob/main/docs/decisions/031-nut-backport.md)). Carries upstream [edc06fb](https://github.com/networkupstools/nut/commit/edc06fb39435b892d5daeec53cb4845cb12d1d50), which stops 2.8.5 accepting a truncated report descriptor. |

## Usage

Install the signing key and check its fingerprint,
`B043 D209 DC86 9A98 ABD2  A7E2 9CD2 4D1B 3352 E76B`:

```bash
sudo install -d -m 0755 /etc/apt/keyrings
sudo curl -fsSLo /etc/apt/keyrings/kyleseneker-apt.asc https://kyleseneker.github.io/apt/kyleseneker-apt.asc
gpg --show-keys /etc/apt/keyrings/kyleseneker-apt.asc
```

Add the source in `/etc/apt/sources.list.d/kyleseneker.sources`:

```text
Types: deb
URIs: https://kyleseneker.github.io/apt
Suites: trixie
Components: main
Signed-By: /etc/apt/keyrings/kyleseneker-apt.asc
```

Limit the repository to the packages you want from it in
`/etc/apt/preferences.d/kyleseneker`:

```text
Package: *
Pin: release o=kyleseneker
Pin-Priority: 1

Package: nut nut-client nut-server libupsclient7 libnutscan4
Pin: release o=kyleseneker
Pin-Priority: 500
```

## Publishing

- `packages/<name>/build.sh` rebuilds a Debian source package in a `debian:trixie`
  container. `dget` verifies the source package's signature against the Debian keyring.
  `version.env` sets the Debian version and the local revision. Upstream fixes that are
  not released yet go in `packages/<name>/patches/` and are added to the Debian patch
  series.
- A push to `main` builds any package whose version is not published yet.
  `scripts/update-repo.sh` adds it to `pool/`, regenerates the indexes and signs
  `InRelease` and `Release.gpg`. The workflow commits the result to `gh-pages`.
- A published file is never replaced. Change `LOCAL_REVISION` to publish a new build.
- The signing key is ed25519 and expires on 2031-11-13. The private key is the
  `APT_SIGNING_KEY` Actions secret.
