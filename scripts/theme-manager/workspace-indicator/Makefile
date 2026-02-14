# workspace-indicator — build & install
#
# Usage:
#   make                    Build the binary
#   make install            Install to ~/.local/bin/
#   make clean              Remove build artifacts
#   make uninstall          Remove installed binary

CC        ?= gcc
CFLAGS    ?= -Wall -Wextra -O2
PKG_DEPS   = gtk+-3.0 gtk-layer-shell-0

CFLAGS    += $(shell pkg-config --cflags $(PKG_DEPS))
LDFLAGS   += $(shell pkg-config --libs   $(PKG_DEPS)) -pthread

PREFIX    ?= $(HOME)/.local
BINDIR     = $(PREFIX)/bin
TARGET     = workspace-indicator

.PHONY: all clean install uninstall

all: $(TARGET)

$(TARGET): main.c
	$(CC) $(CFLAGS) -o $@ $< $(LDFLAGS)

install: $(TARGET)
	install -Dm755 $(TARGET) $(BINDIR)/$(TARGET)

uninstall:
	rm -f $(BINDIR)/$(TARGET)

clean:
	rm -f $(TARGET)
