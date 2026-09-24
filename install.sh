#!/usr/bin/env bash
# arxctl installer. Places the native Control Center + its bundled tools, the menu
# entry, the Plank dock item, and the user timers (news + the worldwide update ping).
# Binaries are prebuilt (public dist ships them); if only sources are present, build.
set -eu
D="$(cd "$(dirname "$0")" && pwd)"
S=""; [ "$(id -u)" -ne 0 ] && S=sudo

# --- binaries ----------------------------------------------------------------
# Source checkouts always build the native workspace. A dist carries only binaries.
ARXCTL="$D/arxctl"; NOTIFY="$D/arxos-notify"; ANOND="$D/anond"; ONION="$D/arxonion"
if [ -f "$D/Cargo.toml" ]; then
  command -v cargo >/dev/null || { echo "Install Rust, pkgconf and gtk4 to build arxctl." >&2; exit 1; }
  ( cd "$D" && cargo build --locked --release --workspace )
  BUILD_DIR="${CARGO_TARGET_DIR:-$D/target}"
  case "$BUILD_DIR" in /*) ;; *) BUILD_DIR="$D/$BUILD_DIR" ;; esac
  ARXCTL="$BUILD_DIR/release/arxctl"; NOTIFY="$BUILD_DIR/release/arxos-notify"
  ANOND="$BUILD_DIR/release/anond"; ONION="$BUILD_DIR/release/arxonion"
elif [ ! -f "$ARXCTL" ] || [ ! -f "$NOTIFY" ] || [ ! -f "$ANOND" ] || [ ! -f "$ONION" ]; then
  VER="$(cat "$D/VERSION" 2>/dev/null || echo 0.0.1)"
  REPO="${ARXCTL_GITHUB_REPO:-thearxos/arxctl-dist}"
  BASE="https://github.com/${REPO}/releases/download/v${VER}"
  dl() { if command -v curl >/dev/null 2>&1; then curl -fsSL "$1" -o "$2"; else wget -qO "$2" "$1"; fi; }
  TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
  for binary in arxctl arxos-notify anond arxonion; do
    dl "$BASE/$binary" "$TMP/$binary"
    chmod +x "$TMP/$binary"
  done
  ARXCTL="$TMP/arxctl"; NOTIFY="$TMP/arxos-notify"; ANOND="$TMP/anond"; ONION="$TMP/arxonion"
fi
# GTK4 renders the interface; libcanberra plays desktop sound-theme events.
$S arx install gtk4 libcanberra sound-theme-freedesktop
[ -x "$ARXCTL" ] && $S install -Dm755 "$ARXCTL" /usr/local/bin/arxctl
[ ! -f "$D/arxctl-gui" ] || $S install -Dm755 "$D/arxctl-gui" /usr/local/bin/arxctl-gui
[ -x "$NOTIFY" ] && $S install -Dm755 "$NOTIFY" /usr/local/bin/arxos-notify
# anond (the anonymity daemon) ships bundled inside the Control Center
[ -x "$ANOND" ]  && $S install -Dm755 "$ANOND"  /usr/local/bin/anond
# arxonion (per-app Tor-only network-namespace isolation), driven from the Privacy panel
[ -x "$ONION" ]  && $S install -Dm755 "$ONION"  /usr/local/bin/arxonion
# anond's transparent-proxy kill-switch needs a real netfilter backend + conntrack: it flushes
# the connection-tracking table when arming so no pre-existing flow can survive in the clear
# (the classic transproxy leak). These MUST be present or a user hits a missing package mid-arm
# and the kill-switch silently can't flush - install them up front, never leave it to chance.
$S arx install nftables iptables-nft conntrack-tools tor >/dev/null 2>&1 || true
$S install -Dm755 "$D/arxos-news"   /usr/local/bin/arxos-news   2>/dev/null
$S install -Dm755 "$D/arxos-kernel" /usr/local/bin/arxos-kernel 2>/dev/null

# --- hardware-info cache (memory type/speed for the dashboard; dmidecode needs root) --------
command -v dmidecode >/dev/null 2>&1 || $S arx install dmidecode 2>/dev/null || true
$S install -Dm755 "$D/data/arxos-hwinfo.sh"              /usr/local/bin/arxos-hwinfo
$S install -Dm644 "$D/data/systemd/arxos-hwinfo.service" /usr/lib/systemd/system/arxos-hwinfo.service
$S systemctl enable arxos-hwinfo.service 2>/dev/null || true
$S systemctl start  arxos-hwinfo.service 2>/dev/null || true

# --- Ricing: the macOS theme installer, and the login hook that applies the look
# saved for all users (arxctl --rice-sync) through each account's own settings ---
$S install -Dm755 "$D/data/arxos-mac-themes" /usr/local/bin/arxos-mac-themes
$S install -Dm644 "$D/data/arxos-rice-sync.desktop" /etc/xdg/autostart/arxos-rice-sync.desktop
command -v picom >/dev/null 2>&1 || $S arx install picom 2>/dev/null || true
# Ricing/lock-screen changes apply system-wide (all users) via pkexec arxctl --rice-system/
# --greeter-bg; this scoped rule authorizes them passwordless for an active administrator.
$S install -Dm644 "$D/data/polkit/49-arxos-rice.rules" /etc/polkit-1/rules.d/49-arxos-rice.rules
# The presentation-mode indicator: a coffee cup in the panel's own colour instead of
# an orange slideshow glyph, for every icon theme and every account.
$S install -Dm755 "$D/data/arxos-tray-icons" /usr/local/bin/arxos-tray-icons
$S /usr/local/bin/arxos-tray-icons
# Run a shell snippet inside home $1, as that home's owner (root for /etc/skel), with the home as
# $HOME and cwd, so nothing root-owned is written into a user's home. It NEVER fails the install: a
# home whose owner cannot be resolved, is a system account, or cannot be written is skipped quietly.
_in_home() { # $1 = home dir, $2 = sh snippet run with $HOME=that home
  local h="$1" snippet="$2" u=root
  if [ "$h" != /etc/skel ]; then
    u="$(stat -c %U "$h" 2>/dev/null)" || return 0
    { [ -n "$u" ] && [ "$u" != root ] && [ "$u" != nobody ] && id "$u" >/dev/null 2>&1; } || return 0
  fi
  $S runuser -u "$u" -- sh -c 'cd "$1" 2>/dev/null || exit 0; HOME="$1"; shift; eval "$1"' _ "$h" "$snippet" 2>/dev/null || true
}
# The tray icons (e.g. the presentation-mode cup) share the panel colour instead of a warning tint.
_TRAY_CSS='f="$HOME/.config/gtk-3.0/gtk.css"; grep -qs "ArxOS: tray icons" "$f" 2>/dev/null && exit 0
  mkdir -p "$HOME/.config/gtk-3.0" || exit 0
  printf "%s\n" "/* ArxOS: tray icons share the panel colour */" ".presentation-mode { color: inherit; }" >> "$f"'
