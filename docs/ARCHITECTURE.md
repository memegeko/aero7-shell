# Architecture

Aero7-shell is a staged Bash installer.

- `bootstrap.sh` downloads and verifies a release archive.
- `install.sh` parses installer options and runs numbered stages.
- `lib/` contains reusable safety, logging, state, backup, package, AUR, bootloader, initramfs, Plasma, application, and validation helpers.
- `stages/` contains small stage scripts with `stage_check`, `stage_run`, `stage_validate`, and `stage_rollback`.
- `recipes/` contains one application recipe per upstream project.
- `commands/aero7` is the management command.

State is stored under `/var/lib/aero7-shell/state/` for real installations and under the user state directory during dry runs. Logs are stored under `~/.local/state/aero7-shell/logs/`.

