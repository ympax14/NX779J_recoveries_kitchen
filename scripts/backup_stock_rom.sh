#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# NX779J (RedMagic 10 Air) — Stock ROM Full Partition Backup
# ─────────────────────────────────────────────────────────────────────────────
# Runs on the HOST (Linux PC). Device must be booted into PBRP/TWRP recovery
# with ADB enabled (enable MTP/ADB from the recovery sidebar).
#
# Output: NX779J_recoveries_kitchen/backups/stock_YYYYMMDD_HHMMSS/
#   ├── boot_a.img  boot_b.img  vendor_boot_*.img  init_boot_*.img
#   ├── dtbo_*.img  vbmeta_*.img  vbmeta_system_*.img
#   ├── super.img            (system + vendor + product + odm + …)
#   ├── modem_*.img  bluetooth_*.img  dsp_*.img
#   ├── persist.img
#   ├── firmware/            (xbl, tz, hyp, abl, aop, devcfg, keymaster)
#   ├── device_info.txt
#   ├── checksums.sha256
#   └── restore.sh           (fastboot-based full restore)
#
# Requirements:  adb  fastboot  (pv optional – shows progress bars)
# Disk space:    ~25 GB free (super alone is 9-13 GB)
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail
IFS=$'\n\t'

# ── Paths ────────────────────────────────────────────────────────────────────
KITCHEN="$(cd "$(dirname "$0")/.." && pwd)"
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
BACKUP_DIR="$KITCHEN/backups/stock_${TIMESTAMP}"
BY_NAME="/dev/block/bootdevice/by-name"

# ── Colors ───────────────────────────────────────────────────────────────────
R='\033[0;31m' G='\033[0;32m' Y='\033[1;33m' C='\033[0;36m' B='\033[1;34m' N='\033[0m'
info()  { echo -e "${C}[INFO]${N} $*"; }
ok()    { echo -e "${G}[ OK ]${N} $*"; }
warn()  { echo -e "${Y}[WARN]${N} $*"; }
die()   { echo -e "${R}[ERR ]${N} $*" >&2; exit 1; }
hdr()   { echo -e "\n${B}══ $* ${N}"; }

# ── ADB helpers ──────────────────────────────────────────────────────────────
ADB="${ADB:-adb}"
adb_sh() { $ADB shell "$@" 2>/dev/null | tr -d '\r'; }

check_adb() {
    command -v "$ADB" >/dev/null 2>&1 || die "adb not found. Install android-tools."
    local state
    state="$($ADB get-state 2>/dev/null || echo offline)"
    if [[ "$state" != "recovery" ]]; then
        die "Device state: '$state' — expected 'recovery'.\nBoot the NX779J into PBRP then enable ADB (sidebar → ADB sideload / MTP toggle)."
    fi
    # Escalate to root inside recovery
    $ADB root >/dev/null 2>&1 || true
    sleep 1
}

# ── Partition existence check ─────────────────────────────────────────────────
part_exists() {
    adb_sh "test -e '$BY_NAME/$1' && echo yes || echo no" | grep -q "^yes"
}

part_path() {
    # Resolve symlink → real block device path
    adb_sh "readlink -f '$BY_NAME/$1' 2>/dev/null || echo ''"
}

part_size_bytes() {
    adb_sh "blockdev --getsize64 '$BY_NAME/$1' 2>/dev/null || echo 0"
}

human_size() {
    local b=$1
    if   (( b >= 1073741824 )); then printf "%d.%d GB" "$(( b / 1073741824 ))" "$(( (b % 1073741824) * 10 / 1073741824 ))"
    elif (( b >= 1048576    )); then printf "%d.%d MB" "$(( b / 1048576 ))"    "$(( (b % 1048576)    * 10 / 1048576 ))"
    elif (( b >= 1024       )); then printf "%d KB"    "$(( b / 1024 ))"
    else printf "%d B" "$b"
    fi
}

