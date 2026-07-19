# Applications

Application installation is recipe-driven. Each recipe declares its upstream, license, build system, dependencies, supported session, availability, fatality, and validation command.

Available recipes in this first implementation:

- Linux Device Manager through `linux-devmgmt` from the AUR
- TuxManager through `tuxmanager` from the AUR

Disabled or unavailable recipes are present for Aero Dolphin, Aero Gwenview, Linux Control Panel, Aero KolourPaint, Gadgets, WinXplorer, execbin, LinVer, and Sevulet until their authoritative upstream repositories, replacement behavior, and current build systems are confirmed. Optional app failures are reported without destroying the core desktop installation.
