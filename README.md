# FreeThumb

FreeThumb is a safety-first macOS menu bar utility for keeping local AI coding
work alive without leaving the display open.

## Current scope

- Read AC/battery status, charge level, thermal pressure, and Low Power Mode.
- Temporarily enables macOS `disablesleep` with one-time, narrowly scoped
  administrator authorization.
- Works the same on AC and battery power.
- Battery, Low Power Mode, and thermal conditions produce soft alerts only.
- Detects physical lid changes, sets the built-in display backlight to zero
  when the lid closes, and restores its previous brightness when the lid opens.
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

## Next milestone

Run the physical lid, AC disconnect, forced-quit, low-battery, and thermal test
matrix before publishing a release.
