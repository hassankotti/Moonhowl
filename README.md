# Moonhowl

A social deduction game (wolves vs. villagers) for Android and iOS that runs
**entirely on your local Wi-Fi, with no internet**. One player opens a room on their
phone; everyone else joins from their own phone on the same network. There are no
accounts and no sign-in: each player's profile lives only on their device.

The app is available in Arabic (right-to-left, the default) and English.

## Features

- **Local profile:** name, avatar (emoji on a color, or a photo), and personal stats
  (games played, wins, win rate, most-played role).
- **Phone-hosted rooms:** the host's phone runs the game server itself. No other
  hardware is needed.
- **Joining:** rooms show up automatically on the same network. Players can also scan
  the room's QR code or type its address.
- **Roles:** Villager, Wolf, Seer, Guardian, Witch, Hunter, Mayor, Jester.
- **Balanced role setup:** roles are picked automatically for the number of players,
  or the host chooses them.
- **Game flow:** night → (witch) → day discussion → vote → (hunter's shot), with a
  timer for every phase.
- **Narrator:** an automatic narrator describes what happens and tells each player
  what to do for their role. Alternatively, the host can act as narrator without a role.
- **What each player sees:** only their own role. Wolves see each other. Roles can be
  revealed on death, and dead players can see every role (both optional).
- **Chat:** village square, a secret wolf den, a graveyard for the dead, private
  messages, and group chats players create themselves.
- **Host tools:** pause, skip phase, lock the room, room password, remove a player.
- **Automatic reconnect:** if a player's Wi-Fi drops, they get back to the same seat
  and role.
- **Atmosphere:** sounds for night, day and deaths, vibration on your turn, and a dark
  night-themed interface.

## Repository layout (monorepo)

```
apps/mobile/          Flutter app (Android + iOS)
packages/howl_core/   Game rules: roles, phases, voting, win conditions, chat permissions, wire protocol (pure Dart)
packages/howl_net/    LAN host server and client over WebSocket (dart:io only)
tool/check.sh         Analyze and test every package
```

The repo is a [pub workspace](https://dart.dev/tools/pub/workspaces): one
`flutter pub get` at the root resolves every package.

- `howl_core` holds the only copy of the rules. It is pure Dart with an injected
  clock, so the whole game is unit-tested without a phone.
- `howl_net` runs on the host's phone: an `HttpServer` with a WebSocket endpoint
  (`/ws`) and a status endpoint (`/info`). Every player, the host included, connects
  as a client and receives a view filtered to what their role may know.
- `apps/mobile` is the UI. Rooms are announced with Bonjour/NSD (`_moonhowl._tcp`)
  and shared as a QR code (`moonhowl://<ip>:<port>`).

## Getting started

Requires Flutter 3.47 or later.

```bash
flutter pub get
cd apps/mobile
flutter run            # on a connected phone or emulator
```

- **Android:** `flutter build apk --release`
- **iOS:** requires a Mac with Xcode. Run `cd apps/mobile && flutter build ios`, then sign the app in Xcode.

### Thmanyah font (optional)

The app uses the [Thmanyah Sans](https://font.thmanyah.com) font when its files are
present, and the system font otherwise. Its license allows **personal use only** and
does not allow redistributing the files, so they are not in this repo.

1. Download Thmanyah Sans from [font.thmanyah.com](https://font.thmanyah.com).
2. Copy its `.ttf` or `.otf` files (Sans only) into `apps/mobile/assets/fonts/`.
3. Rebuild the app. Git ignores that folder, so the files are never committed.

Check the license before shipping a build to other people or to an app store.

To run all analyzers and tests:

```bash
./tool/check.sh
```

## Releasing

Store builds, signing and the App Store / Google Play steps are in
[docs/RELEASING.md](docs/RELEASING.md). Store listing copy is in `docs/store/`
and the privacy policy is published from `docs/` via GitHub Pages.

## Notes

- The host must keep the app open during the game, because the whole game runs on
  their phone. The screen stays on automatically while hosting.
- On iOS, the system asks for **Local Network** permission the first time. It must be
  allowed to host or join.
- The host's phone hotspot works in place of a Wi-Fi router.
- If a room doesn't appear in the list (some networks block discovery), scan the QR
  code or type the address shown on the host's screen.
