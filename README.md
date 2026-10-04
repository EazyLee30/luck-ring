<div align="center">

<img src="docs/images/banner.jpg" alt="Luck Ring" width="100%">

# Luck Ring

**A native iOS companion for a Bluetooth smart ring, built on Coolwear's closed-source BLE SDK.**

[![CI](https://github.com/EazyLee30/luck-ring/actions/workflows/ci.yml/badge.svg)](https://github.com/EazyLee30/luck-ring/actions/workflows/ci.yml)
[![Swift](https://img.shields.io/badge/Swift-5.9-F05138?style=flat-square&logo=swift&logoColor=white)](https://swift.org)
[![iOS](https://img.shields.io/badge/iOS-17.0%2B-000000?style=flat-square&logo=apple&logoColor=white)](https://developer.apple.com/ios/)
[![Xcode](https://img.shields.io/badge/Xcode-26.3-0B6FB8?style=flat-square&logo=xcode&logoColor=white)](https://developer.apple.com/xcode/)
[![License](https://img.shields.io/badge/license-MIT-2ED573?style=flat-square)](#license)
[![Stars](https://img.shields.io/github/stars/EazyLee30/luck-ring?style=flat-square&label=stars)](https://github.com/EazyLee30/luck-ring/stargazers)
[![Forks](https://img.shields.io/github/forks/EazyLee30/luck-ring?style=flat-square&label=forks)](https://github.com/EazyLee30/luck-ring/network/members)
[![Last commit](https://img.shields.io/github/last-commit/EazyLee30/luck-ring?style=flat-square)](https://github.com/EazyLee30/luck-ring/commits/main)

**English** · [简体中文](README.zh-CN.md)

</div>

---

<div align="center">

| Today | Sleep detail | Vitals |
|:---:|:---:|:---:|
| <img src="docs/images/today-top.png" width="230"> | <img src="docs/images/sleep-detail.png" width="230"> | <img src="docs/images/vitals.png" width="230"> |

| My Health | Your data | |
|:---:|:---:|:---:|
| <img src="docs/images/health.png" width="230"> | <img src="docs/images/data.png" width="230"> | |

</div>

<div align="center"><sub>Three tabs, mirroring the structure health apps converge on — screenshots from the demo target, no ring required</sub></div>

---

## What this is

A ring that speaks an undocumented BLE protocol, a vendor SDK that ships as a
closed arm64 binary, and no first-party app worth using. This is an iOS app built
from scratch on top of both.

**Today** leads with circular metric shortcuts, a large arc gauge, a serif headline
with a standfirst, anything that needs attention, and a timeline of what the ring
actually reported. **Vitals** groups every metric by health area with date
navigation; each score gets a status word and a dot placed on a min/max track.
**My Health** rates longer-term areas on four levels against a data requirement, and
says "not enough data" instead of guessing. Device controls live behind the ring icon.

Everything in the UI runs on real ring data. There is no server, no account, no
analytics. The app talks to the ring and nothing else.

## Highlights

<table>
<tr>
<td width="50%">

**Score gauges that explain themselves**
<br><br>
Sleep, Readiness and Activity out of 100 — with the contribution breakdown
shown underneath, not hidden behind a "learn more".

</td>
<td width="50%">

**Sleep reconstructed from raw packets**
<br><br>
The device sends a flat list of stage transitions. Sessions are reassembled,
and every score is traceable back to a packet.

</td>
</tr>
<tr>
<td>

**Runs in the simulator**
<br><br>
The vendor framework is arm64 device-only, so the domain layer sits behind a
protocol and a demo target fills it with generated data.

</td>
<td>

**Honest about uncertainty**
<br><br>
A rating computed from two nights is noise, so every health area declares its
data requirement and refuses to answer before it is met.

</td>
<td>

**Detail screens, not inline walls**
<br><br>
Tapping a score pushes a screen with the arc gauge, the contributor
breakdown, a stage timeline and a trend — instead of unfolding everything on
one scroll.

</td>
<td>

**Derived metrics, labelled as such**
<br><br>
Respiratory rate, a stress proxy, sleep regularity and recovery debt. Each
shows its caveat on tap, and returns nothing rather than guessing when its
inputs are missing.

</td>
<td>
<br><br>
`Editorial.swift` holds the primitives — arc gauge, range scale, segmented
indicator, hatched bar, editorial card. Patterns, not a traced copy.

</td>
</tr>
<tr>
<td>

</td>
</tr>
<tr>
<td>

**114 unit tests**
<br><br>
Score bounds swept across the input space, monotonicity, degenerate input, and
sleep-session assembly — the two places real bugs hid.

</td>
<td>

**Full packet capture**
<br><br>
Every frame in and out is recorded to JSONL and pulled off the device through
the Files app.

</td>
</tr>
</table>

## Quick start

```bash
brew install xcodegen
cd ios && xcodegen generate
```

**Iterate on the UI** — demo target, simulator, no ring needed:

```bash
xcodebuild -project LuckRing.xcodeproj -scheme LuckRingDemo \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```

**Run against a ring** — device target:

```bash
xcodebuild -project LuckRing.xcodeproj -scheme LuckRing \
  -destination 'generic/platform=iOS' build
```

Then open `ios/LuckRing.xcodeproj`, choose your signing team on the `LuckRing`
target, and run on device. First pairing asks you to tap the ring to confirm.

## Two targets, and why

`BluetoothLibrary.framework` reports `LC_BUILD_VERSION platform 2 (IOS)`,
`minos 13.0`, `sdk 26.0`, and `lipo` confirms it is **not a fat binary** — there
is no simulator slice. The device target therefore sets
`SUPPORTED_PLATFORMS = iphoneos` and simply refuses to build for the simulator.

| Target | Framework | Runs on | Purpose |
|---|:---:|---|---|
| `LuckRingDemo` | ✗ | Simulator | UI iteration, SwiftUI previews, screenshots, test host |
| `LuckRing` | ✓ | Device (arm64) | Real ring, embedded and signed |

The domain layer is plain Foundation behind a `RingBridge` protocol, so demo
data and real data drive identical views.

## How data actually flows

This is the single most important thing to know about the SDK, and the thing
that costs people days:

| Kind | How you get it |
|---|---|
| **Requestable** — device info, battery, alarms, user profile | `CE_RequestDevInfoCmd`, `CE_RequestBatteryCmd`, … |
| **Pushed** — steps, sleep, heart-rate history, HRV, temperature | there is **no request command**. Send `CE_SensorCmd(onoff: 1)` and the device uploads |

So "read the data" mostly means holding the sensor switch open, not issuing
commands. `DeviceRingBridge.postPairHandshake` opens it automatically after
pairing, and the Ring tab exposes it manually.

Sleep arrives as `(timestamp, stage)` transitions rather than sessions.
`SleepSession.assemble` rebuilds them — taking the **last** `SLEEP_WAKEUP` as
the session end, because there is normally an early awakening minutes after
falling asleep.

## Correctness

The score engine and sleep assembler are the parts most likely to be quietly
wrong, and neither needs hardware. `ios/Tests` covers them and CI runs the suite
on every push:

```bash
cd ios && xcodegen generate
xcodebuild -project LuckRing.xcodeproj -scheme LuckRingDemo \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test
```

```
Executed 114 tests, with 0 failures
```

Writing them found four real bugs, all now fixed with regression tests:

- **Overnight sleep never assembled.** A night starting before midnight had its
  post-midnight stages bucketed into *tomorrow*, so no session was ever built and
  every night read as missing.
- **Battery and firmware readings were dropped.** `ingest` skipped any record
  without a timestamp, which is every device-level record.
- **A bogus session from a stray transition.** The assembler had no
  `SLEEP_START` anchor, so an awake-first sequence produced a session.
- **No baseline without sleep.** A wearer with HRV and heart rate but no sleep
  record yet never got a baseline.

## Scoring model

Oura's algorithms are proprietary and unpublished. These are **our own**
heuristics, compared against a rolling 7-day `Baseline` so they mean something
per wearer rather than per population.

| Score | Breakdown |
|---|---|
| **Sleep** | duration 40 · efficiency 25 · deep-sleep band 20 · bedtime consistency 15 |
| **Readiness** | sleep 50 · HRV 25 · resting HR 15 · skin-temp deviation 10 |
| **Activity** | steps 50 · calories 30 · active time 20 |

Check the distributions and the session invariants without a device:

```bash
cd ios
swiftc -O Sources/Shared/Models.swift Sources/Shared/Scores.swift \
  Sources/Shared/DemoData.swift Sources/Shared/SeededRNG.swift \
  Tools/ScoreReport/main.swift -o /tmp/score-report && /tmp/score-report
```

```
sleep scores: avg 78  min 49  max 85
readiness:    avg 78  min 42  max 92
activity:     avg 75  min 9   max 100
all sessions consistent ✓
```

## Protocol notes

Recovered by disassembling `-[CE_K6Protocol constructData:funcType:cmdType:searialNumber:header:]`:

```
10-byte header
  [0]      0
  [1]      1
  [2]      packet count
  [3]      (serial % 255) + 1
  [4]      cmdType
  [5]      funcType
  [6..7]   0
  [8..9]   uint16 body length

packet 0 : 10-byte header + 10 body bytes
packet n : 1 index byte  + 19 body bytes      (20 bytes per frame)
```

Payload CRC for OTA/GPS is `crc_dspWithReg:dataCrc:` — poly `0x8005`, MSB-first,
init passed in, i.e. CRC-16/CCITT. The data framing itself carries no CRC.

## Layout

```
ios/
  project.yml                  xcodegen spec
  Sources/
    Shared/                    models · scoring · design system · store
    Views/                     Today / Trends / Ring
    Device/                    BLE bridge bound to the vendor SDK
    Demo/                      simulator entry point
    Previews/                  SwiftUI previews
    Shared/Editorial.swift      design-system primitives
  Tools/ScoreReport/           headless score + invariant harness
    Shared/Workouts.swift       workout model, MET maths, detection
    Shared/DerivedMetrics.swift estimates, with caveats
    Shared/HistoryStore.swift   atomic JSON persistence
    Shared/MotionResearch.swift IMU findings + packet inspector
    Shared/AppGroup.swift       widget snapshot + CSV export
    Shared/HealthExport.swift   Apple Health seam for both targets
  Widget/                      home-screen widget (4 families)
  Tests/                       114 cases across 7 suites
scripts/make-readme-assets.py  regenerates the banner and screenshot tiles
SDK/                           vendor docs, headers and demo project
```

## Gotchas

- **Shortcuts are not yet reorderable** — the catalogue and the three-slot
  minimum are modelled, but the drag-to-reorder gesture is not built.
- **First pairing requires tapping the ring.** Later connections auto-pair once
  the UUID is saved via `saveConnectedUUid`.
- **One BLE central at a time.** Close the vendor app first or the ring stays
  busy.
- **`CE_ClearDataCmd` erases history stored on the ring.** Guarded behind a
  confirmation dialog.
- Background streaming needs `UIBackgroundModes: bluetooth-central`.
- Scans are filtered on `version > 4 || isPairedSystem`, same as the vendor demo.
- The ring does not report REM as a distinct stage; `SleepStage.rem` exists in
  the model but the device never sends it.

## Building the device target

The demo target builds and runs with no setup. The device target needs two
capabilities enabled in your Apple Developer account before Xcode will sign it:

| Capability | Why | Without it |
|---|---|---|
| HealthKit | Apple Health export | The button reports the framework as unavailable |
| App Groups (`group.com.luckring.reader`) | the widget reads the app's snapshot | The widget shows placeholder data |

`project.yml` already declares both in `Support/LuckRing.entitlements`. Add them
to the App ID, regenerate the profile, and the device build signs. Everything else
— BLE background streaming included — is configured in the spec.

## Roadmap

- [x] Land the XCTest suites and run them in CI
- [x] Persist history to disk so data survives an app restart
- [x] HealthKit export
- [x] CSV export, storage accounting, local deletion
- [x] Home-screen widget
- [ ] Standalone BLE client that skips the vendor framework entirely
- [ ] iCloud sync of history between devices
- [ ] Ring-specific metrics once the firmware reveals them
      (`DATA_TYPE_HISTORY_TEMP`, `DATA_TYPE_SET_VALUABLE_ASSISTANT`)

## Credits

- [`BluetoothLibrary.framework`](SDK/) and the SDK documentation are
  **Coolwear / celink**'s. Not affiliated, not endorsed. Framework binaries are
  excluded from git — see [`.gitignore`](.gitignore).
- Visual design is our own. This is not affiliated with, endorsed by, or derived
  from Oura. The layout follows patterns common to health apps; the palette,
  typography, iconography and every line of code here are original.
- Scores are our own heuristics, not Oura's.

## License

[MIT](LICENSE) — see the third-party note at the bottom of that file.