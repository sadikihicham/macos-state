# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

**macOS State** — a system monitor rendered as a translucent, draggable **HUD floating on the
desktop** (think Activity Monitor, but discreet and always visible). Shows CPU, Memory, Disk,
Battery, and Network as utilization gauges, plus an expanded mode with per-metric detail and a
top-process list with guarded kill. Accessory app (no Dock icon), menu-bar driven.

Pure SwiftPM, no Xcode project. Swift tools 6.0 but **Swift 5 language mode** (deliberate: avoids
Swift 6 strict-concurrency friction on main-actor AppKit code). macOS 14.0+. **No external
dependencies.** Comments and identifiers are in **French**; user-facing UI strings go through a
built-in i18n layer (`Localization.swift`, FR/EN/AR + RTL) — see Conventions.

Beyond the desktop HUD, it also offers a **live menu-bar readout** (CPU/RAM/temp + mini-sparkline),
**sparkline history** for CPU/RAM/temperature, **threshold alerts** as local notifications, and an
**adjustable UI scale** (Normal/Grand/Très grand).

## Commands (Makefile)

```bash
make build           # swift build
make run             # build + launch the HUD (dev)
make test            # swift test — unit tests on the pure SystemMetrics lib
make verify          # test + check-net — THE FULL GATE (run before committing)
make check-net       # fitness function: proves the binary has zero network capability
make accuracy        # eval d'exactitude : samplers vs sources système (sysctl/vm_stat/df/pmset/ifconfig)
make hooks           # activer les git hooks versionnés (.githooks) — une fois après clone
make release         # swift build -c release
make bundle          # assemble + ad-hoc codesign .build/MacOSState.app (arch hôte)
make bundle-universal # .app UNIVERSEL (arm64+x86_64), ad-hoc — base de make dmg
make dmg             # .dmg distribuable : .app UNIVERSEL (arm64+x86_64), ad-hoc, lien /Applications
make notarize        # .dmg signé Developer ID + notarisé + staplé (sans avertissement Gatekeeper)
                     #   → requiert un compte Apple Developer ; lit DEV_ID + NOTARY_PROFILE depuis l'env
make install-agent   # install LaunchAgent (~/Library/LaunchAgents/com.hicham.macosstate.plist)
make uninstall-agent # retire le LaunchAgent
make clean
```

Run a single test with SwiftPM filtering, e.g.:
```bash
swift test --filter KillGuardTests
swift test --filter SystemMetricsTests.KillGuardTests/testRefusesSystemBinary
```

**`make verify` is the authoritative gate.** It runs the unit tests AND
`scripts/check-no-network.sh`, which scans the release binary's linked frameworks and undefined
symbols and **fails** if any network capability is present (CFNetwork, Network.framework, `_socket`,
`_connect`, `URLSession`, `NWConnection`, …). `getifaddrs`/`freeifaddrs` are whitelisted — they are
passive local interface-counter reads, the only "network" API allowed.

**Gates.** Server-side: `.github/workflows/ci.yml` runs `make verify` on `macos-15` for every push
to `main` and every PR — the authoritative gate (can't be bypassed). Locally: `.githooks/` (run
`make hooks` once after cloning to set `core.hooksPath`) — `pre-commit` runs `make test` (fast),
`pre-push` runs `make check-net` (release build + zero-network scan). Local hooks are a convenience;
CI is the source of truth.

## Architecture

Four SwiftPM targets (see `Package.swift`): a tiny **C shim** (`CIOHID`), a **pure, testable core**
(`SystemMetrics`, depends on `CIOHID`), a **thin AppKit/SwiftUI app** (`MacOSStateApp`), and a test
target (`SystemMetricsTests`).

### `Sources/CIOHID/` — C shim (read-only system access)
`CIOHID.c` + `include/CIOHID.h` — prototypes for the **private IOHID** temperature functions (Apple
Silicon thermal sensors, not in the public SDK). IOKit-only, no sockets — does **not** affect the
zero-network gate. `SystemMetrics` consumes it via `ThermalSampler`.

### `Sources/SystemMetrics/` — pure core (no UI, no AppKit, fully testable)
- **Samplers** wrap Darwin/IOKit syscalls, one metric each: `CPUSampler` (`host_statistics` +
  `host_processor_info` per-core), `MemorySampler` (`host_statistics64` + `sysctl hw.memsize`),
  `DiskSampler` (Foundation volume APIs), `NetworkSampler` (`getifaddrs`), `BatterySampler`
  (`IOKit.ps`), `ThermalSampler` (CPU temp via the `CIOHID` private IOHID shim) + `SMCFan` (fan RPM
  via SMC / IOKit public API), `ProcessLister` (`proc_listpids`/`proc_pidinfo`/`proc_pid_rusage`).
- `Models.swift` — shared structs (`MetricsSnapshot`, `BatteryInfo`, `ProcSample`, `ThermalSample`, …)
  and **pure functions** (`formatBytes`, `delta`, `rate`, `cpuUsage`). Put new side-effect-free logic
  here so it can be unit-tested.
- `KillGuard.swift` — **pure** `decide(...) -> KillDecision` (`.allowed` / `.allowedWithWarning` /
  `.denied`). The security heart; see below.
- `AlertEvaluator.swift` — **pure** threshold logic: `evaluate(...)` with hysteresis (0.90) and
  **rising-edge** firing (alert fires once on crossing, not every tick). Backs the notification alerts.
- `RingHistory.swift` — bounded circular buffer (~90 samples ≈ 3 min @ 2 s) exposing normalized
  `[Double]` for sparklines.
- `NetworkProof.swift` — runtime open-socket count via libproc; the "zero-network" seal surfaced in
  the HUD (complements the static `make check-net` gate).