for target_home in /etc/skel /home/*; do [ -d "$target_home" ] && _in_home "$target_home" "$_TRAY_CSS"; done

# --- Show Applications: the dock's app grid (arxctl --apps), preloaded at login so a
# press only shows it. It replaces Plank's old Applications menu docklet. ------------
$S install -Dm644 "$D/data/app-grid/arxos-apps.desktop" /usr/share/applications/arxos-apps.desktop
$S install -Dm644 "$D/data/app-grid/arxos-apps.svg" /usr/share/icons/hicolor/scalable/apps/arxos-apps.svg
$S install -Dm644 "$D/data/app-grid/arxos-apps-preload.desktop" /etc/xdg/autostart/arxos-apps-preload.desktop
$S install -Dm644 "$D/data/app-grid/os.arx.apps.service" /usr/share/dbus-1/services/os.arx.apps.service
# Replace Plank's plain Applications docklet with the ArxOS grid launcher, per user.
_APPS_DOCK='d="$HOME/.config/plank/dock1/launchers"; mkdir -p "$d" || exit 0
  rm -f "$d/applications.dockitem"
  printf "%s\n" "[PlankDockItemPreferences]" "Launcher=file:///usr/share/applications/arxos-apps.desktop" > "$d/zz-arxos-apps.dockitem"'
for target_home in /etc/skel /home/*; do [ -d "$target_home" ] && _in_home "$target_home" "$_APPS_DOCK"; done

# --- icon + menu entry -------------------------------------------------------
ICON="$D/src-tauri/icons/icon.png"; [ -f "$ICON" ] || ICON="$D/assets/icons/arxctl.png"
[ -f "$ICON" ] && $S install -Dm644 "$ICON" /usr/share/icons/hicolor/512x512/apps/arxctl.png
# the AnonKit icon (the arxos-anonkit mark) - the icon for the anonkit toolkit everywhere
[ -f "$D/assets/anonkit.png" ] && $S install -Dm644 "$D/assets/anonkit.png" /usr/share/icons/ArxOS/arxos-anonkit.png
$S install -Dm644 "$D/arxos-control.desktop" /usr/share/applications/arxos-control.desktop
$S gtk-update-icon-cache -f /usr/share/icons/hicolor 2>/dev/null || true
$S update-desktop-database 2>/dev/null || true

# --- Plank dock item for the Control Center (system default, seeded to every user) ----
_PLANK='d="$HOME/.config/plank/dock1/launchers"; mkdir -p "$d" || exit 0
  printf "%s\n" "[PlankDockItemPreferences]" "Launcher=file:///usr/share/applications/arxos-control.desktop" > "$d/00-arxctl.dockitem"'
for target_home in /etc/skel /home/*; do [ -d "$target_home" ] && _in_home "$target_home" "$_PLANK"; done

# --- user timers: ArxOS news + the worldwide update ping ---------------------
$S install -Dm644 "$D/arxos-news.service"        /usr/lib/systemd/user/arxos-news.service   2>/dev/null
$S install -Dm644 "$D/arxos-news.timer"          /usr/lib/systemd/user/arxos-news.timer     2>/dev/null
$S install -Dm644 "$D/data/systemd/arxos-notify.service" /usr/lib/systemd/user/arxos-notify.service
$S install -Dm644 "$D/data/systemd/arxos-notify.timer"   /usr/lib/systemd/user/arxos-notify.timer
$S systemctl --global enable arxos-news.timer arxos-notify.timer 2>/dev/null || true

echo "ArxOS Control Center installed: menu + Plank + update-ping timer enabled."
