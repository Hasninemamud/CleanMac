BIN_DIR := bin
GO ?= go
LDFLAGS := -s -w
BINARY := $(BIN_DIR)/cleanmac
APP_DIR := macos
APP_NAME := CleanMac

.PHONY: all build test selfcheck install app package clean

all: build

build:
	@mkdir -p $(BIN_DIR)
	$(GO) build -ldflags="$(LDFLAGS)" -o $(BINARY) ./cmd/cleanmac

test:
	$(GO) test ./internal/...

selfcheck: build
	@bash scripts/selfcheck.sh

install: build
	@bash scripts/install.sh

app: build
	@bash scripts/build-app.sh

package: app
	@bash scripts/package.sh

clean:
	rm -f $(BINARY)
	rm -rf $(APP_DIR)/.build $(APP_DIR)/$(APP_NAME).app dist
