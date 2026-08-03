#!/usr/bin/env bash
set -u

config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
state_home="${XDG_STATE_HOME:-$HOME/.local/state}"
cache_home="${XDG_CACHE_HOME:-$HOME/.cache}"
config_file="$config_home/aero7-shell/first-loginrc"
state_dir="$state_home/aero7-shell"
marker="$state_dir/first-login-applied"
log_file="$state_dir/first-login.log"

[[ -f "$config_file" && ! -e "$marker" ]] || exit 0
mkdir -p -- "$state_dir"
exec >>"$log_file" 2>&1

printf '[%s] Starting deferred Plasma setup.\n' "$(date '+%Y-%m-%d %H:%M:%S')"

read_config() {
  local group="$1"
  local key="$2"
  local fallback="${3:-}"
  local value=""

  if command -v kreadconfig6 >/dev/null 2>&1; then
    value="$(kreadconfig6 --file "$config_file" --group "$group" --key "$key" 2>/dev/null || true)"
  fi
  printf '%s\n' "${value:-$fallback}"
}

config_true() {
  [[ "$(read_config Actions "$1" false)" == "true" ]]
}

qdbus_command=""
for candidate in qdbus6 qdbus-qt6 qdbus; do
  if command -v "$candidate" >/dev/null 2>&1; then
    qdbus_command="$candidate"
    break
  fi
done

if [[ -z "$qdbus_command" ]]; then
  printf 'No qdbus command is available; setup will retry at the next login.\n'
  exit 1
fi

plasma_ready=0
attempt=0
while ((attempt < 60)); do
  ((attempt += 1))
  if "$qdbus_command" org.kde.plasmashell /PlasmaShell \
    org.kde.PlasmaShell.evaluateScript 'true' >/dev/null 2>&1; then
    plasma_ready=1
    break
  fi
  sleep 1
done

if [[ "$plasma_ready" -ne 1 ]]; then
  printf 'plasmashell did not become ready; setup will retry at the next login.\n'
  exit 1
fi

if config_true Theme; then
  lookandfeel="$(read_config Theme LookAndFeel)"
  color_scheme="$(read_config Theme ColorScheme Aero7Light)"
  desktop_theme="$(read_config Theme DesktopTheme breeze-light)"
  kvantum_theme="$(read_config Theme KvantumTheme Windows7Aero)"
  cursor_theme="$(read_config Theme CursorTheme aero-drop)"

  if [[ -n "$lookandfeel" ]] && command -v plasma-apply-lookandfeel >/dev/null 2>&1; then
    plasma-apply-lookandfeel -a "$lookandfeel" || true
  fi

  # Apply the light colors and desktop theme before pinning their config keys.
  # plasma-apply-* deliberately does nothing when the requested value is
  # already present in the config file. Writing the value first therefore
  # leaves the dark theme loaded in memory after the Aero look-and-feel runs.
  if command -v plasma-apply-colorscheme >/dev/null 2>&1; then
    plasma-apply-colorscheme "$color_scheme" || true
  fi
  if command -v plasma-apply-desktoptheme >/dev/null 2>&1; then
    plasma-apply-desktoptheme "$desktop_theme" || true
  fi
  if command -v kvantummanager >/dev/null 2>&1; then
    kvantummanager --set "$kvantum_theme" || true
  fi
  if command -v plasma-apply-cursortheme >/dev/null 2>&1; then
    plasma-apply-cursortheme "$cursor_theme" --size 32 || true
  fi

  if command -v kwriteconfig6 >/dev/null 2>&1; then
    [[ -n "$lookandfeel" ]] && kwriteconfig6 --file kdeglobals --group KDE --key LookAndFeelPackage "$lookandfeel"
    kwriteconfig6 --file kdeglobals --group General --key ColorScheme "$color_scheme"
    kwriteconfig6 --file kdeglobals --group General --key AccentColor "0,0,0,0"
    kwriteconfig6 --file kdeglobals --group General --key accentColorFromWallpaper --type bool false
    kwriteconfig6 --file kdeglobals --group KDE --key widgetStyle kvantum
    kwriteconfig6 --file plasmarc --group Theme --key name "$desktop_theme"
    kwriteconfig6 --file kvantum.kvconfig --group General --key theme "$kvantum_theme"
    kwriteconfig6 --file kcminputrc --group Mouse --key cursorTheme "$cursor_theme"
    kwriteconfig6 --file kcminputrc --group Mouse --key cursorSize 32
  fi

  # Applying the Aero look-and-feel on top of Plasma's initial layout can leave
  # both taskbars alive. Keep one Aero containment and remove every stock or
  # duplicate panel. If the theme did not create one, build the canonical Aero
  # taskbar here so a new account never starts without a usable panel.
  "$qdbus_command" org.kde.plasmashell /PlasmaShell \
    org.kde.PlasmaShell.evaluateScript '
function isAeroPanel(panel) {
    if (String(panel.type) === "io.gitgud.wackyideas.panel") return true;
    var panelWidgets = panel.widgets();
    for (var widgetIndex = 0; widgetIndex < panelWidgets.length; ++widgetIndex) {
        var widgetType = String(panelWidgets[widgetIndex].type);
        if (widgetType === "io.gitgud.wackyideas.SevenStart" ||
            widgetType === "io.gitgud.wackyideas.seventasks") return true;
    }
    return false;
}
var currentPanels = panels();
var aeroPanel = null;
for (var panelIndex = 0; panelIndex < currentPanels.length; ++panelIndex) {
    var candidate = currentPanels[panelIndex];
    if (aeroPanel === null && isAeroPanel(candidate)) {
        aeroPanel = candidate;
    } else {
        candidate.remove();
    }
}
if (aeroPanel === null) {
    aeroPanel = new Panel("io.gitgud.wackyideas.panel");
    aeroPanel.addWidget("io.gitgud.wackyideas.SevenStart");
    aeroPanel.addWidget("io.gitgud.wackyideas.seventasks");
    aeroPanel.addWidget("io.gitgud.wackyideas.systemtray");
    aeroPanel.addWidget("io.gitgud.wackyideas.digitalclocklite");
    aeroPanel.addWidget("io.gitgud.wackyideas.win7showdesktop");
}
aeroPanel.location = "bottom";
aeroPanel.height = 40;
aeroPanel.floating = false;
' || true
fi

apply_plasma_script() {
  local action="$1"
  local script="$2"

  config_true "$action" || return 0
  if [[ ! -s "$script" ]]; then
    printf 'Deferred %s script is missing: %s\n' "$action" "$script"
    return 1
  fi
  "$qdbus_command" org.kde.plasmashell /PlasmaShell \
    org.kde.PlasmaShell.evaluateScript "$(<"$script")"
}

failed=0
apply_plasma_script Layout "$cache_home/aero7-shell/aero7-layout.js" || failed=1
apply_plasma_script Wallpaper "$cache_home/aero7-shell/aero7-wallpaper.js" || failed=1

if [[ "$failed" -ne 0 ]]; then
  printf 'One or more Plasma actions failed; setup will retry at the next login.\n'
  exit 1
fi

"$qdbus_command" org.kde.KWin /KWin reconfigure >/dev/null 2>&1 || true
if command -v kbuildsycoca6 >/dev/null 2>&1; then
  kbuildsycoca6 --noincremental >/dev/null 2>&1 || true
fi
touch -- "$marker"
rm -f -- "$config_home/systemd/user/plasma-workspace.target.wants/aero7-first-login.service"
printf '[%s] Deferred Plasma setup completed.\n' "$(date '+%Y-%m-%d %H:%M:%S')"
