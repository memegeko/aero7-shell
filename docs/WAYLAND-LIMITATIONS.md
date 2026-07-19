# Wayland Limitations

Aero7-shell supports Plasma Wayland only. It installs the Wayland
AeroThemePlasma shell packages and intentionally does not install:

- `aerothemeplasma-desktop-x11-git`
- `aeroshell-kwin-components-x11-git`
- `aeroshell-smodglow-x11-git`
- `kwin-x11`
- `plasma-x11-session`

Some Aero effects may be less complete on Wayland than on X11. The installer warns about this but does not silently fall back to X11.

The upstream AeroThemePlasma project recommends X11 for the most complete
experience today. Aero7-shell keeps the install Wayland-only and pre-applies
the upstream Wayland session, look-and-feel, SDDM theme, cursor, Kvantum, and
KWin defaults where the installed packages provide them.
