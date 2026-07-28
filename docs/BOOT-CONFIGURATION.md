# Boot Configuration

Aero7-shell supports GRUB and systemd-boot, with mkinitcpio or dracut.

Before changing boot files, the installer creates a timestamped backup manifest under `/var/lib/aero7-shell/backups/`.

Plymouth kernel parameters are merged without duplication:

```text
quiet splash
```

Plymouth is configured with `ShowDelay=0` so the splash starts immediately.
The installer also adds
`/etc/systemd/system/plymouth-quit.service.d/aero7-hold.conf`, which waits five
seconds before Plymouth exits and SDDM starts. This makes the splash visible on
fast systems and virtual machines without changing the selected Plymouth theme.

Optional noise-reduction parameters are only added when configured. NVIDIA parameters are not added unless NVIDIA hardware and configuration needs are detected.

If both GRUB and systemd-boot appear configured, the installer treats the result as ambiguous and stops before boot changes.
