# FreeThumb

FreeThumb is a safety-first macOS menu bar utility for keeping local AI coding
work alive without leaving the display open.

## Current scope

- Read AC/battery status, charge level, thermal pressure, and Low Power Mode.
- Temporarily enables macOS `disablesleep` with one-time, narrowly scoped
  administrator authorization.
- Works the same on AC and battery power.
- Battery, Low Power Mode, and thermal conditions produce soft alerts only.
- Uses distinct menu bar symbols and colors for inactive, healthy, warning, and
  critical states, with matching accessibility labels.
- Detects physical lid changes, sets the built-in display backlight to zero
  when the lid closes, and restores its previous brightness when the lid opens.
- Can start protection from `Lock & Keep Running`, then guides the user to the
  standard macOS `Control-Command-Q` lock action.
- Supports configurable local, iMessage, Mail, and HTTPS webhook safety alerts
  with per-condition cooldowns and a Keychain-protected webhook URL.
- Restores the previous sleep setting on stop or session expiry.
- A watchdog restores sleep if FreeThumb exits unexpectedly after changing it.

## Run

```sh
swift run freethumb status
swift run freethumb status --json
swift run freethumb protect --minutes 30
```

`protect` is the non-privileged CLI prototype. Build the menu bar app with:

```sh
./scripts/build-app.sh
open dist/FreeThumb.app
```

The one-time authorization installs `/private/etc/sudoers.d/freethumb`. It only
permits the signed-in user to run `pmset disablesleep 0` and
`pmset disablesleep 1` without another password prompt.

Built-in brightness control uses the private macOS DisplayServices framework so
that closing the lid does not trigger the system's display-sleep lock policy.
This makes GitHub distribution appropriate, but it is not suitable for the Mac
App Store and may require compatibility updates on future macOS versions.

## Safety alerts

Local notifications are enabled by default. iMessage, Mail, and webhook
delivery are opt-in and can be tested with `Send test alert` before starting a
session. iMessage and Mail use the accounts already configured in their macOS
apps and may request Automation permission the first time they are used.

Configurable triggers include battery warning and urgent levels, sustained
serious or critical thermal pressure, AC disconnection, Low Power Mode, and an
approaching session expiry. Each condition has an independent cooldown. Alert
delivery failures are shown in FreeThumb but never stop the protected task.

Webhook delivery accepts HTTPS URLs only. The URL is stored in macOS Keychain;
other non-secret preferences are stored in the app's standard preferences.

## Next milestone

Complete the manual channel and colored-icon checks in
`docs/planned-features-test-plan.md`, then configure release signing and
notarization.

Windows development lessons and platform boundaries are documented in
`docs/windows-development-lessons.md`.

## Planned features

- [x] **Distinct colored status icons**: make the menu bar state immediately
  recognizable by both symbol and color.
  - Inactive: keep the current unfilled, uncolored thumb icon.
  - Active and healthy: use the current filled thumb icon in green.
  - Warning: use a distinct warning symbol in yellow.
  - Critical: use a different critical symbol in red.
  - Warning and critical states must not rely on color alone; their symbols and
    accessibility labels must also differ.
- [x] **Lock & Keep Running**: keep the active FreeThumb protection session
  running while the macOS screen is locked, so unattended AI coding tasks can
  continue without leaving the desktop accessible.
  - The initial version will activate protection first, then direct the user to
    the standard macOS lock action (`Control-Command-Q`). This uses documented
    system behavior and requires no Accessibility permission.
  - A later one-click lock action will only be added if it can avoid broad
    permissions and pass compatibility testing across supported macOS versions.
  - Locking must never log the user out, stop the protected task, or change the
    existing session expiry and recovery behavior.
- [x] **Remote safety alerts**: notify the user when a long-running protection
  session crosses a configurable risk threshold.
  - Initial triggers: battery below a warning level, sustained serious or
    critical thermal pressure, AC power disconnected, Low Power Mode enabled,
    session expiry approaching, or failure to restore the normal sleep setting.
  - Start with local macOS notifications, then add opt-in delivery through
    iMessage, email, and a generic webhook for other common messaging services.
  - Thresholds, cooldowns, and enabled channels must be configurable so repeated
    sensor updates do not spam the user.
  - Alerts report the condition and current FreeThumb state; they do not stop a
    running session unless the user separately enables an automatic action.
