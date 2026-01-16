#!/bin/bash
# ==============================================================================
# Name..........: autogen.sh
# Project.......: ki7mt-ai-lab-core
# Version.......: 1.0.0
# Purpose.......: Bootstrap Autotools for KI7MT AI Lab Core
# Target OS.....: Rocky Linux 9.x / RHEL 9.x (el9)
# Author........: Greg Beam, KI7MT
# ==============================================================================
set -e

PROGRAM="ki7mt-ai-lab-core"

# ANSI Color Codes
C_R='\033[0;31m'    # Red
C_G='\033[0;32m'    # Green
C_Y='\033[0;33m'    # Yellow
C_B='\033[0;34m'    # Blue
C_NC='\033[0m'      # Reset

# ------------------------------------------------------------------------------
# Dependency Check Function
# ------------------------------------------------------------------------------
check_dep() {
    if ! command -v "$1" >/dev/null 2>&1; then
        printf "%b[ERROR]%b %s is not installed.\n" "${C_R}" "${C_NC}" "$1"
        [ -n "$2" ] && printf "  Hint: %s\n" "$2"
        exit 1
    fi
}

# ------------------------------------------------------------------------------
# Check Build Dependencies
# ------------------------------------------------------------------------------
printf "%b[CHECK]%b Verifying build dependencies...\n" "${C_B}" "${C_NC}"

check_dep "autoconf"        "dnf install autoconf"
check_dep "automake"        "dnf install automake"
check_dep "clickhouse-client" "dnf install clickhouse-common-static"

printf "%b[OK]%b All dependencies satisfied.\n" "${C_G}" "${C_NC}"

# ------------------------------------------------------------------------------
# Bootstrap Process
# ------------------------------------------------------------------------------
printf "\n%b[BOOTSTRAP]%b Initializing %s build system...\n" "${C_Y}" "${C_NC}" "$PROGRAM"

# Create build-aux directory for Autotools helper scripts
mkdir -p build-aux

# Clean up old artifacts if they exist
if [ -f "./Makefile" ] && [ -f "./configure" ]; then
    printf "%b[CLEAN]%b Removing old build files...\n" "${C_B}" "${C_NC}"
    make -s clean 2>/dev/null || true
    make -s distclean 2>/dev/null || true
fi

# Run autoreconf
printf "%b[AUTORECONF]%b Generating configure script...\n" "${C_B}" "${C_NC}"
autoreconf --install --force

# ------------------------------------------------------------------------------
# Run Configure
# ------------------------------------------------------------------------------
if [ -s "./configure" ]; then
    printf "%b[OK]%b Configure script generated successfully.\n" "${C_G}" "${C_NC}"
    printf "\n%b[CONFIGURE]%b Running ./configure %s\n\n" "${C_B}" "${C_NC}" "$*"
    ./configure "$@"
else
    printf "\n%b[ERROR]%b Configure script generation failed.\n" "${C_R}" "${C_NC}"
    exit 1
fi

exit 0
