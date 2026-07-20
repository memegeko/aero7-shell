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
    aero_bg_1.png|aero_bg_2.jpeg|aero_bg_3.jpg) return 0 ;;
    *) return 1 ;;
  esac
}

aero7_wallpaper_package_field() {
  local file="$1"
  local field="$2"
  local base
  base="$(basename -- "$file")"

  case "$base:$field" in
    aero_bg_1.png:id) printf '%s\n' "Aero7ShellDefault" ;;
    aero_bg_1.png:name) printf '%s\n' "Aero7-shell Default" ;;
    aero_bg_1.png:resolution) printf '%s\n' "1920x1080" ;;
    aero_bg_1.png:extension) printf '%s\n' "png" ;;
    aero_bg_2.jpeg:id) printf '%s\n' "Aero7ShellArch" ;;
    aero_bg_2.jpeg:name) printf '%s\n' "Aero7-shell Arch" ;;
    aero_bg_2.jpeg:resolution) printf '%s\n' "596x335" ;;
    aero_bg_2.jpeg:extension) printf '%s\n' "jpeg" ;;
    aero_bg_3.jpg:id) printf '%s\n' "Aero7ShellAurora" ;;
    aero_bg_3.jpg:name) printf '%s\n' "Aero7-shell Aurora" ;;
    aero_bg_3.jpg:resolution) printf '%s\n' "2560x1600" ;;
    aero_bg_3.jpg:extension) printf '%s\n' "jpg" ;;
    *) return 1 ;;
  esac
}

aero7_wallpaper_kde_image_path() {
  local file="$1"
  local package_id resolution extension
  package_id="$(aero7_wallpaper_package_field "$file" id)" || return 1
  resolution="$(aero7_wallpaper_package_field "$file" resolution)" || return 1
  extension="$(aero7_wallpaper_package_field "$file" extension)" || return 1
  printf '/usr/share/wallpapers/%s/contents/images/%s.%s\n' "$package_id" "$resolution" "$extension"
}

aero7_install_wallpaper_asset() {
  local wallpaper="$1"
  local base dest_wallpapers raw_dest package_id package_name resolution extension package_dir image_path screenshot_path metadata

  aero7_wallpaper_is_allowed "$wallpaper" || return 1

  base="$(basename -- "$wallpaper")"
  dest_wallpapers="$AERO7_ASSET_DIR/wallpapers"
  raw_dest="$dest_wallpapers/$base"
  aero7_sudo_run install -m 0644 "$wallpaper" "$raw_dest"

  package_id="$(aero7_wallpaper_package_field "$wallpaper" id)" || return 0
  package_name="$(aero7_wallpaper_package_field "$wallpaper" name)" || return 0
  resolution="$(aero7_wallpaper_package_field "$wallpaper" resolution)" || return 0
  extension="$(aero7_wallpaper_package_field "$wallpaper" extension)" || return 0
  package_dir="/usr/share/wallpapers/$package_id"
  image_path="$package_dir/contents/images/$resolution.$extension"
  screenshot_path="$package_dir/contents/screenshot.$extension"
  metadata="$AERO7_CACHE_DIR/$package_id-metadata.json"

  aero7_sudo_run install -d -m 0755 "$package_dir/contents/images"
  aero7_sudo_run install -m 0644 "$wallpaper" "$image_path"
  aero7_sudo_run install -m 0644 "$wallpaper" "$screenshot_path"

  aero7_user_run install -d -m 0755 "$AERO7_CACHE_DIR"
  cat >"$metadata" <<EOF
{
    "KPlugin": {
        "Authors": [
            {
                "Name": "Aero7-shell contributors"
            }
        ],
        "Id": "$package_id",
        "License": "MIT",
        "Name": "$package_name"
    }
}
EOF
  chown "$AERO7_USER:$AERO7_USER" "$metadata" 2>/dev/null || true
  aero7_sudo_run install -m 0644 "$metadata" "$package_dir/metadata.json"
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
  local configured="${AERO7_WALLPAPER:-}"
  local candidate
  if [[ -n "$configured" ]]; then
    candidate="$AERO7_ROOT/assets/wallpapers/$configured"
    [[ -f "$candidate" ]] && aero7_wallpaper_is_allowed "$candidate" && {
      printf '%s\n' "$candidate"
      return 0
    }
    aero7_warn "Configured wallpaper is not approved or missing: $configured"
  fi

  for candidate in \
    "$AERO7_ROOT/assets/wallpapers/aero_bg_1.png" \
    "$AERO7_ROOT/assets/wallpapers/aero_bg_2.jpeg" \
    "$AERO7_ROOT/assets/wallpapers/aero_bg_3.jpg"; do
    [[ -f "$candidate" ]] || continue
    aero7_wallpaper_is_allowed "$candidate" || continue
    printf '%s\n' "$candidate"
    return 0
  done
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
    aero7_install_wallpaper_asset "$wallpaper"
    aero7_info "Installed KDE wallpaper package for $base."
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

  local source installed script
  source="$(aero7_preferred_wallpaper_source)" || {
    aero7_warn "No allowed wallpaper asset found."
    return 0
  }
  installed="$(aero7_wallpaper_kde_image_path "$source")" || installed="$AERO7_ASSET_DIR/wallpapers/$(basename -- "$source")"

  if aero7_dry_run; then
    aero7_info "Would apply wallpaper $installed."
    return 0
  fi

  [[ -f "$installed" ]] || aero7_install_wallpaper_asset "$source"
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
