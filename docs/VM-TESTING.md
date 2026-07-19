# VM Testing

First VM pass:

1. Install a fresh minimal Arch Linux VM.
2. Create a normal user with sudo access.
3. Confirm network and DNS work.
4. Run `./install.sh --dry-run`.
5. Run `./install.sh`.
6. Decline reboot at the final prompt, inspect `aero7 doctor`, then reboot manually.
7. Confirm SDDM starts.
8. Log into Plasma Wayland.

Boot combinations to test where practical:

- GRUB with mkinitcpio
- systemd-boot with mkinitcpio
- GRUB with dracut
- systemd-boot with dracut

Installer behavior to test:

- Successful install
- Interrupted install and resume
- Rerun after success
- Dry run
- No internet
- Failed optional app
- Decline and accept layout replacement
- Decline and accept WinXplorer
- Decline and accept Sevulet
- Decline reboot
- Restore backup
- Uninstall

