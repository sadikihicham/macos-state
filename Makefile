APP   = MacOSState
EXEC  = MacOSStateApp
BUILD = .build
APPDIR = $(BUILD)/$(APP).app
AGENT_PLIST = $(HOME)/Library/LaunchAgents/com.hicham.macosstate.plist

.PHONY: build release run test check-net verify hooks bundle install-agent uninstall-agent clean

build:
	swift build

release:
	swift build -c release

## Lance l'app directement (dev) — HUD visible sur le bureau.
run: build
	swift run $(EXEC)

## Tests unitaires de la lib pure SystemMetrics.
test:
	swift test

## Fitness function : prouve l'absence de toute capacité réseau dans le binaire.
check-net: release
	@bash scripts/check-no-network.sh "$(BUILD)/release/$(EXEC)"

## Porte complète : build + tests + invariant zéro-réseau.
verify: test check-net
	@echo "==> verify OK (tests verts + zéro réseau)"

## Active les git hooks versionnés (.githooks) : test au commit, check-net au push.
## À lancer une fois après un clone.
hooks:
	@chmod +x .githooks/*
	@git config core.hooksPath .githooks
	@echo "==> hooks actifs (core.hooksPath=.githooks) : pre-commit=make test, pre-push=make check-net"

## Assemble un .app signé ad-hoc à partir du binaire release.
bundle: release
	rm -rf "$(APPDIR)"
	mkdir -p "$(APPDIR)/Contents/MacOS"
	cp "$(BUILD)/release/$(EXEC)" "$(APPDIR)/Contents/MacOS/$(EXEC)"
	cp bundle/Info.plist "$(APPDIR)/Contents/Info.plist"
	codesign --force --sign - "$(APPDIR)"
	@echo "==> $(APPDIR)"

## Installe un LaunchAgent qui démarre l'app au login (usage perso).
install-agent: bundle
	@mkdir -p "$(HOME)/Library/LaunchAgents"
	@printf '%s\n' \
	  '<?xml version="1.0" encoding="UTF-8"?>' \
	  '<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">' \
	  '<plist version="1.0"><dict>' \
	  '  <key>Label</key><string>com.hicham.macosstate</string>' \
	  "  <key>ProgramArguments</key><array><string>$(CURDIR)/$(APPDIR)/Contents/MacOS/$(EXEC)</string></array>" \
	  '  <key>RunAtLoad</key><true/>' \
	  '</dict></plist>' > "$(AGENT_PLIST)"
	@echo "==> LaunchAgent installé : $(AGENT_PLIST) (charge: launchctl load $(AGENT_PLIST))"

uninstall-agent:
	-launchctl unload "$(AGENT_PLIST)" 2>/dev/null || true
	rm -f "$(AGENT_PLIST)"

clean:
	swift package clean
	rm -rf "$(APPDIR)"
