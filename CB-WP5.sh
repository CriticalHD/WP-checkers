#!/bin/sh
# ==================================
#   CHROMEBOOK WP DIAGNOSTIC (VT3 SH)
#   v46 - FULL + DETAILED
# ==================================

# ---------- COLORS ----------
RED="$(printf '\033[0;31m')"
GREEN="$(printf '\033[0;32m')"
BLUE="$(printf '\033[0;34m')"
YELLOW="$(printf '\033[1;33m')"
CYAN="$(printf '\033[0;36m')"
MAGENTA="$(printf '\033[0;35m')"
NC="$(printf '\033[0m')"

clear
printf "\033[1;36mChromebook WP Diagnostic v46 (VT3)\033[0m\n"
printf "%s==================================%s\n" "$YELLOW" "$NC"

print_diagnostics() {

# ---------- DEVICE ----------
printf "\n%s----- DEVICE INFO -----%s\n" "$GREEN" "$NC"

HWID=$(crossystem hwid 2>/dev/null)
MODEL=$(echo "$HWID" | cut -d'-' -f1)
VER=$(grep CHROMEOS_RELEASE_VERSION /etc/lsb-release 2>/dev/null | cut -d= -f2)

printf "Model: %s%s%s\n" "$CYAN" "$MODEL" "$NC"
printf "HWID: %s%s%s\n" "$CYAN" "$HWID" "$NC"
printf "ChromeOS: %s%s%s\n" "$CYAN" "$VER" "$NC"

# ---------- CROSSYSTEM ----------
printf "\n%s----- CROSSYSTEM -----%s\n" "$GREEN" "$NC"

wpsw=$(crossystem wpsw_cur 2>/dev/null)
devsw=$(crossystem devsw_cur 2>/dev/null)
dev_usb=$(crossystem dev_boot_usb 2>/dev/null)
dev_signed=$(crossystem dev_boot_signed_only 2>/dev/null)
tpm_ver=$(crossystem tpm_kernver 2>/dev/null)

printf "wpsw_cur: %s%s%s\n" "$YELLOW" "$wpsw" "$NC"
printf "devsw_cur: %s%s%s\n" "$YELLOW" "$devsw" "$NC"
printf "dev_boot_usb: %s%s%s\n" "$YELLOW" "$dev_usb" "$NC"
printf "dev_boot_signed_only: %s%s%s\n" "$YELLOW" "$dev_signed" "$NC"
printf "tpm_kernver: %s%s%s\n" "$YELLOW" "$tpm_ver" "$NC"

# ---------- GBB ----------
printf "\n%s----- GBB FLAGS -----%s\n" "$GREEN" "$NC"

if command -v flashrom >/dev/null 2>&1 && command -v futility >/dev/null 2>&1; then
    TMPGBB=$(mktemp)
    flashrom -p internal -i GBB -r "$TMPGBB" >/dev/null 2>&1
    gbb_flags=$(futility gbb --get --flags "$TMPGBB" 2>/dev/null | awk '{print $2}')
    rm -f "$TMPGBB"

    printf "GBB Flags: %s%s%s\n" "$CYAN" "$gbb_flags" "$NC"

    gbb_flags_dec=$(printf "%d" "$gbb_flags" 2>/dev/null)

    if [ $((gbb_flags_dec & 16)) -ne 0 ]; then
        printf "GBB Dev USB: %sFORCED ENABLED%s\n" "$GREEN" "$NC"
    else
        printf "GBB Dev USB: %sNot forced%s\n" "$YELLOW" "$NC"
    fi
else
    printf "%sGBB tools unavailable%s\n" "$RED" "$NC"
fi

# ---------- SPI ----------
printf "\n%s----- SPI PROTECTION ANALYSIS -----%s\n" "$GREEN" "$NC"

if command -v flashrom >/dev/null 2>&1; then
    wp_output=$(flashrom --wp-status 2>/dev/null)

    mode=$(echo "$wp_output" | grep -i "Protection mode" | cut -d':' -f2 | tr -d ' ')
    range=$(echo "$wp_output" | grep -i "Protection range" | cut -d':' -f2)

    printf "Mode: %s%s%s\n" "$CYAN" "$mode" "$NC"
    printf "Range: %s%s%s\n" "$CYAN" "$range" "$NC"

    printf "\n%s[INTERPRETATION]%s\n" "$BLUE" "$NC"

    case "$mode" in
        disabled)
            printf "%sNo SPI protection active%s\n" "$GREEN" "$NC"
            printf "RO: %sWRITABLE%s\n" "$GREEN" "$NC"
            printf "RW: %sWRITABLE%s\n" "$GREEN" "$NC"
        ;;
        hardware)
            printf "%sHardware WP enabled (physical or strap controlled)%s\n" "$RED" "$NC"
            printf "Typical state: RO locked, RW writable\n"

            if echo "$range" | grep -qi "none"; then
                printf "RO: %sWRITABLE (unexpected)%s\n" "$GREEN" "$NC"
            else
                printf "RO: %sPROTECTED%s\n" "$RED" "$NC"
            fi

            printf "RW: %sLIKELY WRITABLE%s\n" "$YELLOW" "$NC"
        ;;
        software)
            printf "%sSoftware WP enabled (firmware controlled)%s\n" "$YELLOW" "$NC"
            printf "RO: %sPROTECTED%s\n" "$YELLOW" "$NC"
            printf "RW: %sPOSSIBLY WRITABLE%s\n" "$YELLOW" "$NC"
        ;;
        *)
            printf "%sUnknown protection mode%s\n" "$MAGENTA" "$NC"
        ;;
    esac
else
    printf "%sflashrom not available%s\n" "$RED" "$NC"
fi

# ---------- KERNEL ----------
printf "\n%s----- KERNEL (WP / SPI) -----%s\n" "$GREEN" "$NC"

kernel_msgs=$(dmesg | grep -iE "wp|write-protect|spi|flash" | tail -n 10)

if [ -n "$kernel_msgs" ]; then
    printf "%s%s%s\n" "$CYAN" "$kernel_msgs" "$NC"
else
    printf "%sNo relevant kernel messages%s\n" "$RED" "$NC"
fi

# ---------- READ TEST ----------
printf "\n%s----- FIRMWARE READ TEST -----%s\n" "$GREEN" "$NC"
printf "%sThis may take a while...%s\n" "$YELLOW" "$NC"

TMPFILE=$(mktemp)
flashrom -p internal -r "$TMPFILE" >/dev/null 2>&1

if [ $? -eq 0 ]; then
    printf "%sFlash read SUCCESS (SPI accessible)%s\n" "$GREEN" "$NC"
else
    printf "%sFlash read FAILED%s\n" "$RED" "$NC"
fi

rm -f "$TMPFILE"

# ---------- FINAL VERDICT ----------
printf "\n%s----- FINAL VERDICT -----%s\n" "$BLUE" "$NC"

if [ "$mode" = "disabled" ]; then
    printf "%sDEVICE IS FULLY UNLOCKED%s\n" "$GREEN" "$NC"
elif [ "$mode" = "hardware" ]; then
    printf "%sSTANDARD CHROMEBOOK WP (RO locked)%s\n" "$YELLOW" "$NC"
else
    printf "%sUNKNOWN / PARTIAL PROTECTION%s\n" "$MAGENTA" "$NC"
fi

}

print_diagnostics
