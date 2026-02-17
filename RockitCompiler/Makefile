# Rockit Compiler — Makefile
# Dark Matter Tech

PREFIX ?= /usr/local
RUNTIME_DIR = Runtime
PLUGIN_DIR = ../ide/intellij-rockit
PLUGIN_ZIP = $(PLUGIN_DIR)/build/distributions/intellij-rockit-0.1.0.zip

.PHONY: build release install uninstall test clean docker plugin plugin-install setup-editors

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
	@mkdir -p $(PREFIX)/lib/rockit/editors/vscode
	@mkdir -p $(PREFIX)/lib/rockit/editors/vim
	@cp -r ../ide/vscode/* $(PREFIX)/lib/rockit/editors/vscode/ 2>/dev/null || true
	@cp -r ../ide/vim/* $(PREFIX)/lib/rockit/editors/vim/ 2>/dev/null || true
	@echo "Installed: $(PREFIX)/bin/rockit"
	@echo "Runtime:   $(PREFIX)/lib/rockit/runtime/"
	@echo "Editors:   $(PREFIX)/lib/rockit/editors/"
	@echo ""
	@$(PREFIX)/bin/rockit setup-editors 2>/dev/null || true
	@echo ""
	@echo "Usage: rockit run myfile.rok"

setup-editors:
	@.build/debug/rockit setup-editors 2>/dev/null || swift run rockit setup-editors

uninstall:
	@rm -f $(PREFIX)/bin/rockit
	@rm -rf $(PREFIX)/lib/rockit
	@echo "Uninstalled rockit"

docker:
	docker build -t rockit .
	@echo ""
	@echo "Run:    docker run --rm rockit run /usr/local/lib/rockit/examples/hello.rok"
	@echo "REPL:   docker run --rm -it rockit repl"
	@echo "Mount:  docker run --rm -v $$(pwd):/code rockit run /code/main.rok"

plugin:
	@echo "Building IntelliJ plugin..."
	@cd $(PLUGIN_DIR) && ./gradlew buildPlugin
	@echo ""
	@echo "Plugin built: $(PLUGIN_ZIP)"
	@echo "Install: Settings > Plugins > gear > Install Plugin from Disk > select the .zip"

plugin-install: plugin
	@echo "Installing Rockit plugin to JetBrains IDEs..."
	@INSTALLED=0; \
	for dir in "$(HOME)/Library/Application Support/JetBrains"/*/plugins; do \
		if [ -d "$$dir" ]; then \
			unzip -o -q $(PLUGIN_ZIP) -d "$$dir"; \
			echo "  Installed to $$dir/intellij-rockit/"; \
			INSTALLED=$$((INSTALLED + 1)); \
		fi; \
	done; \
	if [ "$$INSTALLED" -eq 0 ]; then \
		echo "  No JetBrains IDEs found. Install manually:"; \
		echo "  Settings > Plugins > gear > Install Plugin from Disk > $(PLUGIN_ZIP)"; \
	else \
		echo ""; \
		echo "Installed to $$INSTALLED IDE(s). Restart your IDE to activate."; \
	fi

clean:
	swift package clean
