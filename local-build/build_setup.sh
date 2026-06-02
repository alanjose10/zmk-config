#!/usr/bin/env bash
#
# build_setup.sh - Build ZMK firmware locally inside a Docker container.
#
# OVERVIEW
# --------
# This script runs inside the zmkfirmware/zmk-dev-arm:stable Docker image,
# launched by docker-compose.yml via Makefile targets (e.g. `make hillside`).
# It compiles ZMK firmware for a single keyboard and outputs .uf2 files to
# the firmwares/ directory at the repo root.
#
# This is the LOCAL build counterpart to build.yaml, which drives GitHub
# Actions CI. Both define the same board+shield combos, but independently.
#
# HOW IT WORKS
# ------------
# 1. The repo is mounted READ-ONLY at /zmk-config (source files stay safe).
# 2. The firmwares/ dir is mounted READ-WRITE at /firmwares (output only).
# 3. The script copies the repo to /tmp/zmk-build/ (writable temp space)
#    so that west can initialize and fetch modules there.
# 4. `west init` + `west update` pulls ZMK, Zephyr, and all modules defined
#    in config/west.yml into the working directory.
# 5. Custom shields (boards/shields/*) are made discoverable via a "user
#    module" — an isolated copy of just boards/ and zephyr/module.yml,
#    passed to the build via -DZMK_EXTRA_MODULES. This must be separate
#    from the main working directory because west update overwrites
#    zephyr/ with the full Zephyr RTOS, which causes recursive Kconfig
#    errors if used as a module directly.
# 6. The selected keyboard's setup function defines a BUILDS array of
#    board|shield|cmake_args entries.
# 7. Each entry is compiled with `west build` and the resulting .uf2
#    (or .bin) is copied to /firmwares/.
#
# ADDING A NEW KEYBOARD
# ---------------------
# 1. Add a setup_<name>() function below that populates the BUILDS array.
#    Each entry is: "board|shield|optional_cmake_args"
#    Use the setup function for any keyboard-specific pre-build steps
#    (e.g. copying extra drivers, setting env vars).
# 2. Add the name to the case statement in the MAIN section.
# 3. Add a Make target in the Makefile:
#      myboard: ## Build myboard firmware
#          cd local-build && docker compose run --rm -e KEYBOARD=myboard builder
#
# DEBUGGING
# ---------
# Drop into an interactive shell:   make shell
# Then run manually:                KEYBOARD=hillside bash ./local-build/build_setup.sh
# Save logs:                        make hillside > build_log.txt 2>&1
#

set -euo pipefail
START_TIME=$(date +%s)

# --- PATHS ---
# These correspond to the volume mounts defined in docker-compose.yml.
REPO_MOUNT="/zmk-config"          # Read-only mount of the host repo
WORK_DIR="/tmp/zmk-build"         # Writable workspace (ephemeral, inside container)
USER_MODULE="$WORK_DIR/user-module" # Isolated copy of boards/ + zephyr/module.yml
OUTPUT_DIR="/firmwares"            # Read-write mount for firmware output

KEYBOARD="${KEYBOARD:?Usage: specify KEYBOARD via make target (e.g. make hillside)}"

# ===========================================================================
# PER-KEYBOARD SETUP FUNCTIONS
# ===========================================================================
# Each function populates the BUILDS array with entries in the format:
#   "board|shield|cmake_args(optional)"
#
# The board and shield values match what you'd pass to west build:
#   west build -b <board> -- -DSHIELD="<shield>"
#
# Multiple shields can be space-separated (e.g. "hillside46_dongle dongle_screen").
# cmake_args are appended to the west build command for that entry.

setup_hillside_mac() {
    BUILDS=(
        "nice_nano_v2|settings_reset"
        "seeeduino_xiao_ble|settings_reset"
        "nice_nano_v2|hillside46mac_right"
        "nice_nano_v2|hillside46mac_left"
        "seeeduino_xiao_ble|hillside46mac_dongle dongle_screen"
        "nice_nano_v2|hillside46mac_dongle"
    )
}

setup_hillside_linux() {
    BUILDS=(
        "nice_nano_v2|settings_reset"
        "seeeduino_xiao_ble|settings_reset"
        "nice_nano_v2|hillside46linux_right"
        "nice_nano_v2|hillside46linux_left"
        "seeeduino_xiao_ble|hillside46linux_dongle dongle_screen"
        "nice_nano_v2|hillside46linux_dongle"
    )
}

setup_kyria() {
    BUILDS=(
        "nice_nano_v2|settings_reset"
        "nice_nano_v2|kyria_rev3_left"
        "nice_nano_v2|kyria_rev3_right"
        "seeeduino_xiao_ble|kyria_rev3_dongle"
    )
}

# ===========================================================================
# COMMON FUNCTIONS
# ===========================================================================

