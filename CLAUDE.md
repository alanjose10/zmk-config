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

Keymaps use Colemak-DH layout with home row mods and multiple layers:
- MAC_L / LNX_L: Base layers with OS-specific shortcuts
- SYMBOL_L: Symbols and numbers
- NAV layers: Navigation (arrow keys, page up/down)
- SHORTCUTS layers: OS-specific shortcuts
- ADJ_L: Adjustment layer (activated via conditional layers)
- SYSTEM_L: System controls (Bluetooth, reset)

### Configuration Files

`config/` directory contains:
- `*.keymap` - Layer definitions and key bindings
- `*.conf` - Kconfig feature flags
- `*.dtsi` - Shared device tree includes:
  - `hillside-common.dtsi` - Common behaviors
  - `hillside-ht.dtsi` - Home row mod hold-tap definitions
  - `hillside-combos.dtsi` - Key combos
  - `shortcuts.dtsi` - OS-specific modifier definitions (LG for Mac GUI, LC for Linux Ctrl)
  - `macros.dtsi` - Custom macros
  - `mouse.dtsi` - Mouse movement configuration

### Dependencies

`config/west.yml` specifies ZMK modules:
- `zmkfirmware/zmk` - Core ZMK firmware (`main`)
- `urob/zmk-helpers` - Helper macros and key labels
- `janpfischer/zmk-dongle-screen` - Display support for dongle, on its `upgrade-4.1` branch (its `main` only builds against ZMK v0.3)

### Shield Definitions

`boards/shields/hillside46/` contains hardware definitions for the Hillside46 keyboard with left/right/dongle variants.

## Keymap Visualization

The `draw-keymaps.yml` workflow auto-generates SVG diagrams using keymap-drawer when keymap files change. Output goes to `keymap-drawer/`.

## Key Patterns

- Conditional layers activate ADJ_L and SYSTEM_L when specific layer combinations are held
- Home row mods use `hml`/`hmr` (hold-tap behaviors) for modifier keys on home row
- `thumb_mt` provides hold-preferred mod-tap for thumb keys
- OS layers (MAC/LNX) have parallel structure with different modifier mappings
