#!/bin/sh
# ============================================
#   CHROMEBOOK WP DIAGNOSTIC (VT3 SH)
#   Version 51 - Corrected USB Boot + Spinner
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

clear
printf "\n%sChromebook WP Diagnostic v51 (VT3) by CriticalHD/neonnebula%s\n" "$CYAN" "$NC"
printf "%s=========================================%s\n" "$YELLOW" "$NC"

print_diagnostics() {
    printf "\n%s----- CROSSYSTEM (Firmware / DevMode info) -----\n%s" "$GREEN" "$NC"

    wpsw=$(crossystem wpsw_cur 2>/dev/null || echo 0)
    devsw=$(crossystem devsw_cur 2>/dev/null || echo 0)
    dev_usb=$(crossystem dev_boot_usb 2>/dev/null || echo 0)
    dev_signed=$(crossystem dev_boot_signed_only 2>/dev/null || echo 0)
    tpm_ver=$(crossystem tpm_kernver 2>/dev/null || echo unknown)

    # ---------- GBB FLAGS ----------
    gbb_dev_usb=0
    gbb_flags="unknown"
    if command -v flashrom >/dev/null 2>&1 && command -v futility >/dev/null 2>&1; then
        TMPGBB=$(mktemp)
        flashrom -p internal -i GBB -r "$TMPGBB" >/dev/null 2>&1
        gbb_flags=$(futility gbb --get --flags "$TMPGBB" 2>/dev/null | awk '{print $2}')
        rm -f "$TMPGBB"
        [ "$gbb_flags" != "0x0" ] && gbb_dev_usb=$((0x10 & $(printf "%d" "$gbb_flags")))
    fi

    # ---------- CROSSYSTEM OUTPUT ----------
    [ "$wpsw" -eq 1 ] && wpsw_status="${RED}WP ENABLED${NC}" || wpsw_status="${GREEN}WP DISABLED${NC}"
    [ "$devsw" -eq 1 ] && devsw_status="${GREEN}ENABLED${NC}" || devsw_status="${RED}DISABLED${NC}"
    if [ "$dev_usb" -eq 1 ] || [ "$gbb_dev_usb" -ne 0 ]; then
        dev_usb_status="${GREEN}ENABLED (GBB / Firmware)${NC}"
    else
        dev_usb_status="${RED}DISABLED${NC}"
    fi
    [ "$dev_signed" -eq 1 ] && dev_signed_status="${RED}SIGNED ONLY ENFORCED${NC}" || dev_signed_status="${GREEN}UNSIGNED ALLOWED${NC}"

    printf "%swpsw_cur = %s → %s\n" "$YELLOW" "$wpsw" "$wpsw_status"
    printf "%sdevsw_cur = %s → %s\n" "$YELLOW" "$devsw" "$devsw_status"
    printf "%sdev_boot_usb = %s → %s\n" "$YELLOW" "$dev_usb" "$dev_usb_status"
    printf "%sdev_boot_signed_only = %s → %s\n" "$YELLOW" "$dev_signed" "$dev_signed_status"
    printf "%stpm_kernver = %s\n" "$YELLOW" "$tpm_ver"

    # ---------- GBB FLAGS ----------
    printf "\n%s----- GBB FLAGS -----\n%s" "$GREEN" "$NC"
    printf "%sGBB Flags = %s\n" "$YELLOW" "$gbb_flags"
    [ "$gbb_dev_usb" -ne 0 ] && printf "%sGBB Dev USB = ENABLED (forced by firmware)\n" "$GREEN" || printf "%sGBB Dev USB = DISABLED\n" "$RED"

    # ---------- CCD / GSC ----------
    printf "\n%s----- GSC / CCD Status -----\n%s" "$GREEN" "$NC"
    GSC_I=$(gsctool -a -I 2>/dev/null)
    GSC_W=$(gsctool -a -W 2>/dev/null)
    ccd_mode=$(echo "$GSC_W" | grep -i ccd_mode | tr -dc '0-9')
    case "$ccd_mode" in
        0) printf "CCD Mode: %sLocked / Closed%s\n" "$RED" "$NC" ;;
        1) printf "CCD Mode: %sOpened%s\n" "$GREEN" "$NC" ;;
        2) printf "CCD Mode: %sDebug%s\n" "$BLUE" "$NC" ;;
        *) printf "CCD Mode: %sUnknown%s\n" "$YELLOW" "$NC" ;;
    esac

    ccd_state=$(echo "$GSC_I" | grep -i "^State" | awk '{print $2}')
    case "$ccd_state" in
        Locked) printf "CCD State: %sLocked%s\n" "$RED" "$NC" ;;
        Opened|Open|Unlocked) printf "CCD State: %sOpened%s\n" "$GREEN" "$NC" ;;
        Debug) printf "CCD State: %sDebug%s\n" "$BLUE" "$NC" ;;
        *) printf "CCD State: %sUnknown%s\n" "$YELLOW" "$NC" ;;
    esac

    get_cap() {
        cap="$1"
        line=$(echo "$GSC_I" | grep -i "$cap")
        line=$(echo "$line" | sed 's/^[YNyn] *//')
        state=$(echo "$line" | grep -oE 'Never|IfOpened|Always|0|1|2' | head -n1)
        case "$state" in
            Never|0) out="${RED}Never${NC}" ;;
            IfOpened|1) out="${BLUE}IfOpened${NC}" ;;
            Always|2) out="${GREEN}Always${NC}" ;;
            *) out="${YELLOW}Unknown${NC}" ;;
        esac
        printf "%-20s %b\n" "$cap:" "$out"
    }
    get_cap AllowUnverifiedRo
    get_cap OverrideWP
    get_cap FlashAP
    get_cap FlashRead
    get_cap GscFullConsole

    # ---------- SPI FLASH ----------
    printf "\n%s----- SPI FLASH Status -----\n%s" "$GREEN" "$NC"
    if command -v flashrom >/dev/null 2>&1; then
        flash_output=$(flashrom --wp-status 2>/dev/null)
        mode=$(echo "$flash_output" | grep -i "Protection mode" | cut -d':' -f2 | tr -d ' ')
        range=$(echo "$flash_output" | grep -i "Protection range" | cut -d':' -f2 | tr -d ' ')
        printf "Protection Mode: %s%s%s\n" "$CYAN" "$mode" "$NC"
        printf "Protection Range: %s%s%s\n" "$CYAN" "$range" "$NC"
    else
        printf "%sflashrom not installed%s\n" "$RED" "$NC"
    fi

    # ---------- KERNEL ----------
    printf "\n%s----- Kernel Messages -----\n%s" "$GREEN" "$NC"
    kernel_msgs=$(dmesg 2>/dev/null | grep -iE "write-protect|wp:|WP:|HWP|flash" | tail -n 10)
    [ -n "$kernel_msgs" ] && printf "%s%s%s\n" "$CYAN" "$kernel_msgs" "$NC" || printf "%sNo relevant kernel messages%s\n" "$RED" "$NC"

    # ---------- FIRMWARE READ TEST ----------
    printf "\n%s----- Firmware Read Test (SPI Only) -----\n%s" "$GREEN" "$NC"
    printf "%sThis may take a while...%s\n" "$YELLOW" "$NC"

    TMPFILE=$(mktemp)
    flashrom -p internal -r "$TMPFILE" >/dev/null 2>&1 &
    FR_PID=$!
    spinner="/-\|"
    i=0
    tput civis 2>/dev/null || true
    while kill -0 $FR_PID 2>/dev/null; do
        i=$(( (i+1) % 4 ))
        char=$(echo "$spinner" | cut -c$((i+1)))
        printf "\r\033[1;33mReading SPI flash... %s\033[0m" "$char"
        sleep 0.2
    done
    wait $FR_PID
    FR_STATUS=$?
    tput cnorm 2>/dev/null || true
    echo -ne "\r\033[K"
    if [ $FR_STATUS -eq 0 ]; then
        printf "%sFlash read SUCCESS (SPI access works)%s\n" "$GREEN" "$NC"
    else
        printf "%sFlash read FAILED%s\n" "$RED" "$NC"
    fi
    rm -f "$TMPFILE"
}

print_diagnostics
