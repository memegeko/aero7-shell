# Third-Party Sources

Aero7-shell does not vendor third-party application source. It records upstreams and installs or clones them during installation through explicit recipes.

On Arch Linux, the full AeroThemePlasma shell is installed from AUR packages.
Those packages include patched AeroShell Plasma providers, including a
`libplasma` provider, so they should be tested in a VM before use on a daily
driver system.

## Core Theme and Shell

| Component | Source | License |
| --- | --- | --- |
| AeroThemePlasma | https://github.com/aeroshell-desktop/aerothemeplasma | AGPL-3.0-or-later |
| AeroShell workspace | https://github.com/aeroshell-desktop/aeroshell-workspace | See upstream |
| AeroShell KWin components | https://github.com/aeroshell-desktop/aeroshell-kwin-components | See upstream |
| AeroShell libplasma | https://gitgud.io/aeroshell/libplasma | See upstream |
| AeroShell SMOD | https://gitgud.io/aeroshell/smod | See upstream |
| AeroThemePlasma icons | https://gitgud.io/aeroshell/atp/aerothemeplasma-icons | See upstream |
| AeroThemePlasma sounds | https://gitgud.io/aeroshell/atp/aerothemeplasma-sounds | See upstream |
| UAC Polkit Agent | https://github.com/aeroshell-desktop/uac-polkit-agent | GPL-3.0-or-later |

## Applications

| Application | Source | Current recipe status |
| --- | --- | --- |
| Aero Dolphin | https://gitgud.io/atmk/dolphin-aero | Disabled; AUR package conflicts with stock `dolphin` |
| Aero Gwenview | https://gitgud.io/atmk/gwenview-aero | Disabled; AUR package conflicts with stock `gwenview` |
| Aero KolourPaint | Not yet verified as an Aero fork | Unavailable until authoritative source is confirmed |
| Linux Control Panel | https://github.com/actuallyaridan/linux-control | Disabled until current build instructions are verified |
| Linux Device Manager | https://github.com/actuallyaridan/linux-devmgmt | AUR recipe available: `linux-devmgmt` |
| TuxManager | https://github.com/benapetr/TuxManager | AUR recipe available: `tuxmanager` |
| Gadgets | Not yet verified | Unavailable until authoritative source is confirmed |
| WinXplorer | Not yet verified | Optional and unavailable until authoritative source is confirmed |
| execbin/run dialog | Not yet verified | Unavailable until authoritative source is confirmed |
| LinVer | Mentioned by AeroThemePlasma; standalone authoritative source not yet verified | Unavailable until source and build system are confirmed |
| Sevulet | Not yet verified | Optional and unavailable until authoritative source is confirmed |

## Plymouth

Aero7-shell installs and configures the Arch `plymouth` package with distribution-provided themes only. It does not install PlymouthVista or Microsoft-branded boot assets.

## Bundled Project Assets

The safe avatar `assets/avatars/aero7-user.png` is original Aero7-shell artwork released under the MIT license with the rest of this repository.

No wallpaper is currently approved for distribution. Aero7-shell does not install Microsoft wallpaper files, Windows-logo wallpapers, or `usertile*.bmp` avatar files.
