# FreeThumb Test Results

## 2026-07-02 — Physical lid test

Environment:

- macOS 26.5.1 (25F80)
- Apple silicon (`arm64`)
- Commit `72f3c1c`
- Ad-hoc signed release build from `scripts/build-app.sh`

Objective evidence from `powerd`:

1. FreeThumb protection was active for 3 minutes 59 seconds.
2. The lid closed at `20:54:50` and reopened at `20:57:45`.
3. No system sleep event occurred during that closed-lid interval.
4. FreeThumb released its sleep assertion at `20:57:57`.
5. `SleepDisabled` returned to `No` after protection stopped.
6. A later unprotected lid closure entered normal `Clamshell Sleep`, confirming
   that FreeThumb did not leave the global sleep setting enabled.

Result:

- Closed-lid task continuity: **passed**
- Sleep-setting restoration after normal stop: **passed**
- Built-in brightness restored after reopening: **passed (user confirmed)**
- Reopening returned directly to the desktop without an unexpected lock:
  **passed (user confirmed)**

## 2026-07-03 — Batch reliability test

User-confirmed passes:

- Settings persistence
- Two consecutive start/stop cycles
- Cleanup after normal quit while protection was active
- Watchdog cleanup after force-quitting FreeThumb
- Manual macOS lock while the protected background task continued

Battery alert retest after expanding the UI range to the full `0%–100%`:

- Standard battery warning: **passed (user confirmed)**
- Urgent battery warning: **passed (user confirmed)**
- Protection remained active for both warning levels: **passed (user confirmed)**

## 2026-07-03 — Planned features automated validation

- Swift formatting and strict lint: **passed**
- Swift tests: **16 passed in 3 suites**
- AC disconnect, battery precedence, sustained thermal timing, thermal reset,
  Low Power Mode, expiry boundary, and cooldown policies: **passed**
- Messages AppleScript compile without sending: **passed**
- Mail AppleScript compile without sending: **passed**
- Release app build and ad-hoc signature verification: **passed**
- Info.plist and Apple Events usage description validation: **passed**
- Runtime launch stability: **passed**
- Webhook URL Keychain read occurs once at startup rather than on each status
  refresh: **passed**

Live iMessage, Mail, and webhook delivery requires an intentionally configured
recipient or endpoint. These side-effecting checks remain in
`docs/planned-features-test-plan.md` for user-controlled validation.

## 2026-07-03 — Remaining macOS TODO validation

- Swift formatting and strict lint: **passed**
- Swift tests: **20 passed in 5 suites**
- Battery-use accumulation, foreground-app correlation, bounded curve storage,
  and numeric version comparison: **passed**
- Unlimited IOKit assertion path: **compiled in Debug and Release**
- Launch-at-login registration through `SMAppService.mainApp`: **compiled**
- Configurable HTTPS update manifest parsing and validation: **compiled**
- Release app build, ad-hoc signature, executable, and Info.plist: **passed**
- Runtime launch stability: **passed**
- Idle performance sample after adaptive polling: **0.0%–0.3% CPU, 13 MB,
  4 threads** across five two-second samples
- `SleepDisabled` before runtime launch: **No**

Login-item approval, unlimited-session stop behavior, chart rendering after two
minutes, and a successful update check against the eventual release endpoint
remain user-controlled checks in `docs/planned-features-test-plan.md`.

## 2026-07-03 — Local notification diagnosis

- Notification delegate registration before application launch completes:
  **implemented**
- Foreground presentation options for banner, Notification Center list, and
  sound: **implemented**
- Test notification delay and visible authorization summary: **implemented**
- Current macOS authorization readback: **denied**; macOS will ignore local
  notification requests until the user enables FreeThumb in System Settings
- Swift tests: **20 passed in 5 suites**
- Release build and ad-hoc signature verification: **passed**

## 2026-07-03 — Activity toggle and icon consistency

- Activity preference persists and gates session sampling: **passed by build
  inspection**
- Disabling Activity stops curve updates and foreground-app lookups while
  retaining the existing recording: **implemented**
