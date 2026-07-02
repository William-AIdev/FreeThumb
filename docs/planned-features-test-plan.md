# Planned Features Test Plan

## Automated checks

- Protection policy behavior on AC and battery power.
- Warning and urgent battery thresholds across the full `0%–100%` range.
- Independent per-condition alert cooldowns and forced restore-failure alerts.
- AC disconnection detection.
- Urgent battery precedence over the normal battery warning.
- Sustained thermal-pressure timing and reset after recovery.
- Low Power Mode and session-expiry trigger detection.
- Debug and release compilation, formatting, app signing, and Info.plist checks.

## Manual macOS checks

Run these with all remote channels disabled unless a real recipient or test
webhook is intentionally configured.

1. Confirm the inactive icon is an unfilled thumb using the standard menu bar
   color.
2. Start protection and confirm the icon becomes a green filled thumb.
3. Trigger the normal battery threshold and confirm the icon becomes a yellow
   warning triangle.
4. Trigger the urgent battery threshold and confirm the icon becomes a red
   critical octagon.
5. Use VoiceOver or Accessibility Inspector to confirm that all four states
   have distinct labels.
6. Click `Lock & Keep Running`, confirm protection starts, then follow the
   `Control-Command-Q` instruction. After unlocking, confirm the task and timer
   continued.
7. Expand `Safety alert delivery` and send a local test alert.
8. Enable each intentionally configured remote channel one at a time and use
   `Send test alert`. Confirm delivery or a visible, non-fatal error.
9. Confirm repeated alerts for one condition respect the selected cooldown,
   while a different condition can still alert immediately.
10. Stop protection and confirm `SleepDisabled` returns to `No`.
