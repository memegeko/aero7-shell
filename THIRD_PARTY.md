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
| Aero Dolphin | https://gitgud.io/atmk/dolphin-aero | Signed `aero7-dolphin`; patched to the clean-room MIT Aero7Qt layer |
| Aero Gwenview | https://gitgud.io/atmk/gwenview-aero | Signed `aero7-gwenview`; original code-drawn controls and MIT Aero7Qt layer |
| Aero KolourPaint | https://invent.kde.org/albert-tomanek/kolourpaint/-/tree/saribbon-aero | Signed `aero7-kolourpaint`; MIT SARibbon and MIT Aero7Qt layer |
| Linux Control Panel | https://github.com/actuallyaridan/linux-control | Signed `linux-control-panel`; patched to the MIT Aero7Qt layer |
| Linux Device Manager | https://github.com/actuallyaridan/linux-devmgmt | AUR recipe available: `linux-devmgmt` |
| TuxManager | https://github.com/benapetr/TuxManager | AUR recipe available: `tuxmanager` |
| Gadgets | Aero7-owned source in `aero7-repo` | Signed `aero7-gadgets`; original Clock, CPU Meter, and Notes widgets |
| WinXplorer | https://gitgud.io/catpswin56/winxplorer | Signed `winxplorer`; bundled bitmap controls and navigation sound removed |
| execbin/run dialog | https://gitgud.io/catpswin56/execbin | Signed `execbin`; bundled icons replaced with documented original artwork |
| LinVer | https://gitgud.io/wackyideas/linver | Signed `linver`; bundled version branding replaced with documented original artwork |
| Sevulet | https://gitgud.io/snailatte/sevulet | Project identified, but anonymous source access and a distributable license could not be verified |

## Plymouth

Aero7-shell installs and configures the Arch `plymouth` package with distribution-provided themes only. It does not install PlymouthVista or Microsoft-branded boot assets.

## Bundled Project Assets

The safe avatar `assets/avatars/aero7-user.png` and all three images in
`assets/wallpapers/` are original Aero7-shell artwork released under the MIT
license with the rest of this repository. The installer registers all three as
KDE wallpaper packages and selects `aero_bg_1.png` by default.

Aero7-shell does not install Microsoft wallpaper files, Windows-logo
wallpapers, or `usertile*.bmp` avatar files.
