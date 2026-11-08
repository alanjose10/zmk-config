# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This is a ZMK firmware configuration repository for split ergonomic keyboards. It uses ZMK (Zephyr-based keyboard firmware) with GitHub Actions for automated firmware builds.

## Building Firmware

Firmware is built automatically via GitHub Actions on push/PR. The workflow uses ZMK's reusable build workflow and outputs timestamped firmware artifacts.

For local development with West (ZMK's build system):
```bash
west init -l config
west update
west build -d build/output -b nice_nano//zmk -- -DSHIELD=hillside46_left config
```

## Build Configuration

`build.yaml` defines the build matrix of board+shield combinations:
- Boards: `nice_nano//zmk`, `xiao_ble//zmk`, `nrf52840_mdk_usb_dongle//zmk`
- Shields: hillside46_left, hillside46_right, hillside46_dongle, settings_reset

ZMK tracks `main` (Zephyr 4.1, hardware model v2), same as the charybdis repo. Board IDs
carry the `//zmk` variant suffix; shield board overlays use the full board string, e.g.
`boards/nice_nano_nrf52840_zmk.overlay`.

`nrf52840_mdk_usb_dongle//zmk` (`boards/makerdiary/nrf52840_mdk_usb_dongle/`) is the
makerdiary nRF52840 MDK USB Dongle, a `zmk` variant of the upstream Zephyr board with the
stock UF2 bootloader's flash layout (app at 0x1000, NVS storage at 0xEC000). It is a copy
of the same board in the charybdis repo. To flash: double-press the dongle button while it
is plugged in, then copy the uf2 onto the `UF2BOOT` drive.

## Architecture

### Keymap Structure

`config/hillside46.keymap` is the Mac-only Colemak-DH design shared with the charybdis
repo (`config/keymaps/colemak_dh.keymap` there). Layers, in the same order as charybdis:

| # | Name | Access | Purpose |
|---|------|--------|---------|
| 0 | BASE | — | Colemak-DH, home row mods, caffeine toggle on key 37 |
| 1 | NAV | hold ENTER (key 42) | Mouse move/scroll on the left; desktop prev/next, left/right click, arrows, Home/PgDn/PgUp/End on the right |
| 2 | SYM | hold TAB (key 39) or DEL (key 44) | Symbols left, numbers right |
| 3 | SHORTCUTS | hold ESC (key 41) | Prev/next tab, back, forward, select all, save, find, undo, cut, copy, paste |
| 4 | ADJ | SHORTCUTS + NAV | Brightness, volume, F23/F24 |
| 5 | SYSTEM | SYM + NAV | BT profiles, BT_CLR (key 23), outputs, ext power, bootloader on both bottom outer keys |

The hillside has five keys the charybdis lacks (30, 31, 38, 44, 45). They keep their own
bindings: ENTER, CAPS, BSPC, SYM/DEL, none. SYSTEM also keeps BT_CLR_ALL on key 31.

Deliberate difference from charybdis: clicks live in NAV with the mouse keys and
Back/Forward in SHORTCUTS, because the hillside has no trackball.

Combos (`hillside-combos.dtsi`): twelve vertical symbol combos on BASE with 20 ms windows
for choc switches, caps word on G+M, ESC on Q+W and Y+;, soft reset on the two top
outer keys, bootloader on the two home outer keys on SYSTEM.

### Configuration Files

`config/` directory contains:
- `*.keymap` - Layer definitions and key bindings
- `*.conf` - Kconfig feature flags
- `*.dtsi` - Shared device tree includes:
  - `hillside-common.dtsi` - Key position diagram (labels come from zmk-helpers)
  - `hillside-ht.dtsi` - Home row mod hold-tap definitions (same timings as charybdis)
  - `hillside-combos.dtsi` - Key combos
  - `shortcuts.dtsi` - Mac shortcut defines
  - `mouse.dtsi` - Mouse movement configuration

### Dependencies

`config/west.yml` specifies ZMK modules:
- `zmkfirmware/zmk` - Core ZMK firmware (`main`)
- `urob/zmk-helpers` - Helper macros and key labels
- `janpfischer/zmk-dongle-screen` - Display support for dongle, on its `upgrade-4.1` branch (its `main` only builds against ZMK v0.3)
- `alanjose10/zmk-caffeine` - shared with the charybdis repo, pinned by tag; bump both configs together

### Shield Definitions

`boards/shields/hillside46/` contains hardware definitions for the Hillside46 keyboard with left/right/dongle variants.

## Keymap Visualization

The `draw-keymaps.yml` workflow auto-generates SVG diagrams using keymap-drawer when keymap files change. Output goes to `keymap-drawer/`.

## Key Patterns

- Conditional layers activate ADJ (SHORTCUTS + NAV) and SYSTEM (SYM + NAV)
- Home row mods use `hml`/`hmr` (balanced hold-taps, 280 ms, hold-trigger-on-release); the
  THUMBS list from zmk-helpers includes the inner bottom keys 30/31
- `thumb_mt` provides hold-preferred mod-tap for thumb keys; `&lt` is tuned to 220/190 ms
- `&ca` (caffeine) comes from the shared zmk-caffeine module
