# FocusGuard — The Digital Study Warden (Android)

Offline-first, on-device AI study proctor built with Flutter, ML Kit, and a native Android anti-tamper lock engine.

## What's Included
- **On-device AI proctor (`lib/services/vision.dart`)**: Captures a silent still frame on your chosen interval, classifies Study / Neutral / Distracted / Absent via ML Kit, and immediately deletes the frame.
- **Anti-Tamper Lock Engine (`android_overlay/.../LockStore.kt`, `BlockerService.kt`)**:
  - **Clock-change proof**: Uses Android's monotonic `SystemClock.elapsedRealtime()` so changing Date & Time never bypasses a lock.
  - **Uninstall protection**: Opt-in Device Administrator (`FocusAdminReceiver.kt`) blocks deleting FocusGuard.
  - **Settings / Force-Stop / Accessibility guard**: Intercepts tamper screens in Android Settings while a lock is active.
  - **Reboot & Background proof**: `BootReceiver.kt` + `LockGuardService.kt` foreground service persist locks across restarts and OEM battery killers.
- **Zero-PC Cloud APK Builder (`.github/workflows/build-apk.yml`)**: Push this folder to any GitHub repo and GitHub Actions compiles `app-release.apk` and `app-arm64-v8a-release.apk` automatically.

## Phone + GitHub Build Steps
1. Upload the contents of this folder to the root of your GitHub repository (including `.github/workflows/build-apk.yml`).
2. Open your repo on GitHub -> **Actions** tab -> **Build FocusGuard APK** -> **Run workflow** (or it triggers automatically on push).
3. Wait ~4 minutes for the green checkmark, tap the run, scroll to **Artifacts**, and download **FocusGuard-APK**.
4. Unzip and install `app-arm64-v8a-release.apk` (smaller, faster) or `app-release.apk` on your Android phone.
5. On Android 13+: go to **Settings -> Apps -> FocusGuard -> three dots (top right) -> Allow restricted settings**, then enable **FocusGuard Lock** in Accessibility settings, **Uninstall Guard**, and **Background Battery Whitelist** inside the app's **Rules** tab.
