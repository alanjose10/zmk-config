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
west build -d build/output -b nice_nano_v2 -- -DSHIELD=hillside46_left config
```

## Build Configuration

`build.yaml` defines the build matrix of board+shield combinations:
- Boards: nice_nano_v2, seeeduino_xiao_ble
- Shields: hillside46_left, hillside46_right, hillside46_dongle, settings_reset

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
- `zmkfirmware/zmk` - Core ZMK firmware (v0.3)
- `urob/zmk-helpers` - Helper macros and key labels
- `janpfischer/zmk-dongle-screen` - Display support for dongle

### Shield Definitions

`boards/shields/hillside46/` contains hardware definitions for the Hillside46 keyboard with left/right/dongle variants.

## Keymap Visualization

The `draw-keymaps.yml` workflow auto-generates SVG diagrams using keymap-drawer when keymap files change. Output goes to `keymap-drawer/`.

## Key Patterns

- Conditional layers activate ADJ_L and SYSTEM_L when specific layer combinations are held
- Home row mods use `hml`/`hmr` (hold-tap behaviors) for modifier keys on home row
- `thumb_mt` provides hold-preferred mod-tap for thumb keys
- OS layers (MAC/LNX) have parallel structure with different modifier mappings
