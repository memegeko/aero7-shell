# Architecture

Aero7-shell is a staged Bash installer.

- `bootstrap.sh` downloads and verifies a release archive.
- `install.sh` parses installer options and runs numbered stages.
- `lib/` contains reusable safety, logging, state, backup, package, AUR, bootloader, initramfs, Plasma, application, and validation helpers.
- `stages/` contains small stage scripts with `stage_check`, `stage_run`, `stage_validate`, and `stage_rollback`.
- `recipes/` contains one application recipe per upstream project.
- `commands/aero7` is the management command.

State is stored under `/var/lib/aero7-shell/state/` for real installations and under the user state directory during dry runs. Logs are stored under `~/.local/state/aero7-shell/logs/`.

## ISO first-boot integration

`install.sh --image-mode --target-user USER` is the narrow integration entry
point used by the Aero7 ISO after it has installed Arch Linux and created the
first account. It reuses the normal numbered stages, but permits a root-owned
OOBE service to perform system work directly while `aero7_user_run` writes
desktop configuration as the selected account.

Image mode fails closed unless all of these conditions are true:

- the caller is root;
- `AERO7_IMAGE_MODE_GUARD` contains the exact first-boot token;
- `/var/lib/aero7/install-source` identifies a ready ISO adapter;
- the target is an existing unprivileged local account with a real home
  directory.

The public bootstrap and normal installer paths remain non-root and continue
to require ordinary sudo authentication. Image mode does not create or retain
a passwordless sudo rule.
