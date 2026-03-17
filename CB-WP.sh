#!/bin/sh
# ==================================
#   CHROMEBOOK WP DIAGNOSTIC (VT3 SH)
#   Ported from v43
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
printf "\033[1;36mChromebook WP Diagnostic Script - VT3 SH Port\033[0m\n"
printf "%s==================================%s\n" "$YELLOW" "$NC"
printf "%s      CHROMEBOOK WP DIAGNOSTIC%s\n" "$YELLOW" "$NC"
printf "%s==================================%s\n" "$YELLOW" "$NC"

# ---------- FUNCTIONS ----------
print_diagnostics() {

    printf "\n%s----- CROSSYSTEM (Firmware / DevMode info) -----%s\n" "$GREEN" "$NC"

    wpsw=$(crossystem wpsw_cur 2>/dev/null)
    devsw=$(crossystem devsw_cur 2>/dev/null)
    dev_usb=$(crossystem dev_boot_usb 2>/dev/null)
    dev_signed=$(crossystem dev_boot_signed_only 2>/dev/null)

    # ---------- GBB FLAGS ----------
    gbb_flags=""
    gbb_modified=0
    gbb_dev_usb=0

    if command -v flashrom >/dev/null 2>&1 && command -v futility >/dev/null 2>&1; then
        TMPGBB=$(mktemp)
        flashrom -p internal -i GBB -r "$TMPGBB" >/dev/null 2>&1
        gbb_flags=$(futility gbb --get --flags "$TMPGBB" 2>/dev/null | awk '{print $2}')
        rm -f "$TMPGBB"

        if [ -n "$gbb_flags" ] && [ "$gbb_flags" != "0x0" ] && [ "$gbb_flags" != "0" ]; then
            gbb_modified=1
        fi

        # convert hex safely
        gbb_flags_dec=$(printf "%d" "$gbb_flags" 2>/dev/null)

        if [ $((gbb_flags_dec & 16)) -ne 0 ]; then
            gbb_dev_usb=1
        fi
    fi

    # ---------- OUTPUT ----------
    if [ "$wpsw" = "1" ]; then
        printf "wpsw_cur: %s%s%s → %sFlash write-protect ENABLED%s\n" "$YELLOW" "$wpsw" "$NC" "$RED" "$NC"
    else
        printf "wpsw_cur: %s%s%s → %sFlash write-protect DISABLED%s\n" "$YELLOW" "$wpsw" "$NC" "$GREEN" "$NC"
    fi

    if [ "$devsw" = "1" ]; then
        printf "devsw_cur: %s%s%s → %sDeveloper Switch ON%s\n" "$YELLOW" "$devsw" "$NC" "$GREEN" "$NC"
    else
        printf "devsw_cur: %s%s%s → %sDeveloper Switch OFF%s\n" "$YELLOW" "$devsw" "$NC" "$RED" "$NC"
    fi

    if [ "$dev_usb" = "1" ]; then
        printf "dev_boot_usb: %s%s%s → %sUSB boot allowed%s\n" "$YELLOW" "$dev_usb" "$NC" "$GREEN" "$NC"
    else
        if [ "$gbb_dev_usb" = "1" ]; then
            printf "dev_boot_usb: %s%s%s → %sUSB boot allowed (GBB SET: %s)%s\n" "$YELLOW" "$dev_usb" "$NC" "$GREEN" "$gbb_flags" "$NC"
        else
            printf "dev_boot_usb: %s%s%s → %sUSB boot disabled%s\n" "$YELLOW" "$dev_usb" "$NC" "$RED" "$NC"
        fi
    fi

    if [ "$dev_signed" = "1" ]; then
        printf "dev_boot_signed_only: %s%s%s → %sBoot signed-only enforced%s\n" "$YELLOW" "$dev_signed" "$NC" "$RED" "$NC"
    else
        printf "dev_boot_signed_only: %s%s%s → %sUnsigned boot allowed%s\n" "$YELLOW" "$dev_signed" "$NC" "$GREEN" "$NC"
    fi

    # ---------- GSC ----------
    printf "\n%s----- GSC / Ti50 Status -----%s\n" "$GREEN" "$NC"

    if command -v gsctool >/dev/null 2>&1; then
        flash_wp=$(gsctool -a -w 2>/dev/null | grep -i "Flash WP" | awk '{print $3}')
        if [ "$flash_wp" = "enabled" ]; then
            printf "Flash WP: %sEnabled%s\n" "$RED" "$NC"
        else
            printf "Flash WP: %sDisabled%s\n" "$GREEN" "$NC"
        fi
    else
        printf "%sFlash WP status unavailable (gsctool missing)%s\n" "$RED" "$NC"
    fi

    # ---------- CCD ----------
    printf "\n%s----- CCD Information -----%s\n" "$GREEN" "$NC"

    if command -v gsctool >/dev/null 2>&1; then
        GSC_I=$(gsctool -a -I 2>/dev/null)
        GSC_W=$(gsctool -a -W 2>/dev/null)

        ccd_mode=$(echo "$GSC_W" | grep -i ccd_mode | tr -dc '0-9')

        case "$ccd_mode" in
            0) printf "CCD Mode: %sLocked%s\n" "$RED" "$NC" ;;
            1) printf "CCD Mode: %sOpened%s\n" "$GREEN" "$NC" ;;
            2) printf "CCD Mode: %sDebug%s\n" "$BLUE" "$NC" ;;
            *) printf "CCD Mode: %sUnknown%s\n" "$YELLOW" "$NC" ;;
        esac
    else
        printf "%sCCD unavailable (gsctool missing)%s\n" "$RED" "$NC"
    fi

    # ---------- SPI ----------
    printf "\n%s----- SPI Flash Status -----%s\n" "$GREEN" "$NC"

    if command -v flashrom >/dev/null 2>&1; then
        flashrom --wp-status 2>/dev/null
    else
        printf "%sflashrom not installed%s\n" "$RED" "$NC"
    fi

    # ---------- KERNEL ----------
    printf "\n%s----- Kernel Messages -----%s\n" "$GREEN" "$NC"
    dmesg | grep -iE "write-protect|wp:|WP:|HWP" | tail -n 10

    # ---------- SPI READ TEST ----------
    printf "\n%s----- Firmware Read Test -----%s\n" "$GREEN" "$NC"

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
