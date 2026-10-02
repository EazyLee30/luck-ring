# Luck Ring

iOS app for a Luck Ring, built on Coolwear's closed-source `BluetoothLibrary.framework`.

Three tabs: **Today** (three score gauges + detail cards), **Trends** (7-day charts), **Ring** (pairing, streaming, on-demand measurements, packet console).

```
ios/
  project.yml                  xcodegen spec — two targets
  Sources/
    Shared/                    domain models, scoring, design system, store
    Views/                     Today / Trends / Ring
    Device/                    BLE bridge bound to the vendor SDK
    Demo/                      simulator entry point
    Previews/                  SwiftUI previews
  Tools/ScoreReport/           CLI that checks score distributions headlessly
  Support/                     Info.plists
SDK/
  SDK/BluetoothLibrary.framework   vendor framework (binary gitignored, see below)
  coolwearsdkdemo-main 6/          vendor demo project + SDK docs
```

## Build

```bash
brew install xcodegen
cd ios && xcodegen generate
```

**Demo target** — runs in the simulator, no ring or vendor framework needed:

```bash
xcodebuild -project LuckRing.xcodeproj -scheme LuckRingDemo \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```

**Device target** — needs the vendor framework at `SDK/SDK/BluetoothLibrary.framework`:

```bash
xcodebuild -project LuckRing.xcodeproj -scheme LuckRing \
  -destination 'generic/platform=iOS' build
```

Then open `ios/LuckRing.xcodeproj`, pick your signing team on the `LuckRing` target, and run on the device.

### A note on the vendored binary

`BluetoothLibrary.framework` is proprietary Coolwear/celink code. `.gitignore` excludes the **binaries** but keeps the docs, headers and demo project. This is your call to reverse — uncomment those lines if you want the framework committed.

### iOS 27 / Xcode 26 note

The framework's Mach-O has `LC_BUILD_VERSION platform 2 (IOS)`, `minos 13.0`, `sdk 26.0`. Consequences:

- **arm64 device only.** `lipo` confirms it is not a fat binary and there is no simulator slice, so the device target sets `SUPPORTED_PLATFORMS = iphoneos`. The simulator will refuse it.
- Deployment target is set to 17.0 (well above the framework's 13.0 floor).
- Verified building with Xcode 26.3 against the iOS 26 SDK.

This is also why the demo target exists: the UI has to be iterable somewhere, and the simulator is the only somewhere available.

## Data model

The ring reports two very different kinds of data, and this is the single most important thing to know about this SDK:

| Kind | How you get it |
|---|---|
| **Requestable** — device info, battery, alarms, user profile | `CE_RequestDevInfoCmd`, `CE_RequestBatteryCmd`, … |
| **Pushed** — steps, sleep, heart-rate history, HRV, temperature | no request command exists. `CE_SensorCmd(onoff: 1)` and the device uploads |

So "read the data" is mostly about keeping the sensor switch open, not about issuing commands. `DeviceRingBridge.postPairHandshake` opens it automatically after pairing.

Sleep arrives as a flat list of `(timestamp, stage)` transitions, not as sessions. `SleepSession.assemble` rebuilds sessions from them — it takes the **last** `SLEEP_WAKEUP` as the session end, since there is typically an early awakening minutes after falling asleep.

Raw frames in both directions are captured via `CEProductK6.receiveOriginalDataHandler` / `sendOriginalDataHandler` and written to `Documents/captures/*.jsonl` (`UIFileSharingEnabled` is on, so pull them from the Files app).

## Scores

Sleep / Readiness / Activity are **our own heuristics**, not Oura's. Their algorithms are proprietary and unpublished; `Scores.swift` documents the weights. In short:

- **Sleep** (100) — duration 40, efficiency 25, deep-sleep band 20, bedtime consistency 15
- **Readiness** (100) — sleep 50, HRV 25, resting HR 15, skin-temp deviation 10
- **Activity** (100) — steps 50, calories 30, active time 20

Each compares against a 7-day `Baseline` rather than a population, so scores mean something per-wearer.

Check the distributions without a device:

```bash
cd ios && xcrun swiftc -O Sources/Shared/Models.swift Sources/Shared/Scores.swift \
  Sources/Shared/DemoData.swift Sources/Shared/SeededRNG.swift \
  Tools/ScoreReport/main.swift -o /tmp/score-report && /tmp/score-report
```

It prints the demo week, a 2000-day histogram, and asserts session invariants (asleep ≤ time in bed, efficiency in range, stage intervals summing to session duration).

## Protocol

Recovered from `-[CE_K6Protocol constructData:funcType:cmdType:searialNumber:header:]`:

- 10-byte header: `[0]`=0, `[1]`=1, `[2]`=packet count, `[3]`=(serial % 255)+1, `[4]`=cmdType, `[5]`=funcType, `[6..7]`=0, `[8..9]`=uint16 body length
- Packet 0 carries the header + 10 body bytes; each later packet is 1 index byte + 19 body bytes. 20 bytes per frame.
- CRC for OTA/GPS payloads is `crc_dspWithReg:dataCrc:` — poly `0x8005`, MSB-first, init passed in (i.e. CRC-16/CCITT). The data framing itself has no CRC.

Not done: a standalone client that speaks BLE directly without the vendor framework. GATT UUIDs aren't in the binary as plaintext.

## Gotchas

- **First pairing requires tapping the ring** to confirm. Automatic on later connects once the UUID is saved.
- Only one BLE central at a time — close the vendor app first.
- `CE_ClearDataCmd` erases history stored on the ring.
- Background streaming needs `UIBackgroundModes: bluetooth-central`.
- The vendor demo filters scans on `version > 4 || isPairedSystem`; so does this app.