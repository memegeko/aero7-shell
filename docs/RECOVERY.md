# Recovery

Aero7-shell creates timestamped backups before desktop and boot configuration changes.

List backups:

```bash
aero7 backups
```

Restore the latest backup:

```bash
aero7 restore --latest
```

Restore a specific backup:

```bash
aero7 restore --backup <id>
```

Restore shows planned changes and asks for confirmation before copying files back.

