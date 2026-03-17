#!/bin/sh
# ============================================
#   CHROMEBOOK WP DIAGNOSTIC (VT3 SH)
#   Version 47 - Full Color + Explanations
# ============================================

# ---------- COLORS ----------
RED="$(printf '\033[0;31m')"
GREEN="$(printf '\033[0;32m')"
BLUE="$(printf '\033[0;34m')"
YELLOW="$(printf '\033[1;33m')"
CYAN="$(printf '\033[0;36m')"
MAGENTA="$(printf '\033[0;35m')"
WHITE="$(printf '\033[1;37m')"
NC="$(printf '\033[0m')"

# ---------- HEADER ----------
clear
printf "\n%sChromebook WP Diagnostic v47 (VT3) by CriticalHD/neonnebula%s\n" "$CYAN" "$NC"
printf "%s=========================================%s\n" "$YELLOW" "$NC"

# ---------- FUNCTION ----------
print_diagnostics() {

# ---------- DEVICE INFO ----------
printf "\n%s----- DEVICE INFO -----%s\n" "$GREEN" "$NC"

HWID=$(crossystem hwid 2>/dev/null || echo "unknown")
MODEL=$(echo "$HWID" | cut -d'-' -f1)
VER=$(grep CHROMEOS_RELEASE_VERSION /etc/lsb-release 2>/dev/null | cut -d= -f2 || echo "unknown")
SERIAL=$(vpd -l 2>/dev/null | grep -i '^"serial_number"' | cut -d'=' -f2 | tr -d '"' || echo "unknown")

printf "%sModel:%s %s%s%s (used to find board on cros.tech)\n" "$YELLOW" "$NC" "$CYAN" "$MODEL" "$NC"
printf "%sHWID:%s %s%s%s\n" "$YELLOW" "$NC" "$CYAN" "$HWID" "$NC"
printf "%sSerial:%s %s%s%s\n" "$YELLOW" "$NC" "$CYAN" "$SERIAL" "$NC"
printf "%sChromeOS Version:%s %s%s%s (Full: %s%s%s)\n" "$YELLOW" "$NC" "$CYAN" "$VER" "$NC" "$CYAN" "$VER" "$NC"

# ---------- CROSSYSTEM ----------
printf "\n%s----- CROSSYSTEM / DEVICES -----%s\n" "$GREEN" "$NC"

wpsw=$(crossystem wpsw_cur 2>/dev/null || echo "unknown")
devsw=$(crossystem devsw_cur 2>/dev/null || echo "unknown")
dev_usb=$(crossystem dev_boot_usb 2>/dev/null || echo "unknown")
dev_signed=$(crossystem dev_boot_signed_only 2>/dev/null || echo "unknown")
tpm_ver=$(crossystem tpm_kernver 2>/dev/null || echo "unknown")

printf "%swpsw_cur:%s %s%s%s → %sWrite Protect status: %sEnabled%s / %sDisabled%s\n" \
"$YELLOW" "$NC" "$CYAN" "$wpsw" "$NC" \
"$WHITE" "$RED" "$NC" "$GREEN" "$NC"

printf "%sdevsw_cur:%s %s%s%s → %sDeveloper Switch: %sON%s / %sOFF%s\n" \
"$YELLOW" "$NC" "$CYAN" "$devsw" "$NC" \
"$WHITE" "$GREEN" "$NC" "$RED" "$NC"

printf "%sdev_boot_usb:%s %s%s%s → %sUSB boot allowed if 1, disabled if 0%s\n" \
"$YELLOW" "$NC" "$CYAN" "$dev_usb" "$NC" "$WHITE" "$NC"

printf "%sdev_boot_signed_only:%s %s%s%s → %sBoot must be signed if 1, unsigned allowed if 0%s\n" \
"$YELLOW" "$NC" "$CYAN" "$dev_signed" "$NC" "$WHITE" "$NC"

printf "%stpm_kernver:%s %s%s%s → %sTPM firmware rollback version%s\n" \
"$YELLOW" "$NC" "$CYAN" "$tpm_ver" "$NC" "$WHITE" "$NC"

# ---------- GBB FLAGS ----------
printf "\n%s----- GBB FLAGS -----%s\n" "$GREEN" "$NC"

if command -v flashrom >/dev/null 2>&1 && command -v futility >/dev/null 2>&1; then
    TMPGBB=$(mktemp)
    flashrom -p internal -i GBB -r "$TMPGBB" >/dev/null 2>&1
    gbb_flags=$(futility gbb --get --flags "$TMPGBB" 2>/dev/null | awk '{print $2}')
    rm -f "$TMPGBB"

    gbb_flags_dec=$(printf "%d" "$gbb_flags" 2>/dev/null || echo 0)

    printf "%sGBB Flags:%s %s%s%s\n" "$YELLOW" "$NC" "$CYAN" "$gbb_flags" "$NC"

    if [ $((gbb_flags_dec & 16)) -ne 0 ]; then
        printf "%sGBB Dev USB:%s %sFORCED ENABLED%s\n" "$YELLOW" "$NC" "$GREEN" "$NC"
    else
        printf "%sGBB Dev USB:%s %sNot forced%s\n" "$YELLOW" "$NC" "$WHITE" "$NC"
    fi
else
    printf "%sGBB tools unavailable%s\n" "$RED" "$NC"
fi

# ---------- SPI FLASH PROTECTION ----------
printf "\n%s----- SPI FLASH / FMAP -----%s\n" "$GREEN" "$NC"

if command -v flashrom >/dev/null 2>&1; then
    wp_output=$(flashrom --wp-status 2>/dev/null)
    mode=$(echo "$wp_output" | grep -i "Protection mode" | cut -d':' -f2 | tr -d ' ')
    range=$(echo "$wp_output" | grep -i "Protection range" | cut -d':' -f2 | tr -d ' ')

    printf "%sProtection Mode:%s %s%s%s\n" "$YELLOW" "$NC" "$CYAN" "$mode" "$NC"
    printf "%sProtection Range:%s %s%s%s\n" "$YELLOW" "$NC" "$CYAN" "$range" "$NC"

    # RO/RW status based on ChromeOS convention
    if [ "$mode" = "disabled" ]; then
        printf "%sRO: %sWRITABLE%s\n" "$YELLOW" "$GREEN" "$NC"
        printf "%sRW: %sWRITABLE%s\n" "$YELLOW" "$GREEN" "$NC"
        printf "%sSPI flash fully unlocked%s\n" "$GREEN" "$NC"
    elif [ "$mode" = "hardware" ]; then
        printf "%sRO: %sPROTECTED (write-protect applied)%s\n" "$YELLOW" "$RED" "$NC"
        printf "%sRW: %sLIKELY WRITABLE%s\n" "$YELLOW" "$GREEN" "$NC"
        printf "%sHardware protection active → RO locked by straps%s\n" "$WHITE" "$NC"
    elif [ "$mode" = "software" ]; then
        printf "%sRO: %sPROTECTED%s\n" "$YELLOW" "$YELLOW" "$NC"
        printf "%sRW: %sPOSSIBLY WRITABLE%s\n" "$YELLOW" "$GREEN" "$NC"
        printf "%sSoftware protection active → controlled by firmware%s\n" "$WHITE" "$NC"
    else
        printf "%sRO/RW status unknown%s\n" "$RED" "$NC"
    fi
else
    printf "%sflashrom not installed%s\n" "$RED" "$NC"
fi

# ---------- KERNEL MESSAGES ----------
printf "\n%s----- KERNEL MESSAGES -----%s\n" "$GREEN" "$NC"
kernel_msgs=$(dmesg 2>/dev/null | grep -iE "wp|write-protect|spi|flash" | tail -n 10)
if [ -n "$kernel_msgs" ]; then
    printf "%s%s%s\n" "$CYAN" "$kernel_msgs" "$NC"
else
    printf "%sNo relevant kernel messages%s\n" "$RED" "$NC"
fi

# ---------- FIRMWARE READ TEST ----------
printf "\n%s----- FIRMWARE READ TEST -----%s\n" "$GREEN" "$NC"
printf "%sThis may take a while...%s\n" "$YELLOW" "$NC"

TMPFILE=$(mktemp)
flashrom -p internal -r "$TMPFILE" >/dev/null 2>&1
if [ $? -eq 0 ]; then
    printf "%sFlash read SUCCESS%s\n" "$GREEN" "$NC"
else
    printf "%sFlash read FAILED%s\n" "$RED" "$NC"
fi
rm -f "$TMPFILE"

# ---------- FINAL VERDICT ----------
printf "\n%s----- FINAL VERDICT -----%s\n" "$BLUE" "$NC"

case "$mode" in
disabled)
    printf "%sDEVICE FULLY UNLOCKED → Flash writable%s\n" "$GREEN" "$NC"
    ;;
hardware)
    printf "%sSTANDARD CHROMEBOOK WP → RO locked, RW writable%s\n" "$YELLOW" "$NC"
    ;;
software)
    printf "%sSOFTWARE WP → Controlled by firmware, RO protected%s\n" "$YELLOW" "$NC"
    ;;
*)
    printf "%sUNKNOWN / PARTIAL PROTECTION%s\n" "$MAGENTA" "$NC"
    ;;
esac

}

# ---------- RUN ----------
print_diagnostics
