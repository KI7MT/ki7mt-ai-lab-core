#!/bin/bash
# ==============================================================================
# Script Name: autogen.sh
# Purpose:     Bootstrap Autotools for ki7mt-ai-lab-core (printf Edition)
# Copyright:   Copyright (C) 2014-2026, Greg Beam, KI7MT
# ==============================================================================
set -e

BASED=$(pwd)
PROGRAM="ki7mt-ai-lab-core"

# Foreground colors with explicit reset sequences
# \033[0m ensures we start with no previous attributes
C_R='\033[0;31m'    # Red
C_G='\033[0;32m'    # Green
C_Y='\033[0;33m'    # Yellow
C_NC='\033[0m'      # Reset / No Color

# ------------------------------------------------------------------------------
# Dependency Check Function
# ------------------------------------------------------------------------------
check_dep() {
    if ! command -v "$1" >/dev/null 2>&1; then
        # Use %b for the color variable and %s for the message
        printf "%bDEPENDENCY ERROR:%b %s\n" "${C_R}" "${C_NC}" "$1 is not installed."
        [ -n "$2" ] && printf "Hint: %s\n" "$2"
        exit 1
    fi
}

# 1. Check for Standard Build Tools
check_dep "lsb_release" "sudo apt-get install lsb-release (Debian) or yum install redhat-lsb (Fedora)"
check_dep "autoconf"    "sudo apt-get install autoconf"
check_dep "automake"    "sudo apt-get install automake"
check_dep "libtoolize"  "sudo apt-get install libtool"

# 2. Lab Foundation Check (ClickHouse)
check_dep "clickhouse-client" "Install via: sudo apt-get install clickhouse-common-static"

# ------------------------------------------------------------------------------
# Bootstrap Process
# ------------------------------------------------------------------------------
printf "%bBootstrapping %s build system...%b\n" "${C_Y}" "$PROGRAM" "${C_NC}"

# Clean up old artifacts if they exist
if [ -f "./Makefile" ] && [ -f "./configure" ]; then
    printf "\n"
    printf "* Found old build files, running make clean...\n"
    printf "\n"
    make -s clean || true
fi

# Run autoreconf
printf "%bRunning autoreconf --install --force...%b\n" "${C_G}" "${C_NC}"
autoreconf --install --force --verbose

# ------------------------------------------------------------------------------
# Final Configuration
# ------------------------------------------------------------------------------
if [ -s "./configure" ]; then
    printf "%b* Successfully generated configure script.%b\n" "${C_G}" "${C_NC}"
    printf "\n"
    printf "Running configure with defaults: ./configure %s\n\n" "$*"
    ./configure "$@"
else
    prinf "\n"
    printf "%bERROR:%b Configure script generation failed.\n" "${C_R}" "${C_NC}"
    prinf "\n"
    exit 1
fi

exit 0