# Applications

Application installation is recipe-driven. Each recipe declares its upstream, license, build system, dependencies, supported session, availability, fatality, and validation command.

Available AUR recipes:

- Linux Device Manager through `linux-devmgmt` from the AUR
- TuxManager through `tuxmanager` from the AUR

Available signed Aero7 companion packages:

- Aero Dolphin (`aero7-dolphin`), replacing stock Dolphin
- Aero Gwenview (`aero7-gwenview`), replacing stock Gwenview
- Linux Control Panel (`linux-control-panel`)
- Aero KolourPaint (`aero7-kolourpaint`), replacing stock KolourPaint
- original Plasma 6 Clock, CPU Meter, and Notes widgets (`aero7-gadgets`)
- WinXplorer (`winxplorer`)
- execbin Run dialog (`execbin`)
- LinVer system information (`linver`)

The first four use the clean-room MIT `aero7-qt` compatibility layer instead of
the unlicensed upstream `libAeroQt`. The gadgets are Aero7-owned source.
WinXplorer's bitmap controls and navigation sound were removed, while execbin
and LinVer use documented original Aero7 branding. All repositories are pinned
to exact revisions in `aero7-repo` and the companion packages never fall back
to unpinned AUR builds.

Sevulet remains disabled: its source is not anonymously accessible and no
distributable license has been verified. Optional application failures remain
nonfatal to the core desktop installation.
