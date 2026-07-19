# First VM Test

1. Take a VM snapshot.
2. Run `tools/vm-preflight.sh`.
3. Run `./install.sh --dry-run --no-reboot`.
4. Inspect the log shown by the dry run.
5. Run `./install.sh --no-reboot`.
6. Run `aero7 doctor`.
7. Inspect boot configuration and generated initramfs files.
8. Take another VM snapshot.
9. Reboot manually.
10. Verify Plymouth appears and exits cleanly.
11. Verify SDDM starts.
12. Log into Plasma Wayland.
13. Verify the panel, start menu, task switcher, networking, audio, and Fastfetch.
14. Collect `aero7 logs` output if something fails.
15. Restore the VM snapshot when needed.

This is an alpha VM validation path. Do not label the project production-ready until install, boot, restore, and uninstall have all succeeded in a VM.

