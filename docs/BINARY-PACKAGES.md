# Binary Packages

Aero7-shell can install the Aero desktop package set from the signed alpha
pacman repository published for current Arch Linux x86_64 systems.

Current status: the repository public key is present, pinned to fingerprint
`72C79ABBBBE96446DD3324042694BFE1090F4FD6`, and the complete alpha package set
is published at `https://memegeko.github.io/aero7-repo/$arch`.

The default `auto` mode prefers signed binary packages when the pinned key and
repository are available. Source builds remain available through
`--source-build`, and noninteractive fallback from binaries to source builds
requires `--allow-source-fallback`.

## Modes

```bash
./install.sh --binary-packages
./install.sh --source-build
./install.sh --allow-source-fallback
```

- `--binary-packages` requires signed Aero7 repository packages.
- `--source-build` skips the binary repository and builds from AUR source.
- `--allow-source-fallback` lets a noninteractive run fall back to source
  builds if the signed repository is unavailable or incompatible.

Interactive fallback requires consent because source builds can take 30-90
minutes.

## Repository Security

The repository must use:

```ini
SigLevel = Required DatabaseRequired
```

Aero7-shell verifies the configured public key fingerprint before importing it
into pacman's keyring. It must not use unsigned packages, `TrustAll`,
`SigLevel = Never`, `--nodeps`, or `--assume-installed`.

## Management Commands

```bash
aero7 repo status
aero7 repo enable
aero7 repo disable
aero7 repo key
aero7 repo fingerprint
aero7 repo packages
aero7 repo refresh
aero7 repo doctor
```

`aero7 doctor` also reports whether Aero packages came from the signed
repository, source builds, or an unknown origin.
