# Boot Configuration

Aero7-shell supports GRUB and systemd-boot, with mkinitcpio or dracut.

Before changing boot files, the installer creates a timestamped backup manifest under `/var/lib/aero7-shell/backups/`.

Plymouth kernel parameters are merged without duplication:

```text
quiet splash
```

The installer downloads
[`furkrn/PlymouthVista`](https://github.com/furkrn/PlymouthVista) from its
upstream GitHub repository at a pinned revision, configures its Windows 7 mode
without prompts, and selects `PlymouthVista`. Its files are not included in the
Aero7-shell repository. The upstream project states that its image resources
belong to Microsoft Corporation. Plymouth is configured with `ShowDelay=0` so
the splash starts immediately.
The installer also adds
`/etc/systemd/system/plymouth-quit.service.d/aero7-hold.conf`, which waits five
seconds before Plymouth exits and SDDM starts. This makes the splash visible on
fast systems and virtual machines without changing the selected Plymouth theme.

Optional noise-reduction parameters are only added when configured. NVIDIA parameters are not added unless NVIDIA hardware and configuration needs are detected.

If both GRUB and systemd-boot appear configured, the installer treats the result as ambiguous and stops before boot changes.
