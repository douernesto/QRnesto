APP_NAME := QRnesto
APP      := build/$(APP_NAME).app
BIN_NAME := QRnesto
INSTALL_DIR ?= /Applications

.PHONY: help check build debug app universal run ios-sim ios-device ios-open ios-help install uninstall quit logs crash-report clean

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-14s %s\n", $$1, $$2}'

check: ## Check that this Mac can build the app
	scripts/check_env.sh

build: ## Compile the release binary
	swift build -c release

debug: ## Compile the debug binary
	swift build

app: ## Build the signed .app bundle for this Mac into ./build
	scripts/build_app.sh

universal: ## Build a universal (Apple Silicon + Intel) .app into ./build
	UNIVERSAL=1 scripts/build_app.sh

run: quit app ## Rebuild, stop any running copy, and launch the app
	open "$(APP)"

ios-sim: ## Build the iOS app and launch it in the iOS Simulator (SIM="iPhone 17")
	scripts/run_ios_sim.sh

ios-device: ## Build, install and launch the iOS app on a connected iPhone (see make ios-help)
	scripts/run_ios_device.sh

ios-open: ## Open the iOS project in Xcode
	open iOS/QRnesto.xcodeproj

ios-help: ## Show how to run the iOS app on your iPhone with a free Apple ID
	@echo "Run QRnesto on your iPhone (free Apple ID, no paid developer account):"
	@echo ""
	@echo "One-time setup"
	@echo "  1. Xcode > Settings > Accounts: click +, choose Apple ID and sign in."
	@echo "  2. Connect the iPhone with a cable, unlock it and tap Trust This Computer."
	@echo "  3. iPhone: Settings > Privacy & Security > Developer Mode on, then restart."
	@echo "     (The option appears after the phone has been connected to Xcode once.)"
	@echo ""
	@echo "Run"
	@echo "  make ios-device            build, install and launch on the connected iPhone"
	@echo "  First launch only: iPhone Settings > General > VPN & Device Management,"
	@echo "  tap your Apple ID and choose Trust, then run make ios-device again."
	@echo ""
	@echo "Options"
	@echo "  TEAM=ABCDE12345            team ID (default: read from your Apple Development certificate)"
	@echo "  DEVICE=<name or UDID>      pick a device when several are connected"
	@echo "  BUNDLE_ID=com.you.qrnesto  use if Xcode says the bundle ID is unavailable"
	@echo ""
	@echo "Free accounts: the app stops opening after 7 days; run make ios-device again."
	@echo "Simulator (no camera): make ios-sim"

install: app ## Copy the app to INSTALL_DIR (default /Applications)
	rm -rf "$(INSTALL_DIR)/$(APP_NAME).app"
	cp -R "$(APP)" "$(INSTALL_DIR)/"

uninstall: quit ## Remove the app from INSTALL_DIR
	rm -rf "$(INSTALL_DIR)/$(APP_NAME).app"

quit: ## Stop any running copy of the app
	-@pkill -f "$(APP_NAME).app/Contents/MacOS/$(BIN_NAME)"; true

logs: ## Stream the app's log output
	log stream --style compact --predicate 'process == "$(BIN_NAME)"'

crash-report: ## Print the latest crash report's exception and stack
	@f=$$(ls -t ~/Library/Logs/DiagnosticReports/$(BIN_NAME)-*.ips 2>/dev/null | head -1); \
	if [ -z "$$f" ]; then echo "No crash reports found."; exit 0; fi; \
	echo "$$f"; \
	python3 -c 'import json,sys; r=json.loads(open(sys.argv[1]).read().split("\n",1)[1]); print(r.get("exception"), r.get("asi")); t=[x for x in r["threads"] if x.get("triggered")][0]; [print(r["usedImages"][f["imageIndex"]].get("name"), f.get("symbol")) for f in t["frames"][:15]]' "$$f"

clean: ## Remove build artifacts
	swift package clean
	rm -rf .build build
