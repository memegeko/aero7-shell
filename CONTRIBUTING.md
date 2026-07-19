# Contributing

Thank you for helping with Aero7-shell.

Before sending changes:

1. Keep the project independent and avoid unrelated branding.
2. Do not add browser theming.
3. Do not add X11-only Aero packages or an X11 Plasma session.
4. Run `bash tests/test-common.sh`, `bash tests/test-detection.sh`, and `bash tests/test-recipes.sh`.
5. Run ShellCheck when available.
6. Document any new third-party source in `THIRD_PARTY.md`.

Application recipes must be explicit. Do not assume every upstream repository is a root-level CMake project.

