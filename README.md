# ZMK Config



## Local ZMK Firmware Builds (Docker)

Build ZMK firmware locally without installing toolchains. Requires only Docker.

### Quick Start

```bash
# Build a specific keyboard
make hillside
make kyria

# See all available commands
make help
```

Firmware files appear in `firmwares/` at the repo root.

### makerdiary nRF52840 MDK USB Dongle

`make hillside` also builds `hillside46_dongle-nrf52840_mdk_dongle.uf2` and
`settings_reset-nrf52840_mdk_dongle.uf2` for the
[makerdiary nRF52840 MDK USB Dongle](https://wiki.makerdiary.com/nrf52840-mdk-usb-dongle/).
To flash: with the dongle plugged in, double-press its button within half a second. The LED
turns green and a `UF2BOOT` drive mounts. Copy the uf2 onto it. Holding the button while
plugging in does not work, because the button is wired as reset. Flash `settings_reset` to both halves before
you move them to a new dongle, so they drop the old bond.

### Adding a New Keyboard

1. Add a `setup_<name>()` function in `build_setup.sh` defining the board+shield combos
2. Add the keyboard to the `case` statement in the main section
3. Add a Make target in `Makefile`

### Troubleshooting

Drop into an interactive shell inside the container:

```bash
make shell
```

Then run the build script manually:

```bash
KEYBOARD=hillside bash ./local-build/build_setup.sh
```

Save build output to a file:

```bash
make hillside > build_log.txt 2>&1
```

## Hillside46
![image](keymap-drawer/hillside46.svg)

## Kyria
![image](keymap-drawer/kyria_rev3.svg)
