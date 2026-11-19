# LAVPNFix

**VPN consent fix for tether-downgraded A12/A13 devices** (surrealra1n etc.)

Tether downgrades from iOS 26/27 to iOS 15.x leave the device with a **newer SEP
than the OS**, which silently breaks LocalAuthentication. As a result, granting
consent for third-party VPN apps (NetworkExtension packet tunnels — Happ, Shadowrocket,
Stash, WireGuard-based apps and others) fails: the "Allow" dialog appears, you tap
Allow — and the app bounces you back with `permission denied` and no VPN profile is
ever saved. The stock Settings → "Add VPN Configuration" (Personal VPN) path keeps
working, which is what makes this fixable in userspace.

This tiny tweak hooks `LAContext` **inside `nehelper`** and grants the consent
evaluation locally, without touching the SEP. No kernel patches, no rootfs changes,
fully reversible.

## Root cause (from syslog)

```
Happ(NetworkExtension)[1139] <Error>: Failed to save configuration Happ:
    Error Domain=NEConfigurationErrorDomain Code=10 "permission denied"
Happ(NetworkExtension)[1139] <Error>: Failed to save configuration:
    Error Domain=NEVPNErrorDomain Code=5 "permission denied"

coreauthd[916] <Info>: returning Error Domain=com.apple.LocalAuthentication Code=-1000
    "ACMContextCreate failed: -536870199"

nehelper(NetworkExtension)[840] <Error>: Device cannot evaluate Local Authentication
```

Chain: app asks for consent → `nehelper` creates `LAContext` → `coreauthd` tries to
allocate an auth context via the SEP → the downgraded-OS / newest-SEP mismatch fails
with `ACMContextCreate failed` → consent is refused → `permission denied` →
the app loops you between Settings and itself forever.

Nothing crashes — it is a clean refusal. `nesessionmanager` is alive and can save
configurations (manual IKEv2 profiles in Settings work fine). Only the consent
evaluation path is broken, so we fake exactly that.

## What it does

Loads into `nehelper` (filter plist) via ElleKit/Substrate and overrides:

- `-[LAContext canEvaluatePolicy:error:]` → returns `YES`
- `-[LAContext evaluatePolicy:localizedReason:reply:]` → calls `reply(YES, nil)`

All it does is skip the broken SEP-backed consent check. VPN profiles are still
stored by the untouched, fully working `nesessionmanager`.

Tag lines in syslog start with `[LAVPNFix]` so you can verify it loaded.

## Tested on

| | |
|---|---|
| Device | iPhone 11 (iPhone12,1, A13, n104ap) |
| OS | iOS 15.6.1 (19G82), tethered downgrade via surrealra1n 2.2.6 |
| SEP/baseband | iOS 27.2.1 (24B156) |
| Jailbreak | Dopamine 3.0.12-fix (pwnerblu fork), ElleKit |
| Package scheme | rootless (`/var/jb`) |
| Result | Third-party VPN consent granted, tunnel saves and connects ✅ |

Should also apply to A12 devices and other tether downgrades where
`LAContext` fails with `-1000` / `ACMContextCreate failed`. Report results in Issues.

## Install (jailbroken, Dopamine rootless)

**Option A — no repo needed:**

1. Download the latest `.deb` from [Releases](https://github.com/MakrSas/LAVPNFix/releases)
   onto the device (Safari / AirDrop / any transfer)
2. Install with Filza (tap the deb → Install), or from a terminal:
   ```
   dpkg -i /var/mobile/Documents/com.user.lavpnfix_1.0.1_iphoneos-arm64.deb
   ```
3. Respring / userspace reboot so `nehelper` picks it up (Dopamine → Respring,
   or `launchctl reboot userspace`)

**Option B — build from source:** see below.

Removing: uninstall via Sileo (`com.user.lavpnfix`) or `dpkg -r com.user.lavpnfix`.

## Build

Requires [theos](https://theos.dev) with an iOS SDK:

```
export THEOS=~/theos
cd LAVPNFix
make package FINALPACKAGE=1
```

The Makefile sets `THEOS_PACKAGE_SCHEME = rootless`. For a rootful jailbreak
(remove that line and rebuild) the tweak itself is identical — only install
paths differ.

## Important limitations

- This does **not** fix the SEP. Passcode / Face ID / Touch ID remain broken and
  **setting a passcode on tether-downgraded A12/A13 still panics (skg/skgs)** —
  don't.
- Only the consent gate is bypassed. If your VPN app fails *after* the profile is
  saved (tunnel won't start), that's a different problem.
- Tested with ElleKit (Dopamine). Substrate-based setups should behave the same.

## Credits

- [opa334](https://github.com/opa334) — Dopamine, ElleKit
- [pwnerblu](https://github.com/pwnerblu) — surrealra1n and the Dopamine downgrade fork
- [mineek](https://github.com/mineek) — seprmvr64
- Theos team

## License

MIT — see [LICENSE](LICENSE).
