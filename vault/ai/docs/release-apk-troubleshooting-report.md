# Release APK Troubleshooting Report
**Status:** INVESTIGATED  
**Date:** 2026-03-27  
**Reporter:** OpenCode orchestrator  
**Symptom:** Release APK downloaded from GitHub installs or is reported invalid on a real Android phone; app does not launch successfully.

---

## 1. Executive Summary

The initial production issue was real: the GitHub release asset for `v1.0.0` was broken for ARM devices.  
After deeper investigation, the problem turned out to have **two layers**:

1. **Original release asset was invalid for ARM runtime**
   - Embedded ARM `libflutter.so` entries were corrupted to `24` bytes.
   - Result: installs on ARM phones but crashes immediately on launch.

2. **Subsequent no-strip workaround produced mixed outcomes**
   - Some rebuilt APKs contained valid ARM native libraries but failed APK signature verification.
   - Some split-per-ABI APKs were validly signed and installable, but on the target Vivo/Android 15 device the system still extracted `/data/data/com.example.kindwords/app_lib/libflutter.so` as an invalid file before app start.

**Final conclusion:**
- The first GitHub release APK was definitely bad.
- The device-specific failure was reproduced even with later valid ARM64 APKs.
- The remaining blocker appears to be a **device/runtime native-lib extraction issue on the target Vivo Android 15 build**, not a Dart/runtime app-logic bug.

---

## 2. Environment

### Project / build environment

| Item | Value |
|------|-------|
| Project | `kindwords` |
| Flutter | `3.41.5` stable |
| Engine | `052f31d115` |
| Dart | `3.11.3` |
| Android SDK | `36.0.0` |
| Build host | Pop!_OS 22.04 |

### Device under test

| Item | Value |
|------|-------|
| Model | `V2314A` |
| Build | `PD2314_A_15.2.16.0.W10` |
| Android version | `15` |
| API level | `35` |
| CPU ABI | `arm64-v8a` |
| Connection | ADB over USB |

### App identity

| Item | Value |
|------|-------|
| Package | `com.example.kindwords` |
| Installed version tested | `1.0.0` |

---

## 3. Original User-Visible Problem

User report:
- Downloaded APK from GitHub release on phone
- Phone reported invalid package or app crashed after install

Initial real-device crash log:

```text
java.lang.UnsatisfiedLinkError: dlopen failed:
"/data/data/com.example.kindwords/app_lib/libflutter.so"
is too small to be an ELF executable: only found 24 bytes
```

This proved the failure happened before Flutter/Dart app code executed.

---

## 4. Evidence Collected

### 4a. Original GitHub release asset (`app-release.apk`)

Metadata observed:

| Item | Value |
|------|-------|
| Filename | `app-release.apk` |
| Size | `32,130,106` bytes (~32 MB) |
| SHA-256 | `4119cdc63d948231b6516d0d59cde7c75f83d31a42a7d3698605e3f6c635d100` |

Embedded `libflutter.so` sizes inside the uploaded release asset:

| ABI | Size | Result |
|-----|------|--------|
| `arm64-v8a` | `24` bytes | ❌ corrupted |
| `armeabi-v7a` | `24` bytes | ❌ corrupted |
| `x86_64` | `12,564,656` bytes | ✅ valid |

Interpretation:
- Emulator / x86_64 path may work
- Real ARM phones will crash immediately

### 4b. Initial fixed local APK attempt

Rebuilt local APK metadata:

| Item | Value |
|------|-------|
| Filename | `build/app/outputs/flutter-apk/app-release.apk` |
| Size | ~`427 MB` |
| SHA-256 | `27d925c9da059d2cf288f9d3fcb5e8da0d3352c6d16db866989db3d0f2059490` |

Embedded `libflutter.so` sizes:

| ABI | Size | Result |
|-----|------|--------|
| `arm64-v8a` | `146,795,256` | ✅ valid |
| `armeabi-v7a` | `133,815,712` | ✅ valid |
| `x86_64` | `147,375,784` | ✅ valid |

