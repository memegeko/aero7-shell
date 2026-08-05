# Third-party sources, licences, and trademarks

Aero7-shell records the third-party components selected by the installer. The
signed package repository builds the packages and installs their full licence
files under `/usr/share/licenses`.

## Independent-project and trademark notice

Aero7 is an independent project and is not affiliated with, authorized,
sponsored, endorsed, or approved by Microsoft Corporation. Windows and other
Microsoft product names are trademarks of the Microsoft group of companies.
Microsoft trademarks are used only for truthful, descriptive references to an
upstream project's design target. No Microsoft sponsorship or compatibility
certification is claimed.

## Core theme and shell

| Component | Source | Declared software licence | Notes |
| --- | --- | --- | --- |
| Aero7 AeroThemePlasma fork | `https://github.com/memegeko/aerothemeplasma` | AGPL-3.0-or-later, plus per-directory notices | Replaces runtime Microsoft logos only; screenshots and non-logo theme resources remain upstream |
| AeroShell workspace | `https://github.com/aeroshell-desktop/aeroshell-workspace` | AGPL-3.0-or-later | Signed package |
| AeroShell KWin components | `https://github.com/aeroshell-desktop/aeroshell-kwin-components` | AGPL-3.0-or-later | Signed package |
| AeroShell libplasma | `https://gitgud.io/aeroshell/libplasma` | LGPL-2.0-or-later | Signed package |
| AeroShell SMOD | `https://gitgud.io/aeroshell/smod` | AGPL-3.0-or-later | Signed package |
| AeroThemePlasma icons | `https://gitgud.io/aeroshell/atp/aerothemeplasma-icons` | AGPL-3.0-or-later software notice; upstream attributes relevant visual assets to Microsoft | Retained by project-owner decision with upstream notices |
| AeroThemePlasma sounds | `https://gitgud.io/aeroshell/atp/aerothemeplasma-sounds` | AGPL-3.0-or-later software notice; upstream attributes relevant sound assets to Microsoft | Retained by project-owner decision with upstream notices |
| UAC Polkit Agent | `https://github.com/aeroshell-desktop/uac-polkit-agent` | GPL-3.0-or-later | Signed package |

Open-source software licences do not grant rights to separately owned artwork.
The icon and sound attribution notices are retained so downstream distributors
can make an informed rights decision; they do not establish that Microsoft has
authorized redistribution.

## Applications

| Application | Source | Declared licence and status |
| --- | --- | --- |
| Aero Dolphin | `https://gitgud.io/atmk/dolphin-aero` | LGPL-2.0-or-later; signed Aero7 package |
| Aero Gwenview | `https://gitgud.io/atmk/gwenview-aero` | GPL-2.0-or-later and LGPL-2.0-or-later; signed Aero7 package |
| Aero KolourPaint | `https://invent.kde.org/albert-tomanek/kolourpaint/-/tree/saribbon-aero` | GPL/LGPL/MIT components; signed Aero7 package |
| Linux Control Panel | `https://github.com/actuallyaridan/linux-control` | GPL-3.0-or-later; signed Aero7 package |
| Linux Device Manager | `https://github.com/actuallyaridan/linux-devmgmt` | MIT |
| TuxManager | `https://github.com/benapetr/TuxManager` | GPL-3.0-or-later |
| Gadgets | Aero7-owned source in `aero7-repo` | MIT |
| execbin/run dialog | `https://gitgud.io/catpswin56/execbin` | AGPL-3.0-or-later; bundled logos replaced by Aero7 artwork |
| LinVer | `https://gitgud.io/wackyideas/linver` | AGPL-3.0-or-later; bundled branding replaced by Aero7 artwork |
| WinXplorer | `https://gitgud.io/catpswin56/winxplorer` | GPL-3.0-or-later; optional and not installed by the ISO |
| Sevulet | `https://gitgud.io/snailatte/sevulet` | Not distributed because anonymous source access and a distributable licence were not verified |

## Plymouth

The shell supports configuring PlymouthVista when explicitly selected by a
consumer such as the Aero7 ISO. PlymouthVista software is MIT-licensed, while
its upstream README attributes the bundled visual resources to Microsoft. The
ISO keeps a pinned copy and its full notice. Plymouth is intentionally unchanged
in the present logo-cleanup work.

## Bundled project assets

`assets/avatars/aero7-user.png` is original Aero7-shell artwork under the
repository MIT licence. `assets/wallpapers/aero7-background.png` and
`docs/assets/aero7-logo.png` are project-owner-supplied Aero7 artwork with their
provenance recorded in `docs/ASSET-LICENSING.md`. Documentation screenshots are
left unchanged until the release screenshot pass and must not be reused as
standalone artwork.