# ── Partition dump ────────────────────────────────────────────────────────────
# Uses pv for progress if installed, else silent dd.
HAS_PV=false
command -v pv >/dev/null 2>&1 && HAS_PV=true

dump_partition() {
    local part="$1"   # partition name (no slot suffix)
    local slot="$2"   # "_a", "_b", or "" for non-A/B
    local outdir="$3" # destination directory

    local full="${part}${slot}"
    local outfile="$outdir/${full}.img"

    if ! part_exists "$full"; then
        warn "  $full — not found, skipping"
        return 0
    fi

    local size
    size=$(part_size_bytes "$full")
    printf "  %-28s %s … " "$full" "$(human_size "$size")"

    if $HAS_PV; then
        $ADB exec-out "dd if='$BY_NAME/$full' bs=4M 2>/dev/null" \
            | pv -s "$size" -W -p -e -r > "$outfile"
    else
        $ADB exec-out "dd if='$BY_NAME/$full' bs=4M 2>/dev/null" > "$outfile"
    fi

    local actual
    actual=$(stat -c%s "$outfile" 2>/dev/null || echo 0)
    if (( actual < 4096 )); then
        warn "  WARNING: $outfile is suspiciously small (${actual} bytes) — may be corrupt"
    else
        echo -e "${G}done${N} ($(human_size "$actual"))"
    fi
}

# ── Disk space estimate ───────────────────────────────────────────────────────
estimate_space() {
    hdr "Estimating required disk space"
    local total=0
    for p in boot_a vendor_boot_a init_boot_a dtbo_a vbmeta_a vbmeta_system_a \
              modem_a bluetooth_a dsp_a persist super \
              abl_a aop_a devcfg_a hyp_a keymaster_a tz_a xbl_a xbl_config_a; do
        local sz
        sz=$(part_size_bytes "${p}" 2>/dev/null || echo 0)
        (( total += sz )) || true
    done
    # Double for both slots (approx)
    (( total *= 2 )) || true
    info "Estimated backup size: ~$(human_size "$total") (uncompressed)"

    local free_kb
    free_kb=$(df -k "$KITCHEN" | awk 'NR==2{print $4}')
    local free_b=$(( free_kb * 1024 ))
    info "Free space in $KITCHEN: $(human_size "$free_b")"

    if (( total > free_b )); then
        die "Not enough free disk space. Need ~$(human_size "$total"), have $(human_size "$free_b")."
    fi
}

# ── Device info ───────────────────────────────────────────────────────────────
save_device_info() {
    local out="$BACKUP_DIR/device_info.txt"
    {
        echo "Backup date    : $(date)"
        echo "Device         : $(adb_sh getprop ro.product.model)"
        echo "Build          : $(adb_sh getprop ro.build.description)"
        echo "Android        : $(adb_sh getprop ro.build.version.release)"
        echo "Security patch : $(adb_sh getprop ro.build.version.security_patch)"
        echo "Slot (current) : $(adb_sh getprop ro.boot.slot_suffix)"
        echo "Bootloader     : $(adb_sh getprop ro.boot.bootloader)"
        echo "Serialno       : $($ADB get-serialno)"
        echo ""
        echo "── Partition layout ──────────────────────────────────────"
        adb_sh "ls -la $BY_NAME/" 2>/dev/null | sort
    } > "$out"
    ok "Device info saved → device_info.txt"
}

# ── Checksum ──────────────────────────────────────────────────────────────────
make_checksums() {
    hdr "Computing SHA-256 checksums"
    (
        cd "$BACKUP_DIR"
        find . -name "*.img" | sort | xargs sha256sum
    ) > "$BACKUP_DIR/checksums.sha256"
    ok "Checksums written → checksums.sha256"
}

verify_checksums() {
    (
        cd "$BACKUP_DIR"
        sha256sum --check checksums.sha256 --quiet
    ) && ok "All checksums verified." || warn "Some checksum mismatches detected — backup may be incomplete."
}

