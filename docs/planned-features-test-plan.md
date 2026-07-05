# Planned Features Test Plan

## Automated checks

- Protection policy behavior on AC and battery power.
- Warning and urgent battery thresholds across the full `0%–100%` range.
- Independent per-condition alert cooldowns and forced restore-failure alerts.
- AC disconnection detection.
- Urgent battery precedence over the normal battery warning.
- Sustained thermal-pressure timing and reset after recovery.
- Low Power Mode and session-expiry trigger detection.
- Session battery-use accumulation, foreground-app correlation, sample bounds,
  and numeric version comparison.
- System-pressure, battery-temperature, and battery-power value ranges; menu
  visibility toggles; and opt-in high-activity application aggregation.
- Debug and release compilation, formatting, app signing, and Info.plist checks.

## Manual macOS checks

Run these with all remote channels disabled unless a real recipient or test
webhook is intentionally configured.

1. Confirm the inactive icon is a gray filled thumb.
2. Enable No-Sleep Mode and confirm the same thumb becomes green.
3. Trigger the normal battery threshold and confirm the same thumb becomes
   yellow.
4. Trigger the urgent battery threshold and confirm the same thumb becomes red.
5. Use VoiceOver or Accessibility Inspector to confirm that all four states
   have distinct labels.
6. Enable No-Sleep Mode, lock macOS normally, then unlock and confirm the task and
   timer continued.
7. Open Settings > Alerts and send a local test alert.
8. Enable each intentionally configured remote channel one at a time and use
   `Test enabled channels`. Confirm delivery or a visible, non-fatal error.
9. Confirm repeated alerts for one condition respect the selected cooldown,
   while a different condition can still alert immediately.
10. Disable No-Sleep Mode and confirm `SleepDisabled` returns to `No`.
11. Start an unlimited session and confirm it remains active without an expiry
    countdown; stop it manually and confirm `SleepDisabled` returns to `No`.
12. Leave protection active for at least two minutes, then open Settings >
    Activity and confirm the battery, thermal-pressure, and foreground-app data
    update without claiming a Celsius temperature or per-process wattage.
13. Toggle Settings > General > Launch at login on and off. If macOS requires
    approval, confirm the app shows the System Settings location.
14. Configure a test HTTPS release manifest, then check both an older/equal
    version and a newer version with an HTTPS download URL.
15. Disable Activity recording during protection and confirm the sample count
    stops increasing for at least two minutes; re-enable it and confirm a new
    recording begins.