But `apksigner verify` reported:

```text
DOES NOT VERIFY
APK Signature Scheme v2 signer #1: APK integrity check failed
CHUNKED_SHA256 digest mismatch
```

So this artifact had valid ARM contents but was **not safely releasable**.

---

## 5. Full Timeline Of What Was Tried

### Attempt 1 — Inspect live device crash

Actions:
- Confirmed device connected over ADB
- Launched installed app
- Captured `logcat`

Result:
- Crash before Flutter UI
- Root cause: corrupted ARM `libflutter.so` extracted on device

### Attempt 2 — Compare local build vs GitHub release asset

Actions:
- Downloaded release asset from GitHub
- Compared file size, checksum, embedded ARM libs

Result:
- Confirmed GitHub release `app-release.apk` was definitely the bad pre-fix asset

### Attempt 3 — Replace GitHub release APK with rebuilt APK

Actions:
- Uploaded rebuilt large APK
- Downloaded it again for verification

Result:
- Replacement asset matched local bytes exactly
- But Android install rejected it:

```text
INSTALL_PARSE_FAILED_NO_CERTIFICATES
APK Signature Scheme v2: SHA-256 digest of contents did not verify
```

Conclusion:
- The replacement release asset itself was not validly signed.

### Attempt 4 — Verify signing locally with `apksigner`

Actions:
- Ran `apksigner verify -v` on rebuilt APKs

Result:
- Large no-strip APK variants failed signature verification.

Conclusion:
- Not safe to release those artifacts.

### Attempt 5 — Build split-per-ABI release APKs

Actions:
- Ran `flutter build apk --release --split-per-abi --no-tree-shake-icons`

Observed outputs:

#### 5a. Stripped split APKs

| Artifact | Size | Signature | ARM libflutter | Result |
|----------|------|-----------|----------------|--------|
| `app-arm64-v8a-release.apk` | ~7.2 MB | ✅ valid | `24` bytes | ❌ unusable |

Conclusion:
- Signing was fine, but ARM runtime was still broken.

#### 5b. Unstripped split APKs (`keepDebugSymbols`)

| Artifact | Size | Signature | ARM libflutter | Result |
|----------|------|-----------|----------------|--------|
| `app-arm64-v8a-release.apk` | ~148 MB | ✅ valid | full-size | ✅ best candidate |

This was the first artifact that was both:
- validly signed
- contained a valid ARM64 `libflutter.so`

### Attempt 6 — Install valid ARM64 split APK to device

Methods tried:
- `adb install -r ...`
- `adb install --no-streaming ...`
- fresh uninstall → reinstall

Results:
- APK installed successfully
- app still crashed at launch on device

Crash signature:

```text
dlopen failed:
"/data/data/com.example.kindwords/app_lib/libflutter.so"
has bad ELF magic: 00000000
```

Interpretation:
- APK itself is valid
- device-side extraction or load path is still producing a broken file in `app_lib`

### Attempt 7 — Make `BootReceiver` fail-safe

Reason:
- boot receiver also tried to start a headless Flutter engine and crashed on native load failure

Action:
- wrapped `BootReceiver.onReceive()` in `try/catch` and log-only failure

Result:
- boot receiver crash stopped being process-fatal
- main activity still crashed independently on native library load

### Attempt 8 — Force `android:extractNativeLibs="false"`

Reason:
- try to make Android load directly from APK instead of extracting native libs

Action:
- added `android:extractNativeLibs="false"` in manifest

Result:
- installed package metadata confirmed `extractNativeLibs=false`
- device still attempted to load `/data/data/com.example.kindwords/app_lib/libflutter.so`
- crash persisted

Conclusion:
- vendor runtime appears to ignore or override this path for this app/build/device combination

### Attempt 9 — Legacy JNI packaging experiment

Action:
- added `useLegacyPackaging = true`

Result:
- some Flutter-copied outputs regressed into signature-invalid artifacts
- direct Gradle ARM64 artifact still validated
- device still crashed the same way after install