- All inactive, healthy, warning, and critical states use
  `hand.thumbsup.fill`; only color and accessibility text change: **verified**
- Swift tests: **20 passed in 5 suites**
- Release build and ad-hoc signature verification: **passed**

## 2026-07-04 — Monitoring energy optimization

- Power-source changes use an IOKit run-loop notification instead of a
  one-second polling loop: **implemented**
- Protected safety snapshots run every 30 seconds; protected lid checks run
  every 2 seconds; the one-second task exists only for finite countdowns:
  **implemented**
- Monitoring tasks restart immediately when protection starts or stops, so an
  earlier idle sleep cannot delay the protected polling interval: **verified by
  code inspection**
- Swift tests: **20 passed in 5 suites**
- Release build, ad-hoc signature, executable, and Info.plist: **passed**
- New inactive instance, ten two-second samples: **nine at 0.0% CPU and one at
  0.2% CPU; 16 MB resident memory**
- Ten-second stack sample: main run loop blocked waiting for events in
  **7,877 of 7,881 samples; 16.4 MB physical footprint**
- The previously running build showed recurring **1.4%–1.9% CPU** refresh
  spikes in the same command-line measurement method.

## 2026-07-04 — Optional menu monitoring widgets

- CPU and memory pressure plus the combined battery temperature/total-power card
  share one 30-second sample and retain at most 2,880 points: **implemented**
- The pressure and combined battery cards can be hidden independently;
  disabling both stops the metric sampler: **implemented**
- High-activity application scanning is separately opt-in, runs once per
  minute only while the menu is visible, includes only the current user's
  third-party `.app` bundles, and ranks them by sampled `proc_pid_rusage`
  energy deltas rather than CPU alone: **implemented**
- Runtime verification excluded WindowServer, System Events, FreeThumb, and
  Apple system apps while reporting third-party app power in watts: **passed**
- Closed-menu history collection does not publish SwiftUI changes; chart
  rendering is deferred until the menu opens and capped at 240 plotted points:
  **implemented after runtime profiling**
- Live sensor sanity check: **CPU 9.73%, memory 46.1 GB, battery 30.31°C**
- Total power uses AC input while connected and battery output while unplugged: **passed**
- Final closed-menu runtime sample across thirty two-second intervals: **29 at
  0.0% CPU and one 0.9% collection spike; 16–17 MB resident memory**
- Metric cards keep only current values and charts, without redundant average
  labels or dashed average lines: **implemented**
- Continuous pointer hover reveals axes, nearest-sample time/value annotations,
  vertical rules, and point markers without changing the sampling interval:
  **compiled in Debug and Release**

## 2026-07-04 — Localization

- Main menu, Settings, Activity, monitoring charts, dynamic durations,
  thresholds, and Info.plist permission text: **localized**
- Bundled languages: **English, Simplified Chinese, Japanese, Korean, Spanish,
  Hindi, French, Bengali, Portuguese, and Russian**
- Translation-table validation: **135 keys in every non-English locale; all
  `.strings` files pass `plutil`**
- Swift tests: **20 passed in 5 suites**
- Release bundle contains all ten `.lproj` directories and passes code-signing
  verification: **passed**
- General Settings language picker switches the SwiftUI locale and dynamic
  localization bundle immediately: **implemented**
- Every non-English locale contains all **135** current UI keys, including the
  language picker labels: **validated in the Release bundle**

## 2026-07-04 — Chart units and Settings reliability

- Pressure, temperature, and battery-power axes are always visible with `%`,
  `°C`, and `W` units; hover only reveals the nearest timestamp and exact value:
  **implemented**
- Pressure legend remains visible without hover: **implemented**
- Monitoring cards use a persistent one-point rounded border: **implemented**
- macOS 14 and later use the system `SettingsLink`, followed by explicit app
  activation and two delayed key-window focus attempts: **implemented**
- Swift tests: **20 passed in 5 suites**
- Release build and ad-hoc signature verification: **passed**
