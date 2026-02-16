# Rockit Compiler — Makefile
# Dark Matter Tech

PREFIX ?= /usr/local
RUNTIME_DIR = Runtime

.PHONY: build release install uninstall test clean docker

build:
	swift build

release:
	swift build -c release

test:
	swift test

install: release
	@echo "Installing rockit to $(PREFIX)/bin..."
	@mkdir -p $(PREFIX)/bin
	@cp .build/release/rockit $(PREFIX)/bin/rockit
	@mkdir -p $(PREFIX)/lib/rockit/runtime
	@cp $(RUNTIME_DIR)/rockit_runtime.c $(PREFIX)/lib/rockit/runtime/
	@cp $(RUNTIME_DIR)/rockit_runtime.h $(PREFIX)/lib/rockit/runtime/
	@echo "Installed: $(PREFIX)/bin/rockit"
	@echo "Runtime:   $(PREFIX)/lib/rockit/runtime/"
	@echo ""
	@echo "Usage: rockit run myfile.rok"

uninstall:
	@rm -f $(PREFIX)/bin/rockit
	@rm -rf $(PREFIX)/lib/rockit
	@echo "Uninstalled rockit"

docker:
	docker build -t rockit .
	@echo ""
	@echo "Run:    docker run --rm rockit run /usr/local/lib/rockit/examples/hello.rok"
	@echo "REPL:   docker run --rm -it rockit repl"
	@echo "Mount:  docker run --rm -v \$$(pwd):/code rockit run /code/main.rok"

clean:
	swift package clean