# ── Restore script generation ─────────────────────────────────────────────────
generate_restore_script() {
    local slot
    slot="$(adb_sh getprop ro.boot.slot_suffix | tr -d '_')"  # "a" or "b"

    cat > "$BACKUP_DIR/restore.sh" << RESTORE_EOF
#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# NX779J Stock ROM Restore Script
# Generated: $(date)
# Source build: $(adb_sh getprop ro.build.description)
# ─────────────────────────────────────────────────────────────────────────────
# HOW TO USE:
#   1. Boot device into FASTBOOT (hold Vol- + Power, or: adb reboot bootloader)
#   2. Run:  bash restore.sh
#
# OPTIONS:
#   bash restore.sh --full        Full restore (incl. firmware/ — use with care)
#   bash restore.sh --images-only Skip super (faster — restores boot/kernel/recovery only)
#
# WARNING: This erases the current system. Your userdata/personal files are
#          NOT touched unless you explicitly uncomment the userdata flash below.
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

SCRIPT_DIR="\$(cd "\$(dirname "\$0")" && pwd)"
FASTBOOT="\${FASTBOOT:-fastboot}"
FULL=false
IMAGES_ONLY=false

for arg in "\$@"; do
    case "\$arg" in
        --full)        FULL=true ;;
        --images-only) IMAGES_ONLY=true ;;
    esac
done

R='\033[0;31m' G='\033[0;32m' Y='\033[1;33m' C='\033[0;36m' N='\033[0m'
info() { echo -e "\${C}[INFO]\${N} \$*"; }
ok()   { echo -e "\${G}[ OK ]\${N} \$*"; }
warn() { echo -e "\${Y}[WARN]\${N} \$*"; }
die()  { echo -e "\${R}[ERR ]\${N} \$*" >&2; exit 1; }

check_fastboot() {
    command -v "\$FASTBOOT" >/dev/null 2>&1 || die "fastboot not found."
    local state
    state="\$("\$FASTBOOT" getvar product 2>&1 | head -1 || echo offline)"
    echo "\$state" | grep -qi "NX779J\|pineapple\|redmagic\|product" \
        || warn "Unexpected device in fastboot — double-check you have the right phone connected."
}

flash() {
    local part="\$1" file="\$2"
    if [[ ! -f "\$SCRIPT_DIR/\$file" ]]; then
        warn "  \$file not found, skipping \$part"
        return 0
    fi
    info "Flashing \$part ← \$file"
    "\$FASTBOOT" flash "\$part" "\$SCRIPT_DIR/\$file"
}

check_fastboot

echo ""
echo "══ Boot chain (both slots) ══════════════════════════════════"
for part in boot vendor_boot init_boot dtbo vbmeta vbmeta_system; do
    flash "\${part}_a" "\${part}_a.img"
    flash "\${part}_b" "\${part}_b.img"
done

echo ""
echo "══ Radio / DSP firmware (both slots) ════════════════════════"
for part in modem bluetooth dsp; do
    flash "\${part}_a" "\${part}_a.img"
    flash "\${part}_b" "\${part}_b.img"
done

echo ""
echo "══ Persist partition ════════════════════════════════════════"
flash persist persist.img

if ! \$IMAGES_ONLY; then
    echo ""
    echo "══ Super (system + vendor + product + odm) ══════════════════"
    warn "Flashing super — this will take several minutes..."
    flash super super.img
fi

if \$FULL; then
    echo ""
    echo "══ Firmware (xbl / tz / hyp / abl / aop / keymaster) ════════"
    warn "Flashing low-level firmware. Device will be unbootable if mismatched hardware."
    for part in xbl xbl_config abl aop aop_config devcfg hyp keymaster tz; do
        flash "\${part}_a" "firmware/\${part}_a.img"
        flash "\${part}_b" "firmware/\${part}_b.img"
    done
