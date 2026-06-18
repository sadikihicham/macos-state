APP   = MacOSState
EXEC  = MacOSStateApp
BUILD = .build
APPDIR = $(BUILD)/$(APP).app
AGENT_PLIST = $(HOME)/Library/LaunchAgents/com.hicham.macosstate.plist

.PHONY: build release run test check-net verify accuracy hooks bundle bundle-universal dmg notarize install-agent uninstall-agent clean

ARCHS   = --arch arm64 --arch x86_64
DMGFILE = $(BUILD)/$(APP).dmg

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

## Eval d'exactitude (sous-ensemble) : croise les samplers avec des sources
## système indépendantes (sysctl, vm_stat, df, pmset, ifconfig). Ces tests
## tournent AUSSI dans `make test` ; cette cible les isole pour diagnostic.
accuracy:
	swift test --filter AccuracyCrossSource

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
	mkdir -p "$(APPDIR)/Contents/Resources"
	cp bundle/AppIcon.icns "$(APPDIR)/Contents/Resources/AppIcon.icns"
	codesign --force --sign - "$(APPDIR)"
	@echo "==> $(APPDIR)"

## Assemble un .app UNIVERSEL (arm64 + x86_64) signé ad-hoc — pour distribuer
## sur une autre machine (Apple Silicon comme Intel).
bundle-universal:
	swift build -c release $(ARCHS)
	rm -rf "$(APPDIR)"
	mkdir -p "$(APPDIR)/Contents/MacOS"
	cp "$$(swift build -c release $(ARCHS) --show-bin-path)/$(EXEC)" "$(APPDIR)/Contents/MacOS/$(EXEC)"
	cp bundle/Info.plist "$(APPDIR)/Contents/Info.plist"
	mkdir -p "$(APPDIR)/Contents/Resources"
	cp bundle/AppIcon.icns "$(APPDIR)/Contents/Resources/AppIcon.icns"
	codesign --force --sign - "$(APPDIR)"
	@echo "==> $(APPDIR) (universel)"

## Crée un .dmg distribuable : app universelle + lien /Applications (glisser-déposer).
## NB : signé ad-hoc seulement (pas notarisé) → Gatekeeper bloquera au 1er lancement
## sur l'autre Mac ; contournement : clic droit → Ouvrir, ou
## xattr -dr com.apple.quarantine "/Applications/MacOSState.app".
dmg: bundle-universal
	rm -f "$(DMGFILE)"
	rm -rf "$(BUILD)/dmgroot"
	mkdir -p "$(BUILD)/dmgroot"
	cp -R "$(APPDIR)" "$(BUILD)/dmgroot/"
	ln -s /Applications "$(BUILD)/dmgroot/Applications"
	hdiutil create -volname "$(APP)" -srcfolder "$(BUILD)/dmgroot" -ov -format UDZO "$(DMGFILE)"
	rm -rf "$(BUILD)/dmgroot"
	@echo "==> $(DMGFILE)"

## Signe (Developer ID) + notarise + staple le DMG → s'installe SANS avertissement
## Gatekeeper sur n'importe quel Mac. Requiert un compte Apple Developer (99 $/an).
##
## Prérequis (une fois) :
##   1. Adhérer à l'Apple Developer Program → certificat "Developer ID Application".
##   2. Créer un profil notarytool :
##        xcrun notarytool store-credentials macnotary \
##          --apple-id "TON_APPLE_ID" --team-id "TEAMID" --password "MDP_APP_SPECIFIQUE"
##
## Variables d'environnement requises (jamais stockées dans le repo) :
##   DEV_ID         = "Developer ID Application: Ton Nom (TEAMID)"
##   NOTARY_PROFILE = nom du profil notarytool (ex. macnotary)
##
## Usage :  DEV_ID="Developer ID Application: ... (TEAMID)" NOTARY_PROFILE=macnotary make notarize
notarize:
	@test -n "$(DEV_ID)"         || { echo "✗ DEV_ID manquant — voir le commentaire de la cible notarize."; exit 1; }
	@test -n "$(NOTARY_PROFILE)" || { echo "✗ NOTARY_PROFILE manquant — voir le commentaire de la cible notarize."; exit 1; }
	swift build -c release $(ARCHS)
	rm -rf "$(APPDIR)"
	mkdir -p "$(APPDIR)/Contents/MacOS"
	cp "$$(swift build -c release $(ARCHS) --show-bin-path)/$(EXEC)" "$(APPDIR)/Contents/MacOS/$(EXEC)"
	cp bundle/Info.plist "$(APPDIR)/Contents/Info.plist"
	mkdir -p "$(APPDIR)/Contents/Resources"
	cp bundle/AppIcon.icns "$(APPDIR)/Contents/Resources/AppIcon.icns"
	# Signature Developer ID + hardened runtime + timestamp sécurisé (exigés pour notariser).
	codesign --force --options runtime --timestamp --sign "$(DEV_ID)" "$(APPDIR)"
	rm -f "$(DMGFILE)"
	rm -rf "$(BUILD)/dmgroot"
	mkdir -p "$(BUILD)/dmgroot"
	cp -R "$(APPDIR)" "$(BUILD)/dmgroot/"
	ln -s /Applications "$(BUILD)/dmgroot/Applications"
	hdiutil create -volname "$(APP)" -srcfolder "$(BUILD)/dmgroot" -ov -format UDZO "$(DMGFILE)"
	rm -rf "$(BUILD)/dmgroot"
	codesign --force --timestamp --sign "$(DEV_ID)" "$(DMGFILE)"
	# Soumission à Apple (bloquant) puis agrafage du ticket sur le DMG.
	xcrun notarytool submit "$(DMGFILE)" --keychain-profile "$(NOTARY_PROFILE)" --wait
	xcrun stapler staple "$(DMGFILE)"
	@echo "==> $(DMGFILE) signé Developer ID + notarisé + staplé (distribuable sans avertissement)"

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
