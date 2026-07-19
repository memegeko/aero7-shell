# Security Policy

Aero7-shell changes desktop, package, bootloader, initramfs, SDDM, and MIME configuration. Treat installer changes as privileged system administration.

Security expectations:

- HTTPS downloads only.
- Release archives verified with SHA-256 checksums.
- No password logging.
- No passwordless sudo rules.
- No browser theming or browser security changes.
- No arbitrary command execution from config files.
- No `eval`.
- No unreviewed third-party shell installers.
- No Secure Boot, firewall, or Polkit weakening.

Report security issues through a private GitHub security advisory once the public repository is available.