fi

# Uncomment to also wipe/restore userdata (DESTROYS ALL PERSONAL DATA):
# echo "══ Userdata wipe ════════════════════════════════════════════"
# "\$FASTBOOT" -w

echo ""
ok "Restore complete. Rebooting…"
"\$FASTBOOT" reboot
RESTORE_EOF

    chmod +x "$BACKUP_DIR/restore.sh"
    ok "Restore script generated → restore.sh"
}

# ══════════════════════════════════════════════════════════════════════════════
# MAIN
# ══════════════════════════════════════════════════════════════════════════════
main() {
    echo -e "\n${B}╔══════════════════════════════════════════════════════╗${N}"
    echo -e "${B}║   NX779J Stock ROM Backup — $(date '+%Y-%m-%d %H:%M:%S')   ║${N}"
    echo -e "${B}╚══════════════════════════════════════════════════════╝${N}"

    hdr "Checking ADB connection"
    check_adb
    ok "Device found in recovery mode"

    estimate_space

    mkdir -p "$BACKUP_DIR/firmware"
    info "Backup directory: $BACKUP_DIR"

    hdr "Saving device info"
    save_device_info

    # ── Boot chain ──────────────────────────────────────────────────────────
    hdr "Boot chain partitions (A + B slots)"
    for part in boot vendor_boot init_boot dtbo vbmeta vbmeta_system; do
        dump_partition "$part" "_a" "$BACKUP_DIR"
        dump_partition "$part" "_b" "$BACKUP_DIR"
    done

    # ── Radio / DSP ─────────────────────────────────────────────────────────
    hdr "Radio / DSP firmware (A + B slots)"
    for part in modem bluetooth dsp; do
        dump_partition "$part" "_a" "$BACKUP_DIR"
        dump_partition "$part" "_b" "$BACKUP_DIR"
    done

    # ── Persist ─────────────────────────────────────────────────────────────
    hdr "Persist partition (calibration data)"
    dump_partition "persist" "" "$BACKUP_DIR"

    # ── Super (big one) ─────────────────────────────────────────────────────
    hdr "Super partition — system + vendor + product + odm"
    warn "This is the largest partition (~9-13 GB). Please wait…"
    dump_partition "super" "" "$BACKUP_DIR"

    # ── Low-level firmware (firmware/ subdir) ────────────────────────────────
    hdr "Low-level firmware (xbl / tz / hyp / abl / aop / keymaster)"
    warn "Saved for reference. Do NOT flash these unless you know exactly what you're doing."
    for part in xbl xbl_config abl aop aop_config devcfg hyp keymaster tz; do
        dump_partition "$part" "_a" "$BACKUP_DIR/firmware"
        dump_partition "$part" "_b" "$BACKUP_DIR/firmware"
    done

    # ── Finalize ─────────────────────────────────────────────────────────────
    hdr "Finalizing backup"
    make_checksums
    verify_checksums
    generate_restore_script

    # Summary
    local total_size
    total_size=$(du -sh "$BACKUP_DIR" | cut -f1)

    echo ""
    echo -e "${G}╔══════════════════════════════════════════════════════╗${N}"
    echo -e "${G}║              BACKUP COMPLETE ✓                       ║${N}"
    echo -e "${G}╚══════════════════════════════════════════════════════╝${N}"
    echo ""
    echo -e "  Location : ${C}$BACKUP_DIR${N}"
    echo -e "  Size     : ${C}$total_size${N}"
    echo ""
    echo -e "  To restore stock ROM later:"
    echo -e "    ${Y}adb reboot bootloader${N}"
    echo -e "    ${Y}bash $BACKUP_DIR/restore.sh${N}"
    echo ""
    echo -e "  To restore boot chain only (no super):"
    echo -e "    ${Y}bash $BACKUP_DIR/restore.sh --images-only${N}"
    echo ""
}

main "$@"
