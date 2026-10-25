# Super Screen Lock

Set a daily screen time limit. When you hit it, every app locks until midnight, and opening one takes as many Face ID scans as you choose (1–50, default 10).

## How it works

All screen time counts toward the limit. You don't pick apps for that.

When the limit is reached, every app is covered by Super Screen Lock's lock screen. Tapping **Unlock with Face ID** sends a notification. Tap it, and Super Screen Lock opens and runs the scans back to back. Each scan uses a fresh Face ID check, so iOS can't reuse an earlier match.

The lock screen can't run Face ID itself, because Apple doesn't allow it there. That's why the notification step exists.

After the last scan, the app you came from stays open for the window you picked (15, 30, 45 or 60 minutes), then locks again. The lock resets at midnight.

While the limit is used up, saving settings or turning the lock off takes the same scans.

## Install

The GitHub Actions workflow builds on every push to `main`, signs the app and its three extensions with their entitlements using ldid, and publishes `SuperScreenLock.ipa` to Releases. Open it with TrollStore.

Free Apple ID sideloading (AltStore, Sideloadly) won't work. Those certificates can't carry the Family Controls entitlement that Screen Time requires.

## Trying it

Tap **Diagnostics and test lock** at the bottom of the home screen, then check **Test lock**. That locks everything right away, so you can try the full unlock flow without using up your limit. The same screen shows a log from the app and all three extensions.

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
Resources/             Asset catalog and app icon
```
