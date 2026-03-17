#!/bin/sh
# ==================================
#   CHROMEBOOK WP DIAGNOSTIC (VT3 SH)
#   Fixed + Cleaned Version
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
printf "\033[1;36mChromebook WP Diagnostic Script (VT3 SH)\033[0m\n"
printf "%s==================================%s\n" "$YELLOW" "$NC"
printf "%s      CHROMEBOOK WP DIAGNOSTIC%s\n" "$YELLOW" "$NC"
printf "%s==================================%s\n" "$YELLOW" "$NC"

# ---------- FUNCTION ----------
print_diagnostics() {

    printf "\n%s----- CROSSYSTEM -----%s\n" "$GREEN" "$NC"

    wpsw=$(crossystem wpsw_cur 2>/dev/null)
    devsw=$(crossystem devsw_cur 2>/dev/null)
    dev_usb=$(crossystem dev_boot_usb 2>/dev/null)
    dev_signed=$(crossystem dev_boot_signed_only 2>/dev/null)

    # ---------- GBB ----------
    gbb_flags=""
    gbb_dev_usb=0

    if command -v flashrom >/dev/null 2>&1 && command -v futility >/dev/null 2>&1; then
        TMPGBB=$(mktemp)
        flashrom -p internal -i GBB -r "$TMPGBB" >/dev/null 2>&1
        gbb_flags=$(futility gbb --get --flags "$TMPGBB" 2>/dev/null | awk '{print $2}')
        rm -f "$TMPGBB"

        gbb_flags_dec=$(printf "%d" "$gbb_flags" 2>/dev/null)

        if [ $((gbb_flags_dec & 16)) -ne 0 ]; then
            gbb_dev_usb=1
        fi
    fi

    # ---------- OUTPUT ----------
    if [ "$wpsw" = "1" ]; then
        printf "wpsw_cur: %s%s%s → %sWP ENABLED%s\n" "$YELLOW" "$wpsw" "$NC" "$RED" "$NC"
    else
        printf "wpsw_cur: %s%s%s → %sWP DISABLED%s\n" "$YELLOW" "$wpsw" "$NC" "$GREEN" "$NC"
    fi

    if [ "$devsw" = "1" ]; then
        printf "devsw_cur: %s%s%s → %sDev Mode ON%s\n" "$YELLOW" "$devsw" "$NC" "$GREEN" "$NC"
    else
        printf "devsw_cur: %s%s%s → %sDev Mode OFF%s\n" "$YELLOW" "$devsw" "$NC" "$RED" "$NC"
    fi

    if [ "$dev_usb" = "1" ]; then
        printf "dev_boot_usb: %s%s%s → %sUSB boot allowed%s\n" "$YELLOW" "$dev_usb" "$NC" "$GREEN" "$NC"
    else
        if [ "$gbb_dev_usb" = "1" ]; then
            printf "dev_boot_usb: %s%s%s → %sUSB allowed (GBB: %s)%s\n" "$YELLOW" "$dev_usb" "$NC" "$GREEN" "$gbb_flags" "$NC"
        else
            printf "dev_boot_usb: %s%s%s → %sUSB disabled%s\n" "$YELLOW" "$dev_usb" "$NC" "$RED" "$NC"
        fi
    fi

    if [ "$dev_signed" = "1" ]; then
        printf "dev_boot_signed_only: %s%s%s → %sSigned-only%s\n" "$YELLOW" "$dev_signed" "$NC" "$RED" "$NC"
    else
        printf "dev_boot_signed_only: %s%s%s → %sUnsigned allowed%s\n" "$YELLOW" "$dev_signed" "$NC" "$GREEN" "$NC"
    fi

    # ---------- SPI PROTECTION MODE ----------
    printf "\n%s----- SPI Protection Mode -----%s\n" "$GREEN" "$NC"

    if command -v flashrom >/dev/null 2>&1; then
        mode=$(flashrom --wp-status 2>/dev/null | grep -i "mode:" | head -n1 | cut -d':' -f2 | tr -d ' ')
        
        if [ -n "$mode" ]; then
            case "$mode" in
                hardware) printf "Protection Mode: %sHARDWARE%s\n" "$RED" "$NC" ;;
                software) printf "Protection Mode: %sSOFTWARE%s\n" "$YELLOW" "$NC" ;;
                disabled) printf "Protection Mode: %sDISABLED%s\n" "$GREEN" "$NC" ;;
                *) printf "Protection Mode: %s%s%s\n" "$MAGENTA" "$mode" "$NC" ;;
            esac
        else
            printf "%sProtection mode unavailable%s\n" "$RED" "$NC"
        fi
    else
        printf "%sflashrom not installed%s\n" "$RED" "$NC"
    fi

    # ---------- KERNEL ----------
    printf "\n%s----- Kernel Messages -----%s\n" "$GREEN" "$NC"

    kernel_msgs=$(dmesg | grep -iE "write-protect|wp:|WP:|HWP|spi|flash" | tail -n 10)

    if [ -n "$kernel_msgs" ]; then
        printf "%s%s%s\n" "$CYAN" "$kernel_msgs" "$NC"
    else
        printf "%sNo relevant kernel WP/SPI messages found%s\n" "$RED" "$NC"
    fi

    # ---------- READ TEST ----------
    printf "\n%s----- Firmware Read Test -----%s\n" "$GREEN" "$NC"
    printf "%sThis may take a while...%s\n" "$YELLOW" "$NC"

    TMPFILE=$(mktemp)
    flashrom -p internal -r "$TMPFILE" >/dev/null 2>&1

    if [ $? -eq 0 ]; then
        printf "%sFlash read SUCCESS%s\n" "$GREEN" "$NC"
    else
        printf "%sFlash read FAILED%s\n" "$RED" "$NC"
    fi

    rm -f "$TMPFILE"
}

# ---------- RUN ----------
print_diagnostics
