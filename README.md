<div align="center">
<img src="assets/banner.svg" alt="ArxOS Control Center" width="100%">

**ArxOS Control Center** · Rust + GTK4 · Stingray Labs
</div>

## Interface

The Control Center uses native GTK4 widgets. Navigation keeps each category's
widgets alive, and system commands run on worker threads. Only the active live
panel polls; static panels refresh on demand. Lists reuse visible rows and wallpaper
previews decode on a worker. The interface has no webview or network-loaded fonts.
GTK uses Cairo by default; an explicit `GSK_RENDERER` setting takes precedence.

The existing Rust system adapters still call ArxOS tools, `/proc` and `/sys`.
Package and kernel transactions open the terminal; other privileged operations use
the existing authorization helpers. Opening a terminal is reported separately from
completing an operation. Privacy action output streams into the Activity panel.

## Categories

| Category | Controls and information |
| --- | --- |
| Dashboard | System load, memory, updates, storage, privacy and news |
| Update | Package/version list, system upgrade, database refresh, community registry |
| Weapons | Loadouts, searchable categories, removal, live totals and menu rebuild |
| Kernels | Installed kernels, release history, install and removal |
| Performance | Profiles, governors, energy preference, boost and per-core load |
| Network | Interfaces, Wi-Fi scan/connect, listening ports, service and firewall actions |
| Wallpaper | Library, selected preview, desktop-supported styles, random image, slideshow and downloads |
| Privacy | anond, live output, exit location, app isolation and browser controls |
| VM Tools | QEMU/KVM, VirtualBox and VMware setup |
| Snapshots | Snapshot-before-change preference, listing and manual creation |
| Services | System service status |
| Info | Hardware and OS information |

Ctrl+1 through Ctrl+9 open the first nine categories. Refresh checks the active
category again. The Activity expander keeps recent action output. Destructive
network, removal and trust changes present a confirmation first.

## Event sounds

The footer's **Event sounds** checkbox controls completion, failure and terminal
opening sounds through libcanberra and the desktop sound theme. Routine polling and
category navigation are silent. The preference persists in
`$XDG_CONFIG_HOME/arxos/control-center/event-sounds` (normally under `~/.config`).
An unavailable audio service does not fail a system operation. Terminal launch
sounds mean the terminal opened; its transaction may still be running.

## Build and install

Build requirements: Rust, pkgconf and GTK4 development files (GTK 4.8 or newer).
Runtime: GTK4, the ArxOS system tools, and optionally `canberra-gtk-play` with a sound
theme. On ArxOS these sound packages are `libcanberra` and `sound-theme-freedesktop`.

```bash
cargo build --locked --release --workspace
bash install.sh
```

The installer builds source checkouts or downloads the compiled workspace from the
public `thearxos/arxctl-dist` release. It installs native dependencies, the menu and
dock launchers, bundled tools and notification timers. `arxctl-gui` remains a small
compatibility launcher for older desktop entries. Source stays private.

`src-tauri/` is the retained crate directory name; it now contains GTK4 code and has
no Tauri dependency. CSS is embedded in the binary, so styling changes need a rebuild.

## Verification

Compile on the host and run runtime checks in a fresh diskless guest:

```bash
python3 tests/vm.py
```

The harness claims its own QEMU/KVM process, uses no disk, NIC or host shares, runs
Rust unit tests, and drives every category under Xvfb. It measures switch-to-paint
latency while a fixture delays update queries, exports real framebuffer screenshots,
and checks action success/failure, sound dispatch and saved mute state. Evidence is
written to `target/native-vm/`. See [test scope](tests/README.md) and the [previous-version parity audit](tests/PARITY.md).

<img src="assets/stingray-labs.png" alt="Stingray Labs" width="760">
