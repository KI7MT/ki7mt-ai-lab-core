# Makefile for ki7mt-ai-lab-core
#
# Local development only - does not affect COPR/rpkg builds
#
# Usage:
#   make              # Show help
#   make build        # Process templates into build/
#   make install      # Install to system (requires sudo)
#   make test         # Run verification tests
#   make distclean    # Remove all build artifacts

SHELL := /bin/bash
.PHONY: help build install uninstall test distclean

# Package metadata
NAME     := ki7mt-ai-lab-core
VERSION  := $(shell cat VERSION 2>/dev/null || echo "0.0.0")
PREFIX   := /usr
BINDIR   := $(PREFIX)/bin
DATADIR  := $(PREFIX)/share/$(NAME)/ddl

# Build directory
BUILDDIR := build

# Source files
SCRIPTS  := src/ki7mt-lab-db-init src/ki7mt-lab-env
SCHEMAS  := $(wildcard src/*.sql)

# Default target
.DEFAULT_GOAL := help

help:
	@printf "\n"
	@printf "Package : $(NAME)\n"
	@printf "Version : $(VERSION)\n"
	@printf "\n"
	@printf "Usage: make [target]\n"
	@printf "\n"
	@printf "Targets:\n"
	@printf "  help       Show this help message\n"
	@printf "  build      Process templates into build/ directory\n"
	@printf "  install    Install to system (PREFIX=$(PREFIX), requires sudo)\n"
	@printf "  uninstall  Remove installed files (requires sudo)\n"
	@printf "  test       Run verification tests (requires ClickHouse)\n"
	@printf "  distclean  Remove all build artifacts\n"
	@printf "\n"
	@printf "Variables:\n"
	@printf "  PREFIX     Installation prefix (default: /usr)\n"
	@printf "  DESTDIR    Staging directory for packaging\n"
	@printf "\n"
	@printf "Examples:\n"
	@printf "  make build                    # Build templates\n"
	@printf "  sudo make install             # Install to /usr\n"
	@printf "  make PREFIX=/usr/local install # Install to /usr/local\n"
	@printf "  DESTDIR=/tmp/stage make install # Stage for packaging\n"

build: $(BUILDDIR)/.built

$(BUILDDIR)/.built: $(SCRIPTS) $(SCHEMAS) VERSION
	@printf "Building $(NAME) v$(VERSION)...\n"
	@mkdir -p $(BUILDDIR)/bin $(BUILDDIR)/ddl
	@# Process scripts
	@for script in $(SCRIPTS); do \
		name=$$(basename $$script); \
		sed -e 's|@PROGRAM@|$(NAME)|g' \
		    -e 's|@VERSION@|$(VERSION)|g' \
		    $$script > $(BUILDDIR)/bin/$$name; \
		chmod 755 $(BUILDDIR)/bin/$$name; \
		printf "  %-30s -> build/bin/%s\n" "$$script" "$$name"; \
	done
	@# Process SQL schemas
	@for sql in $(SCHEMAS); do \
		name=$$(basename $$sql); \
		sed -e 's|@PROGRAM@|$(NAME)|g' \
		    -e 's|@VERSION@|$(VERSION)|g' \
		    -e 's|@COPYRIGHT@|GPL-3.0-or-later|g' \
		    $$sql > $(BUILDDIR)/ddl/$$name; \
		printf "  %-30s -> build/ddl/%s\n" "$$sql" "$$name"; \
	done
	@touch $(BUILDDIR)/.built
	@printf "Build complete.\n"

install: build
	@printf "Installing to $(DESTDIR)$(PREFIX)...\n"
	install -d $(DESTDIR)$(BINDIR)
	install -d $(DESTDIR)$(DATADIR)
	install -m 755 $(BUILDDIR)/bin/* $(DESTDIR)$(BINDIR)/
	install -m 644 $(BUILDDIR)/ddl/*.sql $(DESTDIR)$(DATADIR)/
	@printf "Installed:\n"
	@printf "  Scripts: $(DESTDIR)$(BINDIR)/ki7mt-lab-*\n"
	@printf "  Schemas: $(DESTDIR)$(DATADIR)/*.sql\n"

uninstall:
	@printf "Uninstalling from $(DESTDIR)$(PREFIX)...\n"
	rm -f $(DESTDIR)$(BINDIR)/ki7mt-lab-db-init
	rm -f $(DESTDIR)$(BINDIR)/ki7mt-lab-env
	rm -rf $(DESTDIR)$(PREFIX)/share/$(NAME)
	@printf "Uninstall complete.\n"

test: build
	@printf "Running tests for $(NAME) v$(VERSION)...\n"
	@printf "\n"
	@# Test 1: Check build outputs exist
	@printf "[TEST] Build outputs exist... "
	@test -f $(BUILDDIR)/bin/ki7mt-lab-db-init && \
	 test -f $(BUILDDIR)/bin/ki7mt-lab-env && \
	 test -f $(BUILDDIR)/ddl/01-wspr_schema.sql && \
	 printf "PASS\n" || { printf "FAIL\n"; exit 1; }
	@# Test 2: Check version substitution
	@printf "[TEST] Version substitution... "
	@grep -q 'VERSION="$(VERSION)"' $(BUILDDIR)/bin/ki7mt-lab-db-init && \
	 printf "PASS\n" || { printf "FAIL\n"; exit 1; }
	@# Test 3: Check program name substitution
	@printf "[TEST] Program name substitution... "
	@grep -q 'PROGRAM="$(NAME)"' $(BUILDDIR)/bin/ki7mt-lab-db-init && \
	 printf "PASS\n" || { printf "FAIL\n"; exit 1; }
	@# Test 4: Check DDL path substitution
	@printf "[TEST] DDL path in scripts... "
	@grep -q '/usr/share/$(NAME)/ddl' $(BUILDDIR)/bin/ki7mt-lab-db-init && \
	 printf "PASS\n" || { printf "FAIL\n"; exit 1; }
	@# Test 5: Check scripts are executable
	@printf "[TEST] Scripts are executable... "
	@test -x $(BUILDDIR)/bin/ki7mt-lab-db-init && \
	 test -x $(BUILDDIR)/bin/ki7mt-lab-env && \
	 printf "PASS\n" || { printf "FAIL\n"; exit 1; }
	@# Test 6: Check SQL files have no unsubstituted placeholders
	@printf "[TEST] No unsubstituted placeholders in SQL... "
	@! grep -q '@[A-Z_]*@' $(BUILDDIR)/ddl/*.sql && \
	 printf "PASS\n" || { printf "FAIL\n"; exit 1; }
	@# Test 7: Syntax check scripts (bash -n)
	@printf "[TEST] Script syntax valid... "
	@bash -n $(BUILDDIR)/bin/ki7mt-lab-db-init && \
	 bash -n $(BUILDDIR)/bin/ki7mt-lab-env && \
	 printf "PASS\n" || { printf "FAIL\n"; exit 1; }
	@printf "\nAll tests passed.\n"

distclean:
	@printf "Cleaning build artifacts...\n"
	rm -rf $(BUILDDIR)
	@printf "Clean complete.\n"
