<a id="readme-top"></a>

<div align="center">

<img src="docs/assets/aero7-logo.png" width="150" alt="Aero7 logo">

# Aero7-shell

### A Windows 7-inspired Plasma 6 desktop for Arch Linux

A standalone, resumable installer for turning a fresh Arch Linux system into a
polished KDE Plasma Wayland desktop with AeroThemePlasma, AeroShell, matching
applications, a custom wallpaper, Plymouth, SDDM, Fastfetch, and Wine integration.

[![syntax](https://github.com/memegeko/aero7-shell/actions/workflows/syntax.yml/badge.svg)](https://github.com/memegeko/aero7-shell/actions/workflows/syntax.yml)
[![shellcheck](https://github.com/memegeko/aero7-shell/actions/workflows/shellcheck.yml/badge.svg)](https://github.com/memegeko/aero7-shell/actions/workflows/shellcheck.yml)
[![Arch Linux](https://img.shields.io/badge/Arch_Linux-supported-1793D1?logo=archlinux&logoColor=white)](https://archlinux.org/)
[![Plasma 6](https://img.shields.io/badge/KDE_Plasma-6_Wayland-1D99F3?logo=kde&logoColor=white)](https://kde.org/plasma-desktop/)
[![MIT License](https://img.shields.io/badge/license-MIT-2ea44f.svg)](LICENSE)

[Install](#installation) ·
[Screenshots](#screenshots) ·
[Documentation](#documentation) ·
[Report a bug](https://github.com/memegeko/aero7-shell/issues/new?template=bug_report.yml)

</div>

---

**Aero7-shell is an independent project and is not affiliated with or endorsed by Microsoft Corporation. Windows is a trademark of the Microsoft group of companies.**

<details>
<summary>Table of contents</summary>

- [Installation](#installation)
- [Screenshots](#screenshots)
- [About the project](#about-the-project)
- [What it installs](#what-it-installs)
- [Supported environment](#supported-environment)
- [Managing Aero7-shell](#managing-aero7-shell)
- [Project status](#project-status)
- [Maintenance policy](#maintenance-policy)
- [Documentation](#documentation)
- [Contributing](#contributing)
- [Security](#security)
- [License](#license)
- [Legal / Trademark Notice](#legal--trademark-notice)

</details>

## Installation

Install the checksum-verified Aero7-shell 1.0 release on a fresh Arch Linux
system with one command:

```bash
AERO7_VERSION=v1.0.0 bash -c "$(curl -fsSL https://raw.githubusercontent.com/memegeko/aero7-shell/release/bootstrap.sh)"
```

> [!IMPORTANT]
> Aero7-shell changes desktop, login, initramfs, and boot configuration. Use a
> fresh supported installation and keep a current backup of personal data.

Prefer to inspect the installer before running it?

```bash
curl -fsSLO https://raw.githubusercontent.com/memegeko/aero7-shell/release/bootstrap.sh
less bootstrap.sh
AERO7_VERSION=v1.0.0 bash bootstrap.sh
```

See the [installation guide](docs/INSTALLATION.md) for installer flags, binary
package controls, source-build fallback, resume options, and local development.

<p align="right">(<a href="#readme-top">back to top</a>)</p>

## Screenshots

<p align="center">
  <img src="docs/screenshots/desktop.png" alt="Aero7-shell desktop" width="900">
</p>

| Start menu | All Programs |
| --- | --- |
| <img src="docs/screenshots/start-menu.png" alt="Aero7-shell Start menu" width="420"> | <img src="docs/screenshots/all-programs.png" alt="Aero7-shell alphabetical All Programs list" width="420"> |

| Authentication prompt | Desktop context menu |
| --- | --- |
| <img src="docs/screenshots/authentication.png" alt="Aero7-shell authentication prompt" width="420"> | <img src="docs/screenshots/context-menu.png" alt="Aero7-shell light desktop context menu" width="420"> |

Open the [complete screenshot gallery](docs/SCREENSHOTS.md) to see the lock
screen, jump lists, gadgets, network and volume controls, applications, and
other desktop elements.

<p align="right">(<a href="#readme-top">back to top</a>)</p>

## About the project

Aero7-shell is a post-installation setup system for Arch Linux. It recreates
the familiar layout and visual language of Windows 7 Ultimate on a modern KDE
Plasma 6 Wayland desktop while retaining a standard Linux foundation.

The installer is designed to be useful beyond the first run:

- A full-screen terminal interface shows live stage and package progress
- Installation state is logged and resumable after interruption or failure
- Existing desktop and boot configuration is backed up before it is changed
- Signed binary packages are preferred when available to reduce build time
- Explicit source-build fallback remains available for supported AUR packages
- The installed `aero7` command handles status, repair, updates, and recovery
- Plasma Wayland is used exclusively; no X11 Plasma session is installed

This project recreates styling and interface concepts. It is not a Microsoft
product and does not ship Microsoft-owned assets.

## What it installs

| Area | Included setup |
| --- | --- |
| Desktop | KDE Plasma 6 Wayland, AeroThemePlasma, AeroShell, layout, icons, colors, sounds, and a custom wallpaper |
| Login and boot | SDDM configuration and [PlymouthVista](https://github.com/furkrn/PlymouthVista) fetched directly from upstream |
| Applications | Compatible Aero applications through verified package recipes |
| System tools | NetworkManager, Fastfetch, terminal compatibility commands, and `yay` when needed |
| Integration | Reversible Wine MIME associations and Windows-like terminal conveniences |
| Recovery | Configuration backups, stage checkpoints, logs, validation, repair, restore, and uninstall commands |

PlymouthVista is downloaded at install time from a pinned upstream revision and
is not stored in this repository. Its upstream README states that its image
resources belong to Microsoft Corporation.

Aero7-shell does **not** partition disks, install Arch Linux itself, replace the
bootloader, enable autologin, create passwordless sudo rules, force GPU driver
changes, install browser themes, or add an X11 Plasma session.

## Supported environment

| Requirement | Supported configuration |
| --- | --- |
| Distribution | Fresh Arch Linux installation |
| User | Normal non-root user with working `sudo` access |
| Desktop | KDE Plasma 6 Wayland |
| Bootloader | GRUB or systemd-boot |
| Initramfs | mkinitcpio or dracut |
| Hardware | x86-64 system with supported Arch Linux kernel drivers |

Some Aero effects may be less complete on Wayland than on X11. See the
[Wayland limitations](docs/WAYLAND-LIMITATIONS.md) for the current tradeoffs.

<p align="right">(<a href="#readme-top">back to top</a>)</p>

## Managing Aero7-shell

After installation, use the `aero7` command to inspect or maintain the system:

```bash
aero7 status
aero7 doctor
aero7 update
aero7 repair
aero7 backups
aero7 restore --latest
aero7 uninstall
aero7 apps status
aero7 repo status
aero7 wine status
```

## Project status

Aero7-shell 1.0 is the stable feature-complete shell release. The main
installation flow, desktop packages, SDDM, Plymouth, wallpapers, configuration
backups, and management commands are covered by automated validation and real
hardware installation testing.

Several third-party Aero application recipes remain unavailable or experimental
until their upstream source and build instructions can be verified. The
installer reports these honestly instead of guessing how to build them.

Follow the [changelog](CHANGELOG.md) for completed work and the
[issue tracker](https://github.com/memegeko/aero7-shell/issues) for known
problems and maintenance updates.

## Maintenance policy

The `release` branch is the canonical stable branch. Aero7-shell is now in
maintenance mode: future changes are limited to bug fixes, security fixes,
compatibility updates required by Arch Linux or Plasma, and corrections to
documentation. New desktop features belong in separate Aero7 projects rather
than this repository.

## Documentation

| Start here | Technical details | Maintenance and recovery |
| --- | --- | --- |
| [Installation](docs/INSTALLATION.md) | [Architecture](docs/ARCHITECTURE.md) | [Troubleshooting](docs/TROUBLESHOOTING.md) |
| [Applications](docs/APPLICATIONS.md) | [UI architecture](docs/UI-ARCHITECTURE.md) | [Recovery](docs/RECOVERY.md) |
| [Screenshots](docs/SCREENSHOTS.md) | [Binary packages](docs/BINARY-PACKAGES.md) | [Release workflow](docs/RELEASE.md) |
| [Wayland limitations](docs/WAYLAND-LIMITATIONS.md) | [Boot configuration](docs/BOOT-CONFIGURATION.md) | [Security policy](SECURITY.md) |
| [Asset licensing](docs/ASSET-LICENSING.md) | | |

<p align="right">(<a href="#readme-top">back to top</a>)</p>

## Contributing

Bug reports, tested bug fixes, security fixes, compatibility fixes, and
documentation corrections are welcome. Feature additions are no longer
accepted in this maintenance repository. Please read
[CONTRIBUTING.md](CONTRIBUTING.md) before opening a pull request.

1. Fork the repository.
2. Create a focused bug-fix branch.
3. Run the relevant test scripts and ShellCheck.
4. Commit the change with a clear message.
5. Open a pull request describing what was tested.

Third-party sources must be documented in [THIRD_PARTY.md](THIRD_PARTY.md), and
new assets must follow the rules in [Asset licensing](docs/ASSET-LICENSING.md).

## Security

Remote shell installers can modify desktop, initramfs, and bootloader
configuration. Inspect `bootstrap.sh` and keep backups. Pinned release installs
verify release archives against their published SHA-256 checksum.

Aero7-shell avoids browser security modifications, passwordless sudo, Secure
Boot changes, firewall changes, and arbitrary command execution from
configuration files.

## License

The Aero7-shell source code is distributed under the [MIT License](LICENSE).
Third-party components and assets retain their own licenses; see
[THIRD_PARTY.md](THIRD_PARTY.md) and the
[asset licensing guide](docs/ASSET-LICENSING.md) for details.

## Legal / Trademark Notice

Aero7-shell is an independent open-source project and is not affiliated with,
authorized, sponsored, endorsed, or approved by Microsoft Corporation.

Microsoft, Windows, and the Windows logo are trademarks of the Microsoft group
of companies. All other trademarks are the property of their respective owners.

Aero7-shell does not include or redistribute proprietary Microsoft wallpapers,
logos, sounds, fonts, icons, or other copyrighted assets.

<p align="right">(<a href="#readme-top">back to top</a>)</p>
