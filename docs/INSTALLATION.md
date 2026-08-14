# Installation

Aero7-shell is intended for a fresh minimal Arch Linux installation with a
normal non-root user that has sudo access. Back up personal data before
changing desktop, login, initramfs, or boot configuration.

Checksum-verified installation of the stable 1.0 release:

```bash
AERO7_VERSION=v1.0.0 bash -c "$(curl -fsSL https://raw.githubusercontent.com/memegeko/aero7-shell/release/bootstrap.sh)"
```

Safer inspect-first flow:

```bash
curl -fsSLO https://raw.githubusercontent.com/memegeko/aero7-shell/release/bootstrap.sh
less bootstrap.sh
AERO7_VERSION=v1.0.0 bash bootstrap.sh
```

The canonical `release` branch can be used without a version pin when testing a
maintenance fix before its next tagged release:

```bash
AERO7_REF=release bash bootstrap.sh
```

Pinned release mode downloads the release archive and requires its published
SHA-256 value from `checksums.txt`. Branch mode does not have release-asset
checksum verification and is not the recommended installation path.

Useful installer options:

```bash
./install.sh --help
./install.sh --dry-run
./install.sh --resume
./install.sh --restart-stage 60-aeroshell
./install.sh --skip-stage 100-plymouth
./install.sh --non-interactive --no-reboot
./install.sh --binary-packages
./install.sh --source-build
./install.sh --allow-source-fallback
```

Noninteractive mode keeps any existing Plasma layout. WinXplorer is an optional
compatibility browser and is only installed when `--install-winxplorer` is used.
Companion applications are installed from the signed Aero7 companion set,
Sevulet is skipped, and the installer does not reboot unless explicit options
are added. It still pre-applies the upstream AeroThemePlasma Wayland session and marks its
first-time setup wizard as complete after configuring the equivalent settings.

The signed Aero7 package repository is live and pinned by fingerprint. The
default installer path prefers those signed binary packages
when available. `--binary-packages` fails closed if the signed repository is
unavailable. `--source-build` keeps the original AUR build behavior.
`--allow-source-fallback` is required for noninteractive runs that may fall back
from binaries to source builds.