# setup_workspace: Prepare the ZMK build environment.
#
# Copies the repo into a writable temp directory, initializes the west
# workspace, fetches all modules (ZMK, Zephyr, helpers, etc.), and creates
# an isolated "user module" directory so the build can find our custom
# shield definitions without conflicting with the fetched Zephyr sources.
setup_workspace() {
    echo ""
    echo "=== SETUP ZMK WORKSPACE ==="

    echo "Copying repo to working directory..."
    mkdir -p "$WORK_DIR"
    cp -r "$REPO_MOUNT/." "$WORK_DIR/"

    cd "$WORK_DIR"

    if [ ! -d ".west" ]; then
        echo "Initializing west workspace..."
        west init -l config
    fi

    echo "Updating west modules..."
    west update

    echo "Preparing Zephyr build environment..."
    west zephyr-export

    # Create an isolated user module with just our custom boards/shields.
    # Why not point ZMK_EXTRA_MODULES at $WORK_DIR directly?
    # Because west update places the full Zephyr RTOS at $WORK_DIR/zephyr/,
    # and Zephyr's module system would re-source its own Kconfig files,
    # causing a "recursive source" error. By copying only boards/ and our
    # small zephyr/module.yml into a clean directory, we avoid the conflict.
    echo "Setting up user module..."
    rm -rf "$USER_MODULE"
    mkdir -p "$USER_MODULE/zephyr"
    cp -r "$REPO_MOUNT/boards" "$USER_MODULE/"
    cp "$REPO_MOUNT/zephyr/module.yml" "$USER_MODULE/zephyr/"
}

# build_firmware: Compile firmware for one board+shield combo.
#
# Args:
#   $1 - board   (e.g. "nice_nano_v2")
#   $2 - shield  (e.g. "hillside46_left" or "hillside46_dongle dongle_screen")
#   $3 - cmake_args (optional, extra cmake flags)
#
# Output:
#   Copies the compiled .uf2 (or .bin) to $OUTPUT_DIR/<shield>-<board>.uf2
build_firmware() {
    local board="$1"
    local shield="$2"
    local cmake_args="${3:-}"

    # Artifact name: spaces in shield names become underscores
    local artifact_name
    artifact_name="$(echo "${shield}" | tr ' ' '_')-${board}"

    local build_dir="$WORK_DIR/build/${artifact_name}"

    printf '\n=== BUILDING FIRMWARE ===\n'
    printf '  Board  : %s\n' "$board"
    printf '  Shield : %s\n' "$shield"
    if [ -n "$cmake_args" ]; then
        printf '  Args   : %s\n' "$cmake_args"
    fi
    printf '\n'

    # shellcheck disable=SC2086
    west build --pristine \
        -s "$WORK_DIR/zmk/app" \
        -d "$build_dir" \
        -b "$board" \
        -- \
        -DZMK_CONFIG="$WORK_DIR/config" \
        -DSHIELD="$shield" \
        -DZMK_EXTRA_MODULES="$USER_MODULE" \
        $cmake_args

    # Locate the compiled firmware (prefer .uf2, fall back to .bin)
    local artifact_src=""
    local artifact_ext=""
    if [ -f "$build_dir/zephyr/zmk.uf2" ]; then
        artifact_src="$build_dir/zephyr/zmk.uf2"
        artifact_ext="uf2"
    elif [ -f "$build_dir/zephyr/zmk.bin" ]; then
        artifact_src="$build_dir/zephyr/zmk.bin"
        artifact_ext="bin"
    else
        echo "[WARN] No firmware artifact found for ${artifact_name}"
        return 1
    fi

    mkdir -p "$OUTPUT_DIR"
    local dest="$OUTPUT_DIR/${artifact_name}.${artifact_ext}"
    cp "$artifact_src" "$dest"
    chmod 666 "$dest"
    printf '  Output : %s\n' "${artifact_name}.${artifact_ext}"
}

# ===========================================================================
# MAIN
# ===========================================================================

setup_workspace

echo ""
echo "=== BUILDING KEYBOARD: ${KEYBOARD} ==="

case "$KEYBOARD" in
    hillside-mac)   setup_hillside_mac ;;
    hillside-linux) setup_hillside_linux ;;
    kyria)          setup_kyria ;;
    *)              echo "Unknown keyboard: $KEYBOARD"; exit 1 ;;
esac

rm -rf "$OUTPUT_DIR"/*

for entry in "${BUILDS[@]}"; do
    IFS='|' read -r board shield cmake_args <<< "$entry"
    build_firmware "$board" "$shield" "$cmake_args"
done

# --- SUMMARY ---
END_TIME=$(date +%s)
ELAPSED=$(( END_TIME - START_TIME ))
MINUTES=$(( ELAPSED / 60 ))
SECONDS=$(( ELAPSED % 60 ))

echo ""
echo "=== BUILD COMPLETE ==="
echo "Duration: ${MINUTES}m ${SECONDS}s"
echo "Firmware files:"
ls -1 "$OUTPUT_DIR"/ 2>/dev/null || echo "  (none)"
echo ""