- **Samplers are stateful**: each caches previous counters (ticks, rx/tx bytes, per-PID CPU time) to
  compute deltas. Preserve that invariant — a snapshot is meaningless without the prior sample.

### `Sources/MacOSStateApp/` — AppKit coordinator + SwiftUI views (all `@MainActor`)
- `main.swift` — entry point; `MainActor.assumeIsolated` sets up `NSApplication` as accessory
  (`LSUIElement` in `bundle/Info.plist`).
- `AppDelegate.swift` — lifecycle, `NSStatusItem` menu-bar icon + `NSMenu`, kill-confirmation
  `NSAlert`, `validateMenuItem` for dynamic menu state. Also drives the **live menu-bar readout**
  (CPU/RAM/temp text + a generated mini-sparkline `NSImage`) and **threshold alerts**
  (`evaluateAlerts()` → `postAlert()` via `UNUserNotificationCenter` — there is no separate
  notification manager, it's inline here), both reacting to `engine.$snapshot`.
- `MetricsEngine.swift` — `ObservableObject` coordinator. Owns the samplers and a `Timer` on
  `RunLoop.main` (interval from settings, 1/2/5s). `tick()` reads every sampler → aggregates into
  `@Published var snapshot` and appends to the `cpuHist`/`ramHist`/`tempHist` `RingHistory` buffers.
  Process listing runs **only when expanded** (`processListingEnabled`).
- `DesktopPanel.swift` — borderless non-activating translucent `NSPanel` (`.ultraThinMaterial`,
  clear background, floating, movable-by-background). Persists position via `didMoveNotification`.
- `ProcessController.swift` — orchestrates kills (identity re-validation → KillGuard → graceful
  `NSRunningApplication.terminate()` → SIGTERM → SIGKILL escalation).
- `Settings.swift` — `UserDefaults` wrapper: position, expanded, interval, float-on-top, per-metric
  visibility, plus `menubarMetric` (off/cpu/ram/temp), `alertsEnabled` (+ thresholds), and `uiScale`
  (1.0/1.25/1.5 = Normal/Grand/Très grand). `LaunchAtLogin.swift` — `SMAppService`.
- `Localization.swift` — lightweight in-code i18n (no `.lproj`): FR→EN/AR tables, `L.t()` /
  `L.fmt()` (safe `%@`-slot formatting), and RTL detection. **All UI strings route through this.**
- `Views/` — `HUDView` (SwiftUI root, reduced/expanded toggle via `@AppStorage`, resizes the panel
  anchored top-left on geometry change, applies `uiScale`), `Gauges`, `ExpandedDetails` (per-metric
  detail + trend sparklines), `ProcessListView`, `Sparkline` (normalized-history mini-chart).

### Data flow
`Timer.tick()` → each sampler reads + computes delta → `MetricsEngine.snapshot` (`@Published`) +
ring-history append → `HUDView` (`@ObservedObject engine`) re-renders. The same `$snapshot` stream
also feeds `AppDelegate`'s menu-bar readout and alert evaluation. UI actions (resize, kill request)
flow back up via closures passed from `AppDelegate`. Settings changes mutate `Settings`, which the
engine observes to re-schedule the timer.

## Security model — do not weaken

This is the project's reason for the specific design; treat both invariants as hard constraints.

1. **Zero network.** The app is strictly local. Any change that links a network framework or symbol
   breaks `make check-net` (a CI/local gate). Never add networking. If you need a new system API,
   confirm it doesn't pull in CFNetwork/Network.framework.

2. **Guarded kill (fail-closed).** A process can be terminated only through
   `ProcessController` → `KillGuard.decide`, which:
   - allows only the **current user's own** processes (`uid == getuid()`), no privilege escalation;
   - **refuses** PID ≤ 1, the monitor itself, binaries under `/System`, `/usr/libexec`, `/usr/sbin`,
     and a hardcoded critical-daemon blacklist (launchd, WindowServer, loginwindow, cfprefsd, tccd,
     coreaudiod, …); warns on system-auto-restarted apps (Dock, Finder);
   - **fails closed**: unreadable identity → refusal;
   - guards against **PID reuse** — identity (uid + start time in µs) is re-validated immediately
     before SIGKILL escalation (TOCTOU mitigation);
   - requires **human confirmation** (`NSAlert`) before any signal.

   App is intentionally **non-sandboxed** (kill is incompatible with App Sandbox). When touching kill
   logic, add a `KillGuardTests` case first — the guard is pure and must stay covered.

   **Known debt (F1):** the graceful `NSRunningApplication.terminate()` path in
   `ProcessController.perform` is not unit-covered (NSRunningApplication is not injectable) and has a
   theoretical, sub-microsecond `validate→terminate` TOCTOU window. Runtime risk is negligible; harden
   by abstracting `NSRunningApplication` behind a protocol if you ever touch that path.

## Conventions

- **French** for comments/identifiers — match the file. `// MARK: -` section dividers, `///` docs.
- **User-facing UI strings are not hardcoded**: add them to the FR/EN/AR tables in
  `Localization.swift` and render via `L.t()` / `L.fmt()`. Keep RTL working through CSS-logical /
  SwiftUI-native layout, not a separate AR codepath.
- New testable logic goes in `SystemMetrics` (pure); AppKit/SwiftUI glue stays in `MacOSStateApp`.
- All app-layer types are `@MainActor`; respect Darwin buffer lifetimes (e.g. `vm_deallocate` after
  `host_processor_info`).
- Work is organized as sequential **slices** (see `git log`: Slice 0 scaffold → Slice 4 hardening,
  V1 complete). Keep changes as small reversible slices.
