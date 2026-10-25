# Super Screen Lock

Set a daily screen time limit. When you hit it, every app locks until midnight, and opening one takes as many Face ID scans as you choose (1–50, default 10).

## How it works

All screen time counts toward the limit. You don't pick apps for that. The home screen shows today's total, drawn by a small report extension, because iOS only hands usage numbers to that kind of extension.

When the limit is reached, every app is covered by Super Screen Lock's lock screen. Tapping **Unlock with Face ID** sends a notification. Tap it, and Super Screen Lock opens the scan screen. Every scan needs its own tap of the Scan button, and each one is a fresh Face ID check, so iOS can't reuse an earlier match.

The lock screen can't run Face ID itself, because Apple doesn't allow it there. That's why the notification step exists.

After the last scan, either that app or all apps open, depending on **Scanning opens**, for the length you picked: 5, 10, 15 or 20 minutes, or a custom number from 1 to 240. Then they lock again. The lock resets at midnight.

iOS won't run a re-lock timer shorter than 15 minutes, so short unlocks use a 16-minute timer window that started in the past and ends exactly when the unlock does.

While the limit is used up, saving settings or turning the lock off takes the same scans.

**Open an app** (in the app, when Scanning opens is set to That app) asks which app first, then runs the scans. The same screen appears after tapping Unlock on a lock screen, because iOS only tells the lock screen buttons an app's category, and the extension that draws the lock screen isn't allowed to save anything.

The app picker is a grid of apps you've unlocked before, plus anything in Also lock, with an Other app tile for the system list. iOS doesn't give apps a list of recently used or open apps, so the grid learns from your unlocks.

**Start over if a scan fails** sends the count back to zero on any scan that doesn't pass, including a cancelled one.

**Also lock** covers the built-in apps that iOS leaves out when it locks everything, such as Safari and Files. Apps picked there are locked by name, which iOS honors even for its own apps.

**Block deleting apps** turns on iOS's "Deleting Apps: Don't Allow" restriction. iOS applies it to every app, not just this one. Turning it off takes Face ID or the passcode, or the full scans if today's limit is used up. Removing Super Screen Lock's Screen Time access in Settings lifts it, and TrollStore can still uninstall apps on its own.

## Install

The GitHub Actions workflow builds on every push to `main` and publishes `SuperScreenLock.ipa` to Releases. Open it with TrollStore.

The workflow is a thin wrapper around `ci/build.sh`, which does the real work: it builds the app, builds the screen-time report from its own spec (`report.yml`) so a problem there can't stop the app from building, copies the report into `Extensions/`, and signs every binary with its entitlements using ldid. Build changes go in the script, so the workflow file shouldn't need editing again.

Every binary is signed with an `application-identifier` (team `SUPERLOCK1`). A provisioning profile would normally add one; without it, iOS refuses to schedule the daily limit or any re-lock.

Free Apple ID sideloading (AltStore, Sideloadly) won't work. Those certificates can't carry the Family Controls entitlement that Screen Time requires.

## Trying it

Tap **Diagnostics and test lock** at the bottom of the home screen, then check **Test lock**. That locks everything right away, even if an unlock window is open, so you can try the full unlock flow without using up your limit.

The same screen has **Share debug log (.txt)** and **Copy debug log**, and the latest export is always in Files › On My iPhone › Super Screen Lock. The file starts with a status snapshot and then has everything the app and all three extensions logged, oldest first. The log itself is kept in `debug-log.txt` in the App Group container and trimmed to about a megabyte.

## Things to know

- **Unlocking one app vs. all apps.** When everything is locked, iOS tells the button handler the locked app's category, not the app itself. The lock screen's drawing extension records which app is on screen, and the scan screen uses that. If that record isn't available, the scans unlock all apps instead. The scan screen always shows what's about to open, and you can switch to all apps there.
- **iOS 17.0 to 17.3.** Usage counts from the moment you turn the lock on. On later days it counts from midnight. Changing the limit restarts that day's count. On iOS 17.4 and later, the whole day always counts.
- **iOS keeps some apps open.** The system apps in Settings › Screen Time › Always Allowed (Phone, Messages, FaceTime and Maps by default) can't be locked this way. Super Screen Lock itself never locks.
- **Always allowed limit.** iOS accepts up to 50 exceptions in total, so up to 40 always-allowed apps are kept.

## Layout

```
project.yml            XcodeGen spec (the .xcodeproj is generated in CI)
Config/                Info.plists and entitlements for all four targets
Sources/App            The app: setup, settings, scan screen, diagnostics
Sources/Shared         Settings, lock state and scheduling, used by every target
Sources/SharedUI       Palette and the dial drawing, used by the app and lock screen
Sources/LimitMonitor   Wakes at the limit, at midnight and when an unlock ends
Sources/ShieldLook     Draws the lock screen over a locked app
Sources/ShieldButtons  Handles the lock screen's buttons
Sources/ActivityReport Draws today's screen time (an ExtensionKit extension in Extensions/)
report.yml             XcodeGen spec for the report extension alone
ci/build.sh            Everything the workflow runs
Resources/             Asset catalog and app icon
```
