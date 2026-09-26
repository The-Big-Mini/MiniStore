# MiniStore

> SideStore with the interface sanded down

[![License: AGPL v3](https://img.shields.io/badge/License-AGPL%20v3-blue.svg)](https://www.gnu.org/licenses/agpl-3.0)
[![Nightly build](https://github.com/The-Big-Mini/MiniStore/actions/workflows/nightly.yml/badge.svg)](https://github.com/The-Big-Mini/MiniStore/actions/workflows/nightly.yml)

MiniStore is a fork of [SideStore](https://github.com/SideStore/SideStore), an alternative
app store that sideloads apps onto non-jailbroken iOS devices using only an Apple ID. It
resigns apps with your personal development certificate and refreshes them in the background
so the 7-day development period doesn't expire.

Everything SideStore does, MiniStore does. This fork is a thin layer of interface work on top
of upstream, deliberately small so that merging new SideStore releases stays routine rather
than becoming a rewrite. If you want the reference implementation, use SideStore. If you want
the same thing with the interface sanded down, use this.

## What MiniStore adds

- **OLED dark mode** — true-black backgrounds throughout, applied live without a relaunch.
- **Accent colour in the widget** — the colour picker itself is SideStore's. MiniStore mirrors
  the chosen colour into the app group so the home-screen widget can tint itself with it — the
  widget runs in its own process and cannot read the app's settings — and re-tints views that
  had already cached the old colour.
- **Reorganised settings** — the settings root is a list of eight categories (User
  Customizations, Refreshing Apps, Tech Things, Beta Testing, Advanced Settings, What's New,
  Experimental, Developer) rather than one long scroll, each with a leading icon. The category
  screens themselves are left plain; tiles on a leaf screen read as another index.
- **Tab customization** — hide the tabs you don't use, reorder them, and choose which one opens
  on launch.
- **App icon picker in settings** — the alternate-icon grid moved into User Customizations.
- **What's New** — release notes read live from this repo's GitHub releases, rendered in the app.
- **Its own recommended sources** — the list behind *Add Source* is MiniStore's, not
  SideStore's: 13 repos, several added and several of SideStore's dropped. The list lives in
  [`default-sources.json`](default-sources.json) and is fetched at runtime, so it can be changed
  without shipping a build.

MiniStore ships **no default sources**. Nothing appears in the Sources tab unasked except the
app's own update feed — the recommended list is a suggestion screen, and you pick from it.

## Installing

MiniStore updates itself through its own source, published by this repo's CI:

```
https://the-big-mini.github.io/MiniStore/source.json
```

That feed lists MiniStore only: it is the self-update channel, not an app catalogue. Stable,
nightly and alpha are release tracks *within* it, so switching channels is a toggle in
settings rather than a different URL.

Builds are attached to this repo's [releases](https://github.com/The-Big-Mini/MiniStore/releases).

## A note on the name

The app shows as **MiniStore** on your Home Screen and in the My Apps tab, but identifies
itself as **SideStore** over the wire.

This is deliberate and load-bearing. Pairing tools like
[iLoader](https://github.com/nab138/iloader) and
[idevice_pair](https://github.com/jkcoxson/idevice_pair) detect sideloaders by matching the
raw `CFBundleDisplayName` that `installation_proxy` reports against a hardcoded list, with no
bundle-identifier fallback. Renaming that key would make MiniStore invisible to them. The
Home Screen name comes from a localized `InfoPlist.strings` override instead, which those
tools never see.

For the same reason, the certificate is still registered under a `SideStore - …` machine
name. Renaming it would orphan every certificate already issued to your Apple ID.

## Requirements

- macOS with Xcode. CI builds with Xcode 26.4 on macOS 26; that is the only configuration
  this fork is verified against.
- iOS 15+ on the device (`IPHONEOS_DEPLOYMENT_TARGET = 15.0`).
- Clone with `--recurse-submodules`. Dependencies resolve as local Swift packages — no Rust
  toolchain and no CocoaPods are needed.

## Project overview

**MiniStore / AltStore target** — a regular sandboxed iOS app. The `AltStore` target holds
most of the functionality: downloading, signing, installing and refreshing apps, the four tab
screens, and the settings *root*, which is a static storyboard table. The `SideStore` target
holds the minimuxer bridge and the newer SwiftUI layer, including the individual settings
screens.

**`AltWidget`** — the Home Screen and Lock Screen widget extension. **`SideBackup`** — the
companion backup app, embedded as an IPA inside the main bundle. **`Shared`** — code compiled
into both the app and the widget.

**[minimuxer](https://github.com/SideStore/minimuxer)** — a lockdown muxer that runs inside
iOS's sandbox, replicating Apple's `usbmuxd` protocol so the app can talk to the device it is
running on. A git submodule, consumed as a local Swift package.

**[SideSign](https://github.com/SideStore/SideSign)** — Apple Developer API client and code
signing, also a submodule. It replaced AltSign upstream, and still vends `AltSign` as a module
name, so that name turns up in source even though the old submodule is gone.

## Building

```bash
make build      # xcodebuild ARCHIVE → SideStore.xcarchive
make fakesign   # ldid fake-sign with release entitlements
make ipa        # package the archive → MiniStore.ipa
```

`make build` performs an archive, not a plain build. Only the archive path runs the
SideBackup packaging phase, so a plain `xcodebuild build` can pass on code that fails CI.

Versions and identifiers live in `Build.xcconfig`. Don't hard-code bundle IDs. Local signing
overrides belong in `CodeSigning.xcconfig`, which is gitignored.

## Contributing

Bug reports and fixes that aren't MiniStore-specific belong
[upstream at SideStore](https://github.com/SideStore/SideStore): a fix merged there reaches
every user of both projects and costs this fork nothing to inherit.

[CONTRIBUTING.md](./CONTRIBUTING.md) is SideStore's, carried unchanged; parts of its setup
section predate the move to Swift packages and no longer apply here.

## Licensing

AGPLv3, inherited from SideStore. See [LICENSE](./LICENSE).

SideStore is itself a community fork of [AltStore](https://github.com/rileytestut/AltStore)
by Riley Testut. Credit for the foundation belongs to both projects.

## 🤖 AI SLOP DETECTED

Yes. Guilty.

<img src="screenshots/YouGotMe.jpg" alt="Walter White, hands raised: you got me" width="320">

MiniStore is developed with [Claude Code](https://claude.com/claude-code), running Opus 5
as the primary model. It writes the code, it writes the commit messages, and it wrote this
section. Which is a strange thing to be told by a README.

Every change is compiled by CI before it merges, and the diff against upstream is kept short
enough that a person can read all of it. That is the honest extent of the guarantee: CI proves
it builds, not that it behaves. Device testing is manual and not every change gets it.
