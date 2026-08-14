# Contributing

Thank you for helping maintain Aero7-shell. Version 1.0 is feature-complete;
this repository accepts bug fixes, security fixes, required Arch Linux or
Plasma compatibility updates, and documentation corrections only.

Before sending changes:

1. Keep the project independent and avoid unrelated branding.
2. Do not add browser theming.
3. Do not add X11-only Aero packages or an X11 Plasma session.
4. Run `bash tests/test-common.sh`, `bash tests/test-detection.sh`, and `bash tests/test-recipes.sh`.
5. Run ShellCheck when available.
6. Do not add new applications, themes, or desktop features.

Corrections to existing application recipes must remain explicit. Do not assume
every upstream repository is a root-level CMake project.
