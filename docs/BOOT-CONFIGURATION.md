# Boot Configuration

Aero7-shell supports GRUB and systemd-boot, with mkinitcpio or dracut.

Before changing boot files, the installer creates a timestamped backup manifest under `/var/lib/aero7-shell/backups/`.

Plymouth kernel parameters are merged without duplication:

```text
quiet splash
```

Optional noise-reduction parameters are only added when configured. NVIDIA parameters are not added unless NVIDIA hardware and configuration needs are detected.

If both GRUB and systemd-boot appear configured, the installer treats the result as ambiguous and stops before boot changes.

