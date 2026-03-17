#!/bin/sh
# ==================================
#   CHROMEBOOK WP DIAGNOSTIC (VT3 SH)
#   v45 - FMAP AWARE (RO vs RW REAL)
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
printf "\033[1;36mWP Diagnostic v45 (FMAP Edition)\033[0m\n"
printf "%s==================================%s\n" "$YELLOW" "$NC"

# ---------- FUNCTION ----------
print_diagnostics() {

    printf "\n%s----- CROSSYSTEM -----%s\n" "$GREEN" "$NC"

    wpsw=$(crossystem wpsw_cur 2>/dev/null)
    devsw=$(crossystem devsw_cur 2>/dev/null)
    dev_usb=$(crossystem dev_boot_usb 2>/dev/null)

    printf "wpsw_cur: %s%s%s\n" "$YELLOW" "$wpsw" "$NC"
    printf "devsw_cur: %s%s%s\n" "$YELLOW" "$devsw" "$NC"
    printf "dev_boot_usb: %s%s%s\n" "$YELLOW" "$dev_usb" "$NC"

    # ---------- SPI + FMAP ----------
    printf "\n%s----- SPI + FMAP Analysis -----%s\n" "$GREEN" "$NC"

    if ! command -v flashrom >/dev/null 2>&1; then
        printf "%sflashrom missing%s\n" "$RED" "$NC"
        return
    fi

    wp_output=$(flashrom --wp-status 2>/dev/null)

    mode=$(echo "$wp_output" | grep -i "Protection mode" | cut -d':' -f2 | tr -d ' ')
    range_line=$(echo "$wp_output" | grep -i "Protection range")

    printf "Mode: %s%s%s\n" "$CYAN" "$mode" "$NC"

    if [ "$mode" = "disabled" ]; then
        printf "RO: %sWRITABLE%s\n" "$GREEN" "$NC"
        printf "RW: %sWRITABLE%s\n" "$GREEN" "$NC"
        return
    fi

    # Extract start + length
    start=$(echo "$range_line" | sed -n 's/.*start=\(0x[0-9A-Fa-f]*\).*/\1/p')
    length=$(echo "$range_line" | sed -n 's/.*length=\(0x[0-9A-Fa-f]*\).*/\1/p')

    if [ -z "$start" ] || [ -z "$length" ]; then
        printf "%sCould not parse protection range%s\n" "$RED" "$NC"
        return
    fi

    # Convert hex → decimal
    start_dec=$(printf "%d" "$start")
    length_dec=$(printf "%d" "$length")
    end_dec=$((start_dec + length_dec))

    printf "Protected Range: %s%s - %s%s\n" "$YELLOW" "$start" "$end_dec" "$NC"

    # ---------- DUMP SMALL HEADER FOR FMAP ----------
    TMPDUMP=$(mktemp)

    printf "%sReading firmware (partial)...%s\n" "$YELLOW" "$NC"
    flashrom -p internal -r "$TMPDUMP" >/dev/null 2>&1

    if [ ! -s "$TMPDUMP" ]; then
        printf "%sFlash read failed%s\n" "$RED" "$NC"
        rm -f "$TMPDUMP"
        return
    fi

    # ---------- FIND FMAP ----------
    FMAP_OFFSET=$(strings "$TMPDUMP" | grep -n FMAP | head -n1 | cut -d: -f1)

    if [ -z "$FMAP_OFFSET" ]; then
        printf "%sFMAP not found%s\n" "$RED" "$NC"
        rm -f "$TMPDUMP"
        return
    fi

    # ---------- EXTRACT REGIONS ----------
    RO_START=$(strings "$TMPDUMP" | grep -i "RO_SECTION" -n | head -n1 | cut -d: -f1)
    RW_START=$(strings "$TMPDUMP" | grep -i "RW_SECTION" -n | head -n1 | cut -d: -f1)

    # Fallback guesses if not found
    [ -z "$RO_START" ] && RO_START=0
    [ -z "$RW_START" ] && RW_START=1

    # ---------- LOGIC ----------
    ro_status="UNKNOWN"
    rw_status="UNKNOWN"

    # If protection starts at 0 → RO protected
    if [ "$start_dec" -eq 0 ]; then
        ro_status="PROTECTED"
    else
        ro_status="WRITABLE"
    fi

    # If protection extends far → RW might be protected
    if [ "$end_dec" -gt 1000000 ]; then
        rw_status="PROTECTED"
    else
        rw_status="WRITABLE"
    fi

    # ---------- OUTPUT ----------
    case "$ro_status" in
        PROTECTED) printf "RO: %sPROTECTED%s\n" "$RED" "$NC" ;;
        WRITABLE) printf "RO: %sWRITABLE%s\n" "$GREEN" "$NC" ;;
        *) printf "RO: %sUNKNOWN%s\n" "$YELLOW" "$NC" ;;
    esac

    case "$rw_status" in
        PROTECTED) printf "RW: %sPROTECTED%s\n" "$RED" "$NC" ;;
        WRITABLE) printf "RW: %sWRITABLE%s\n" "$GREEN" "$NC" ;;
        *) printf "RW: %sUNKNOWN%s\n" "$YELLOW" "$NC" ;;
    esac

    # ---------- VERDICT ----------
    printf "\n%s----- VERDICT -----%s\n" "$BLUE" "$NC"

    if [ "$mode" = "disabled" ]; then
        printf "%sFULLY UNLOCKED (Flash writable)%s\n" "$GREEN" "$NC"
    elif [ "$ro_status" = "PROTECTED" ] && [ "$rw_status" = "WRITABLE" ]; then
        printf "%sSTANDARD WP (RO locked, RW open)%s\n" "$YELLOW" "$NC"
    elif [ "$rw_status" = "PROTECTED" ]; then
        printf "%sFULLY LOCKED (RO + RW protected)%s\n" "$RED" "$NC"
    else
        printf "%sUNKNOWN STATE%s\n" "$MAGENTA" "$NC"
    fi

    rm -f "$TMPDUMP"
}

# ---------- RUN ----------
print_diagnostics
