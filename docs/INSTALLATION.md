# Installation

Use a VM first. Aero7-shell is intended for a fresh minimal Arch Linux installation with a normal non-root user that has sudo access.

One-line install from the current GitHub `main` branch:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/memegeko/aero_desktop/main/bootstrap.sh)"
```

Safer inspect-first flow:

```bash
curl -fsSLO https://raw.githubusercontent.com/memegeko/aero_desktop/main/bootstrap.sh
less bootstrap.sh
bash bootstrap.sh
```

Pinned release install after a GitHub Release is published:

```bash
AERO7_VERSION=v0.1.0 bash -c "$(curl -fsSL https://raw.githubusercontent.com/memegeko/aero_desktop/main/bootstrap.sh)"
```

The main-branch installer is convenient for alpha testing. Pinned release mode downloads the release archive and verifies `checksums.txt`.

Useful installer options:

```bash
./install.sh --help
./install.sh --dry-run
./install.sh --resume
./install.sh --restart-stage 60-aeroshell
./install.sh --skip-stage 100-plymouth
./install.sh --non-interactive --no-reboot
```

Noninteractive mode keeps any existing Plasma layout, skips WinXplorer, skips
Sevulet, and does not reboot unless explicit options are added. The installer
still pre-applies the upstream AeroThemePlasma Wayland session and marks its
first-time setup wizard as complete after configuring the equivalent settings.
