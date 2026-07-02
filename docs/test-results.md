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
