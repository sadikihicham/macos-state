# macOS State

[![CI](https://github.com/sadikihicham/macos-state/actions/workflows/ci.yml/badge.svg)](https://github.com/sadikihicham/macos-state/actions/workflows/ci.yml)

[English](README.md) · **Français** · [العربية](README.ar.md)

Moniteur système macOS affiché en **HUD flottant sur le bureau** (façon Activity Monitor,
mais discret et toujours visible). CPU · Mémoire · Disque · Batterie · Réseau, en taux
d'utilisation, avec un **mode réduit** (jauges) ⇄ **mode développé** (détails + liste des
process actifs avec possibilité de **tuer** un process/app).

Natif **Swift + SwiftUI/AppKit**. 100 % local, **aucun accès réseau** (garanti par un test).

## Fonctionnalités

- **HUD bureau** translucide, déplaçable, position mémorisée ; réduit ⇄ développé.
- **Métriques** : CPU (+ par cœur), Mémoire (active/câblée/compressée/libre), Disque
  (utilisé/libre/total), Batterie (%, charge, temps restant, **cycles + santé**), Réseau
  (débit ↓/↑ global + **par interface**), **Température (CPU) + ventilateur** (best-effort ; « N/A » si indispo).
- **Process** (mode développé) : top consommateurs CPU, mémoire, icône, **bouton Tuer**
  avec confirmation.
- **Icône barre de menu** (à côté de l'horloge) : Afficher/Masquer le HUD, Toujours
  au-dessus, Intervalle, Métriques, Lancer au login, Quitter.
- **Réglages** : intervalle de rafraîchissement (1/2/5 s), métriques affichées, lancement
  au login.
- **Sparklines d'historique** (tendances CPU / RAM / température sur les ~3 dernières min) en mode développé — 100% local.
- **Interface trilingue** (FR / EN / AR) : menu Langue intégré, bascule en direct, RTL pour l'arabe.

## Sécurité (modèle)

- **Zéro réseau** : moniteur strictement local. Vérifié par `make check-net` (échoue si un
  framework/symbole réseau sortant est lié).
- **Kill borné et gardé** (`KillGuard`, fonction pure testée) :
  - uniquement les process de **l'utilisateur courant** (`uid == getuid()`), pas d'élévation ;
  - **refus** des PID réservés (≤1), du moniteur lui-même, des **binaires système**
    (chemin sous `/System`, `/usr/libexec`, `/usr/sbin`…), d'une **blacklist** de daemons
    critiques (launchd, WindowServer, loginwindow, cfprefsd, tccd, coreaudiod…) ;
  - **fail-closed** : identité illisible → refus ;
  - **anti-réutilisation de PID** : identité (uid + start time **µs**) re-validée juste
    avant de frapper, et avant l'escalade `SIGKILL` ;
  - **confirmation humaine** obligatoire (NSAlert) ; `SIGTERM` puis `SIGKILL` après délai.
- **Non-sandboxé** (le kill de process est incompatible avec l'App Sandbox), entitlements
  minimaux, aucun secret, aucune écriture hors `UserDefaults`.

## Build & exécution

Prérequis : macOS 14+, Xcode/Swift 6.

```bash
make run            # build + lance le HUD (dev)
make test           # tests unitaires (lib pure SystemMetrics)
make accuracy       # eval d'exactitude : samplers vs sources système (sysctl/vm_stat/df/pmset/ifconfig)
make check-net      # fitness function : prouve l'absence de réseau
make verify         # test + check-net (porte complète)
make hooks          # active les git hooks versionnés (une fois après clone)
```

## Distribution

```bash
make dmg            # .dmg distribuable : app UNIVERSELLE (arm64 + x86_64), signée ad-hoc
make notarize       # .dmg signé Developer ID + notarisé (sans avertissement Gatekeeper ; requiert
                    #   un compte Apple Developer — lit DEV_ID et NOTARY_PROFILE depuis l'env)
make bundle         # .app signé ad-hoc (.build/MacOSState.app)
make install-agent  # LaunchAgent : démarre au login (usage perso)
```

La sortie de `make dmg` est **signée ad-hoc** (non notarisée) : sur un autre Mac, le 1er
lancement est bloqué par Gatekeeper. Contournement : clic droit sur l'app → **Ouvrir** →
Ouvrir, ou `xattr -dr com.apple.quarantine "/Applications/MacOSState.app"`. Pour une
distribution sans avertissement, utilise `make notarize` (compte Apple Developer requis).

## Architecture

```
Sources/
  SystemMetrics/      # cœur PUR & testable (sans UI)
    CPUSampler · MemorySampler · DiskSampler · BatterySampler · NetworkSampler
    ProcessLister · KillGuard · Models (fonctions pures)
  MacOSStateApp/      # AppKit + SwiftUI
    main · AppDelegate (menu bar + confirmations) · DesktopPanel (NSPanel bureau)
    MetricsEngine (timer → snapshot) · ProcessController (kill) · Settings · LaunchAtLogin
    Views/ (HUDView, Gauges, ExpandedDetails, ProcessListView)
Tests/SystemMetricsTests/   # deltas, %, formats, KillGuard, ProcessLister, exactitude
```

Toute la logique (calculs, décision de kill) vit dans `SystemMetrics` sous forme de
**fonctions pures** → testables sans matériel. Les accès système (mach/IOKit/libproc) sont
isolés dans les `*Sampler`.

## Vérification end-to-end

1. `make verify` → tests verts + zéro réseau.
2. `make run` → comparer CPU/RAM/Disque/Batterie/Réseau à **Activity Monitor**.
3. Mode réduit ⇄ développé ; position/état persistés après relance.
4. Kill sûr : `sleep 1000 &` → le repérer → Tuer → disparaît ; un process système
   (ex. `WindowServer`) est **non tuable** (bouton grisé / refus `KillGuard`).
