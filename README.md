# macOS State

[![CI](https://github.com/sadikihicham/macos-state/actions/workflows/ci.yml/badge.svg)](https://github.com/sadikihicham/macos-state/actions/workflows/ci.yml)

**English** · [Français](README.fr.md) · [العربية](README.ar.md)

macOS system monitor shown as a **floating desktop HUD** (like Activity Monitor, but discreet
and always visible). CPU · Memory · Disk · Battery · Network as utilization rates, with a
**collapsed mode** (gauges) ⇄ **expanded mode** (details + live process list, with the ability
to **kill** a process/app).

Native **Swift + SwiftUI/AppKit**. 100% local, **no network access** (enforced by a test).

## Features

- **Desktop HUD**: translucent, draggable, remembers its position; collapsed ⇄ expanded.
- **Metrics**: CPU (+ per core), Memory (active/wired/compressed/free), Disk (used/free/total),
  Battery (%, charge, time left, **cycles + health**), Network (↓/↑ throughput, global +
  **per interface**), **Temperature (CPU) + fan speed** (best-effort; “N/A” if unavailable).
- **Processes** (expanded mode): top CPU/memory consumers, icon, **Kill button** with confirmation.
- **Menu-bar icon** (next to the clock): Show/Hide HUD, Always on top, Interval, Metrics,
  Launch at login, Quit.
- **Settings**: refresh interval (1/2/5 s), displayed metrics, launch at login.
- **Trilingual UI** (FR / EN / AR) with an in-app language menu, live switching, and RTL for Arabic.

## Security model

- **Zero network**: strictly local monitor. Enforced by `make check-net` (fails if any outbound
  network framework/symbol is linked).
- **Bounded, guarded kill** (`KillGuard`, a pure tested function):
  - only the **current user's** processes (`uid == getuid()`), no privilege escalation;
  - **refuses** reserved PIDs (≤1), the monitor itself, **system binaries** (path under
    `/System`, `/usr/libexec`, `/usr/sbin`…), and a **blacklist** of critical daemons
    (launchd, WindowServer, loginwindow, cfprefsd, tccd, coreaudiod…);
  - **fail-closed**: unreadable identity → refusal;
  - **PID-reuse protection**: identity (uid + start time in **µs**) re-validated right before
    striking and before the `SIGKILL` escalation;
  - mandatory **human confirmation** (NSAlert); `SIGTERM` then `SIGKILL` after a delay.
- **Non-sandboxed** (killing processes is incompatible with the App Sandbox), minimal
  entitlements, no secrets, no writes outside `UserDefaults`.

## Build & run

Requirements: macOS 14+, Xcode/Swift 6.

```bash
make run            # build + launch the HUD (dev)
make test           # unit tests (pure SystemMetrics lib)
make accuracy       # accuracy eval: samplers vs system sources (sysctl/vm_stat/df/pmset/ifconfig)
make check-net      # fitness function: proves there is no network capability
make verify         # test + check-net (full gate)
make hooks          # enable the versioned git hooks (run once after cloning)
```

## Distribution

```bash
make dmg            # distributable .dmg: UNIVERSAL app (arm64 + x86_64), ad-hoc signed
make notarize       # Developer ID signed + notarized .dmg (no Gatekeeper warning; needs an
                    #   Apple Developer account — reads DEV_ID and NOTARY_PROFILE from the env)
make bundle         # ad-hoc signed .app (.build/MacOSState.app)
make install-agent  # LaunchAgent: start at login (personal use)
```

The `make dmg` output is **ad-hoc signed** (not notarized): on another Mac, first launch is
blocked by Gatekeeper. Bypass: right-click the app → **Open** → Open, or
`xattr -dr com.apple.quarantine "/Applications/MacOSState.app"`. For warning-free distribution,
use `make notarize` (Apple Developer account required).

## Architecture

```
Sources/
  SystemMetrics/      # PURE & testable core (no UI)
    CPUSampler · MemorySampler · DiskSampler · BatterySampler · NetworkSampler
    ProcessLister · KillGuard · Models (pure functions)
  MacOSStateApp/      # AppKit + SwiftUI
    main · AppDelegate (menu bar + confirmations) · DesktopPanel (desktop NSPanel)
    MetricsEngine (timer → snapshot) · ProcessController (kill) · Settings · LaunchAtLogin
    Views/ (HUDView, Gauges, ExpandedDetails, ProcessListView)
Tests/SystemMetricsTests/   # deltas, %, formats, KillGuard, ProcessLister, accuracy
```

All logic (computations, kill decision) lives in `SystemMetrics` as **pure functions** →
testable without hardware. System access (mach/IOKit/libproc) is isolated in the `*Sampler`s.

## End-to-end verification

1. `make verify` → green tests + zero network.
2. `make run` → compare CPU/RAM/Disk/Battery/Network against **Activity Monitor**.
3. Collapsed ⇄ expanded; position/state persisted across relaunch.
4. Safe kill: `sleep 1000 &` → find it → Kill → it disappears; a system process
   (e.g. `WindowServer`) is **not killable** (button disabled / `KillGuard` refusal).