Conclusion:
- did not resolve Vivo native extraction/load issue

### Attempt 10 — Build AAB path

Action:
- tried `flutter build appbundle --release --no-tree-shake-icons`

Results:
- bundle packaging failed with ZIP/CRC errors:

```text
java.util.zip.ZipException: invalid entry crc-32
java.util.zip.ZipException: ZipFile invalid LOC header (bad signature)
```

Conclusion:
- AAB path is not currently reliable on this build machine/state either

---

## 6. Root-Cause Layers

### Layer A — confirmed release artifact bug

The first GitHub release APK was definitely wrong for ARM devices.

**Evidence:** ARM `libflutter.so` entries were 24 bytes.

### Layer B — device/runtime extraction issue

Even with a validly signed, valid ARM64 split APK, the Vivo device still failed before Flutter startup because Android attempted to load:

```text
/data/data/com.example.kindwords/app_lib/libflutter.so
```

and the file appeared corrupted (`bad ELF magic: 00000000`).

This means the problem is no longer just "bad APK uploaded" — it extends to the device's handling of the installed native library for this sideloaded build.

---

## 7. Current Repo State

### Committed changes

Committed during investigation:

| Commit | Purpose |
|--------|---------|
| `3e9e4d0` | `fix(android): keep libflutter.so symbols to prevent ARM release APK corruption` |

### Reverted experiments

These were tested but **not left in the repo**:
- `android:extractNativeLibs="false"`
- `BootReceiver` `try/catch` fail-safe wrapper
- `useLegacyPackaging = true`

Working tree was restored clean after experiments.

---

## 8. Current GitHub Release State

At the time of this report:

- `v1.0.0` release history has been manipulated during troubleshooting
- At least one original asset was definitely bad
- At least one replacement asset was signature-invalid
- Therefore the release page should be treated as **not trustworthy until a fresh verified-good artifact is published**

**Recommendation:** do not tell users to download `v1.0.0` until a new verified asset is installed successfully on a real ARM device.

---

## 9. Strongest Conclusions

1. **The bug is real and reproducible.**  
   It is not user error.

2. **The first release asset was objectively broken.**  
   ARM native libraries were corrupted in the uploaded APK.

3. **A valid ARM64 APK can be produced locally.**  
   Split-per-ABI ARM64 artifacts passed `apksigner` and ZIP integrity checks.

4. **The target Vivo/Android 15 device still fails with valid APKs.**  
   So the remaining blocker is in the install/runtime native-lib extraction path on that device.

5. **This is not a Dart/UI/business-logic crash.**  
   The app never reaches Flutter initialization.

---

## 10. Recommended Next Steps

Ordered by signal value:

### Option 1 — Test on a second physical Android device

**Why:** fastest way to determine whether this is Vivo-specific.

Pass condition:
- same valid ARM64 split APK installs and launches normally on another ARM Android device

If it passes:
- issue is highly likely vendor/device specific

### Option 2 — Use `flutter run --release` directly to device

**Why:** uses a different deployment path than sideloaded APK install.

What it answers:
- whether the app code itself is healthy on the device when deployed by Flutter tooling

### Option 3 — Set up proper release signing

**Why:** current builds still use debug signing. A real keystore is needed anyway for production hygiene.

What it may change:
- device/install behavior for final release packaging
- future Play internal testing path

### Option 4 — Publish through Google Play Internal Testing

**Why:** Play delivers split APKs/App Bundle artifacts via the store-managed path instead of raw sideload installation.

This is the strongest realistic release test for the Vivo device.

---

## 11. Final Recommendation

For the next sprint / release-management task:

1. create a proper Android release keystore
2. configure release signing in Gradle
3. build an `.aab`
4. upload to Google Play Internal Testing
5. install from Play on the Vivo device

This is the best path to separate:
- sideload-specific native extraction issues
- app/runtime issues
- signing/distribution issues

Until that is done, the project should consider the public `v1.0.0` release **not yet validated on real ARM hardware**.
