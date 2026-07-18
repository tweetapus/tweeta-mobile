# Tweeta Mobile

Native mobile clients for Tweetapus:

- `src/`: the C/GTK3 application for GNU/Linux phones such as PinePhone and
  Librem 5. Its layout is handset-first and there is no desktop build target.
- `android/`: the native Android application, written in Java with Android
  platform views and networking (no cross-platform UI framework).
- `iOS/`: the native iPhone application, written in SwiftUI with iOS 26 Liquid
  Glass and an iOS 17 material fallback.

The GNU/Linux and Android clients cover the same Tweetapus feature areas. The
iPhone client currently supplies the core timeline, composing, search,
notification, and profile experience while its server integration is brought
to parity.

The upstream Tweetapus server source in `tweetapus/` is reference-only and is
never built into or modified by any app.

## GNU/Linux phones

Required packages are GTK3, libhandy 1, libcurl, json-glib, GPGME, pkg-config,
and a C99 compiler. On Debian-derived mobile distributions:

```bash
sudo apt install build-essential pkg-config libgtk-3-dev libhandy-1-dev \
  libcurl4-openssl-dev libjson-glib-dev libgpgme-dev
make
./tweeta-mobile
```

Meson is also supported:

```bash
meson setup build
meson compile -C build
./build/tweeta-mobile
```

The installed package is `tweeta-mobile`; no `tweeta-desktop` executable or
parallel desktop target is produced. The UI defaults to a 390×760 phone window,
uses a compact header and bottom navigation, and keeps secondary destinations
in a touch-friendly menu.

Optional FIDO2 support can be enabled with `make USE_FIDO2=1` when `libfido2`
is installed. GPGME/GnuPG supplies the encrypted P2P messaging workspace.

## Android

Open `android/` in Android Studio and build the `app` configuration, or use the
installed Gradle 9.3.1. The project pins Android Gradle Plugin 9.1.1, whose
minimum/default Gradle version is 9.3.1:

```bash
cd android
gradle assembleDebug
```

The Android app requires API 26 or newer and targets API 35. It accepts only
HTTPS Tweetapus instances. Change the instance from **Menu → Settings → Change
server instance**; changing it signs out the current session.

## iPhone

The iPhone client is an xtool-compatible Swift package. It requires Swift 6
and a Darwin SDK built from Xcode. Once the SDK is installed, build it from the
`iOS/` directory:

```bash
./xtool-x86_64.AppImage sdk install /path/to/Xcode.xip
./xtool-x86_64.AppImage dev build
```

The app targets iOS 17 or newer. On iOS 26 it uses the native Liquid Glass APIs
for controls, cards, and navigation; older releases receive an equivalent
material treatment.

The iPhone client connects to the live Tweetapus API. It defaults to
`https://tweeta.tiago.zip`; add, remove, or switch HTTPS instances from
**Profile → Settings → Server instance**. Sign-in tokens are stored in the iOS
Keychain and kept separate for each instance.

## Custom Tweetapus instance on GNU/Linux

```bash
TWEETA_API_BASE_URL="https://example.org/api" \
TWEETA_BASE_DOMAIN="https://example.org" \
./tweeta-mobile
```

## Documentation and tests

```bash
make test
make docs
```

The canonical GNU/Linux phone manual is `tweeta-mobile.texi`.

(c) 2026 Lily — AGPLv3
