# PocketDesk phone app

Flutter app that turns your phone into a touchpad and keyboard for the PocketDesk
desktop agent. The iPhone is the main target; Android still builds.

```bash
flutter test
flutter run                         # phone connected over USB with USB debugging on
flutter build apk --release --split-per-abi   # Android (not a goal, kept compiling)
```

### iPhone

There is no Mac here: the iPhone app is built by GitHub Actions
(`.github/workflows/ios.yml`) on a Mac runner as an unsigned `PocketDesk.ipa`, and
installed with Sideloadly and a free Apple ID (see the top-level README). The
`ios/` project is committed and can be edited on any machine; on a Mac:

```bash
flutter build ios --release --no-codesign
```

The app icons are rendered in CI from `../packaging/icons/pocketdesk-ios.svg` by
`tool/ios_icons.sh` (needs `sips` and `rsvg-convert`).

App ID: `me.lapalu.pocketdesk` (must never change after the first public release).

| File | What it does |
| --- | --- |
| `lib/agent_connection.dart` | Pinned-TLS WebSocket, sign-in handshake, protocol messages |
| `lib/pairing/` | QR link parsing, phone key (Ed25519), saved computers, network discovery |
| `lib/app_model.dart` | App-wide state |
| `lib/touchpad_gestures.dart` | Finger events → move / click / scroll (pure Dart, unit-tested) |
| `lib/touchpad.dart` | Touchpad and hold-to-drag button widgets |
| `lib/screens/` | Home (paired computers), QR scanner, settings, button editor |
| `lib/screens/tabs/` | Control screen tabs: buttons, apps, power |
| `lib/buttons/` | Custom button model, defaults and storage |
| `lib/settings/` | Phone settings and the app lock |
| `lib/ui/pocket_style.dart` | The design: colours, theme, pill header, wordmark, corner action |
| `packages/pocketdesk_ios/` | iPhone-only native plugin for the `pocketdesk/files` channel (Swift) |
| `ios/` | The Flutter iOS project (bundle id `me.lapalu.pocketdesk`) |

The QR scanner uses ZXing, not Google ML Kit, so the app has no proprietary
dependencies (needed for F-Droid).

See [../docs/PROTOCOL.md](../docs/PROTOCOL.md) for the messages.
