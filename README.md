# FreeThumb

[English](README.md) | [简体中文](README.zh-CN.md) | [日本語](README.ja.md) |
[한국어](README.ko.md)

<p align="center">
  <img src="Resources/AppIcon.png" width="160" alt="FreeThumb app icon">
</p>

Keep long-running work alive on your Mac—even when you lock the screen or close
the lid.

FreeThumb is a lightweight macOS menu bar app for local AI agents, builds,
downloads, renders, and other tasks that should not be interrupted by system
sleep. It also watches battery and thermal conditions without stopping your
work unexpectedly.

FreeThumb 是一款轻量级 macOS 菜单栏应用，可防止系统休眠，让本地 AI、构建、
下载和渲染等长时间任务持续运行；同时提供电池、温度与能耗监控，不会擅自中断任务。

## What it does

- Keeps macOS awake for 30 minutes, 1 hour, 2 hours, 4 hours, or until you stop it.
- Continues working while macOS is locked.
- Supports closed-lid operation and restores the previous sleep setting when
  protection ends.
- Shows battery, power source, Low Power Mode, lid, and thermal status.
- Offers optional system-pressure and battery temperature/power charts.
- Sends optional local, iMessage, Mail, or HTTPS webhook alerts.
- Records battery use, thermal pressure, and approximate foreground-app
  activity during a protection session.
- Supports ten interface languages and launch at login.

## Requirements

- macOS 13 or later
- Administrator approval the first time closed-lid protection is enabled

FreeThumb is distributed outside the Mac App Store because closed-lid display
control uses a private macOS framework.

## Download

Open [GitHub Releases](../../releases/latest) and download the package for your
platform. macOS and Windows packages are listed there when available.

On macOS, open the DMG and drag `FreeThumb.app` onto the Applications folder.
If macOS says it cannot verify FreeThumb, do not move it to Trash. After the
blocked launch, open **System Settings → Privacy & Security**, scroll to
Security, click **Open Anyway**, then confirm **Open**. Only override this check
for a package downloaded from this repository that you trust.

Prefer to build it yourself? Follow the steps below.

## Build from source

Install Xcode Command Line Tools if needed:

```sh
xcode-select --install
```

From the project directory, build and open the app:

```sh
./scripts/build-app.sh
open dist/FreeThumb.app
```

To create the drag-and-drop DMG:

```sh
./scripts/build-dmg.sh
```

FreeThumb appears as a thumb icon in the menu bar. It does not appear in the
Dock.

## Quick start

1. Click the thumb icon in the menu bar.
2. Choose a duration. Select `∞` to keep protection active until you stop it.
3. Click **Enable Sleep Prevention Mode**.
4. Approve the macOS administrator prompt on first use.
5. Lock your Mac with `Control-Command-Q`, or close the lid. Your task continues
   running.
6. Open FreeThumb and click **Disable Sleep Prevention Mode** when the task is finished.

Keep the Mac connected to power and the network when the task depends on them.
FreeThumb prevents sleep; it cannot prevent power loss, network loss, an app
crash, or a forced shutdown.

## Status icon

The thumb shape stays the same so its meaning remains easy to recognize. Its
color shows the current state:

| Color | Meaning |
| --- | --- |
| Gray | Protection is off |
| Green | Protection is active and conditions are normal |
| Yellow | A warning condition needs attention |
| Red | A critical condition or restoration error occurred |

## Settings and advanced features

Click the gear button at the bottom of the FreeThumb menu.

### General

- **Language:** follow macOS or choose English, Simplified Chinese, Japanese,
  Korean, Spanish, Hindi, French, Bengali, Portuguese, or Russian. Changes
  apply immediately.
- **Launch at login:** start FreeThumb automatically after signing in.
- **Menu bar monitoring:** show or hide the system-pressure chart, the combined
  battery temperature/power chart, and the estimated high-energy app list.
- **Check for updates:** enter a project-provided HTTPS release manifest URL,
  then check manually. FreeThumb never installs an update silently.

The charts sample every 30 seconds and retain up to 24 hours in memory. The
combined battery chart uses temperature on the left axis and battery power on
the right axis. Battery discharge power may be unavailable while connected to
AC power. The high-energy list includes only third-party apps run by the current
user and ranks them using a running average of the relative values reported by
macOS `top`, aggregated across each app's processes. It is not power measured
in watts. Sampling occurs every five minutes in the background and every minute
while the menu is open, only when this widget is enabled.

### Protection

Set battery warning and urgent thresholds, then choose which conditions should
raise an alert:

- AC power disconnected
- Low Power Mode enabled
- Sustained serious or critical thermal pressure
- Session approaching expiry

These conditions produce alerts only. They do not stop protection. Changes
apply the next time protection starts.

### Alerts

Local notifications are enabled by default. Other delivery channels are
optional:

- **iMessage:** requires an account already signed in to Messages.
- **Email:** uses an existing sending account in Mail.
- **HTTPS webhook:** sends a JSON `POST` to the configured HTTPS URL.

Use **Test local notification** or **Test enabled channels** before relying on
an alert. macOS may ask for Notification or Automation permission. Delivery
errors are shown in FreeThumb and never interrupt the protected task.

### Activity

Enable **Record activity statistics** to collect one sample per minute while
protection is active. The Activity tab shows:

- Session duration and battery percentage points used
- Battery-level history
- macOS thermal-pressure history
- Approximate foreground-app correlation

Foreground-app rows assign each interval to the app that was active at its
start. They do **not** measure that app's actual energy use. Disable activity
recording if you do not need these statistics.

## Why administrator approval is required

macOS requires administrator access to change its closed-lid sleep setting.
On first use, FreeThumb installs a narrowly scoped rule at
`/private/etc/sudoers.d/freethumb`. The rule only permits the current user to
run these two commands without repeated prompts:

```text
pmset disablesleep 0
pmset disablesleep 1
```

FreeThumb cannot read or store your password. A watchdog restores the normal
sleep setting if the app exits unexpectedly after changing it.

## Privacy and resource use

- Monitoring and activity data stay in memory on your Mac.
- Remote data is sent only through alert channels you explicitly enable.
- High-energy app estimates are disabled by default.
- Expensive process scanning runs only when that optional feature is enabled
  and the menu is visible.
- Routine monitoring uses bounded, low-frequency sampling.

## Troubleshooting

**Local notifications do not appear**

Open **Settings → Alerts**, click **Refresh Status**, and enable FreeThumb in
**System Settings → Notifications** if macOS has blocked it.

**Battery power shows unavailable**

Battery-side discharge power is normally unavailable while the Mac is powered
by its adapter.

**Protection does not start**

Open the FreeThumb menu and read the displayed error. Confirm the administrator
prompt was approved and that your macOS user account has administrator access.

**Normal sleep was not restored**

Stop protection from the menu first. If FreeThumb reports a restoration error,
run the following command in Terminal:

```sh
sudo pmset disablesleep 0
```

## Feedback

FreeThumb is not accepting development contributions. If you find a bug or
want to request a feature, please [open a GitHub Issue](../../issues).

## Roadmap

- [x] macOS menu bar app
- [x] Unlimited protection, monitoring, alerts, activity statistics, login item,
  localization, and manual update checks
- [ ] Windows version
