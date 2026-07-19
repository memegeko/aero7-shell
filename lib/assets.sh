#!/usr/bin/env bash

if [[ -n "${AERO7_ASSETS_LOADED:-}" ]]; then
  return 0
fi
AERO7_ASSETS_LOADED=1

aero7_wallpaper_is_allowed() {
  local file="$1"
  local base
  base="$(basename -- "$file")"
  case "$base" in
    README.md) return 1 ;;
    *) return 1 ;;
  esac
}

aero7_avatar_is_allowed() {
  local file="$1"
  local base
  base="$(basename -- "$file")"
  case "$base" in
    usertile*.bmp)
      return 1
      ;;
  esac
  return 0
}

aero7_preferred_wallpaper_source() {
  aero7_debug "No approved wallpaper is currently distributed."
  return 1
}

aero7_install_assets() {
  local dest_wallpapers="$AERO7_ASSET_DIR/wallpapers"
  local dest_avatars="$AERO7_ASSET_DIR/avatars"
  local dest_fastfetch="$AERO7_ASSET_DIR/fastfetch"

  if aero7_dry_run; then
    aero7_info "Would install filtered Aero7 assets to $AERO7_ASSET_DIR."
    return 0
  fi

  aero7_sudo_run install -d -m 0755 "$dest_wallpapers" "$dest_avatars" "$dest_fastfetch"

  local wallpaper base
  for wallpaper in "$AERO7_ROOT"/assets/wallpapers/*; do
    [[ -f "$wallpaper" ]] || continue
    if ! aero7_wallpaper_is_allowed "$wallpaper"; then
      aero7_info "Skipping unapproved wallpaper asset: $(basename -- "$wallpaper")"
      continue
    fi
    base="$(basename -- "$wallpaper")"
    aero7_sudo_run install -m 0644 "$wallpaper" "$dest_wallpapers/$base"
  done

  local avatar fastfetch
  for avatar in "$AERO7_ROOT"/assets/avatars/*; do
    [[ -f "$avatar" ]] || continue
    if ! aero7_avatar_is_allowed "$avatar"; then
      aero7_warn "Skipping prohibited or unverified avatar asset: $(basename -- "$avatar")"
      continue
    fi
    aero7_sudo_run install -m 0644 "$avatar" "$dest_avatars/$(basename -- "$avatar")"
  done

  for fastfetch in "$AERO7_ROOT"/assets/fastfetch/*; do
    [[ -f "$fastfetch" ]] || continue
    aero7_sudo_run install -m 0644 "$fastfetch" "$dest_fastfetch/$(basename -- "$fastfetch")"
  done
}

aero7_apply_wallpaper() {
  [[ "$(aero7_config_value ApplyWallpaper)" != "false" ]] || return 0

  local source base installed script
  source="$(aero7_preferred_wallpaper_source)" || {
    aero7_warn "No allowed wallpaper asset found."
    return 0
  }
  base="$(basename -- "$source")"
  installed="$AERO7_ASSET_DIR/wallpapers/$base"

  if aero7_dry_run; then
    aero7_info "Would apply wallpaper $installed."
    return 0
  fi

  [[ -f "$installed" ]] || aero7_sudo_run install -D -m 0644 "$source" "$installed"
  script="$AERO7_CACHE_DIR/aero7-wallpaper.js"
  aero7_user_run install -d -m 0755 "$AERO7_CACHE_DIR"
  cat >"$script" <<EOF
var desktopsList = desktops();
for (var i = 0; i < desktopsList.length; i++) {
  desktopsList[i].wallpaperPlugin = "org.kde.image";
  desktopsList[i].currentConfigGroup = ["Wallpaper", "org.kde.image", "General"];
  desktopsList[i].writeConfig("Image", "file://$installed");
}
EOF
  chown "$AERO7_USER:$AERO7_USER" "$script" 2>/dev/null || true
  aero7_state_append "modified_user_files" "$script"
  local qdbus_cmd
  if qdbus_cmd="$(aero7_qdbus_command)"; then
    aero7_user_run "$qdbus_cmd" org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript "$(cat "$script")" || {
      aero7_warn "Wallpaper script could not be applied during this session."
      aero7_state_set "logout_recommended" "yes"
    }
  fi
}
