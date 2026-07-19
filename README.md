# Aero7-shell

**Aero7-shell is an independent project and is not affiliated with or endorsed by Microsoft Corporation. Windows is a trademark of the Microsoft group of companies.**

Aero7-shell is a standalone post-installation setup system for Arch Linux. It turns a fresh minimal Arch installation into a KDE Plasma 6 Wayland desktop inspired by Windows 7 Ultimate using AeroThemePlasma, AeroShell, compatible Aero applications, Plymouth, SDDM, Fastfetch, Wine integration, and small Windows-like terminal conveniences.

Aero7-shell honestly reports the operating system as Arch Linux. It recreates styling and interface concepts; it is not a Microsoft product.

## Status

This repository is VM-tested for a clean Arch-based install flow. The installer is modular, resumable, logged, and defensive, but several third-party Aero application recipes remain marked unavailable or experimental until their upstream build instructions are verified.

## Supported Environment

- Arch Linux with a normal sudo-capable user
- Fresh minimal Arch installation as the initial target
- KDE Plasma 6 Wayland only
- GRUB or systemd-boot
- mkinitcpio or dracut
- Browser theming intentionally excluded

Aero7-shell does not partition disks, install Arch Linux, replace the bootloader, enable autologin, install GPU drivers without need, or install an X11 Plasma session.

## Installation

Remote bootstrap command:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/memegeko/Aero7-shell/main/bootstrap.sh)"
```

Safer inspect-before-running method:

```bash
curl -fsSLO https://raw.githubusercontent.com/memegeko/Aero7-shell/main/bootstrap.sh
less bootstrap.sh
bash bootstrap.sh
```

For local development:

```bash
./install.sh --dry-run
./install.sh --dry-run --non-interactive
```

## What It Changes

- Installs KDE Plasma Wayland packages and common desktop applications
- Enables NetworkManager and SDDM
- Installs `yay` without running AUR builds as root
- Installs the full Wayland AeroThemePlasma and AeroShell AUR shell stack
- Installs compatible Aero applications through explicit recipes
- Prompts separately for WinXplorer and Sevulet
- Prompts before replacing Plasma layout
- Backs up Plasma, SDDM, bootloader, initramfs, Fastfetch, and MIME-related configuration
- Enables Plymouth using distribution-provided themes; it does not install Microsoft-branded boot assets
- Adds an Aero7 Fastfetch profile that clearly says Arch Linux
- Adds reversible Wine MIME integration
- Adds `aero7`, `aero7-dir`, `aero7-ipconfig`, `aero7-systeminfo`, and `aero7-winver`

## Management Command

After installation, use:

```bash
aero7 status
aero7 doctor
aero7 update
aero7 repair
aero7 backups
aero7 restore --latest
aero7 uninstall
aero7 apps status
aero7 wine status
```

## Documentation

- [Installation](docs/INSTALLATION.md)
- [Architecture](docs/ARCHITECTURE.md)
- [UI architecture](docs/UI-ARCHITECTURE.md)
- [Applications](docs/APPLICATIONS.md)
- [Boot configuration](docs/BOOT-CONFIGURATION.md)
- [Wayland limitations](docs/WAYLAND-LIMITATIONS.md)
- [Asset licensing](docs/ASSET-LICENSING.md)
- [Recovery](docs/RECOVERY.md)
- [Troubleshooting](docs/TROUBLESHOOTING.md)
- [VM testing](docs/VM-TESTING.md)
- [First VM test](docs/FIRST-VM-TEST.md)
- [Release workflow](docs/RELEASE.md)

## Security Notice

Remote shell installers can modify system and boot configuration. Inspect `bootstrap.sh`, use a VM first, and keep backups. Aero7-shell verifies release archives by checksum and avoids browser security modifications, passwordless sudo, Secure Boot changes, firewall changes, and arbitrary command execution from configuration files.

## Legal / Trademark Notice

Aero7-shell is an independent open-source project and is not affiliated with, authorized, sponsored, endorsed, or approved by Microsoft Corporation.

Microsoft, Windows, and the Windows logo are trademarks of the Microsoft group of companies. All other trademarks are the property of their respective owners.

Aero7-shell does not include or redistribute proprietary Microsoft wallpapers, logos, sounds, fonts, icons, or other copyrighted assets.
