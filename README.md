# MiniStore

> SideStore with UI upgrades and preloaded sources

[![License: AGPL v3](https://img.shields.io/badge/License-AGPL%20v3-blue.svg)](https://www.gnu.org/licenses/agpl-3.0)
[![Nightly build](https://github.com/The-Big-Mini/MiniStore/actions/workflows/nightly.yml/badge.svg)](https://github.com/The-Big-Mini/MiniStore/actions/workflows/nightly.yml)

MiniStore is a fork of [SideStore](https://github.com/SideStore/SideStore), an alternative
app store that sideloads apps onto non-jailbroken iOS devices using only an Apple ID. It
resigns apps with your personal development certificate and refreshes them in the background
so the 7-day development period doesn't expire.

Everything SideStore does, MiniStore does. This fork is a thin layer of interface work and
preloaded sources on top of upstream, deliberately small so that merging new SideStore
releases stays routine rather than becoming a rewrite. If you want the reference
implementation, use SideStore. If you want the same thing with the interface sanded down,
use this.

## What MiniStore adds

- **OLED dark mode** — true-black backgrounds throughout, applied live without a relaunch.
- **Accent colour in the widget** — the colour picker itself is SideStore's. MiniStore carries
  the chosen colour into the home-screen widget, which runs in its own process and cannot see
  the app's settings, and re-tints views that had already cached the old colour.
- **Reorganised settings** — the settings root is a list of categories (Display, Refreshing
  Apps, Tech Things, Beta Testing, Advanced) rather than one long scroll, with a leading icon
  on every row.
- **Tab customization** — hide the tabs you don't use, and choose which one opens on launch.
- **What's New** — release notes pulled live from this repo's GitHub releases, rendered in
  the app.
- **Preloaded source** — [Mini's Repo](https://OofMini.github.io/Minis-Repo/mini.json) is
  seeded on first launch, so there's a catalogue to browse immediately.
- **Its own recommended sources** — the list behind *Add Source* is MiniStore's, not
  SideStore's. Several repos have been added to it, and some of the ones SideStore ships have
  been dropped: a few had gone dead, and one was large enough on its own to hold up the whole
  screen while it loaded. The list lives in [`default-sources.json`](default-sources.json) and
  is fetched at runtime, so it can be changed without shipping a build.

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

- Xcode 15+
- iOS 15+
- Rustup (`brew install rustup`) — for building minimuxer

## Project overview

**MiniStore / AltStore target** — a regular sandboxed iOS app. The `AltStore` target holds
most of the functionality: downloading, signing, installing and refreshing apps. The
`SideStore` target holds the minimuxer bridge and the newer SwiftUI layer, including all of
settings.

**[minimuxer](https://github.com/SideStore/minimuxer)** — a lockdown muxer that runs inside
iOS's sandbox, replicating Apple's `usbmuxd` protocol so the app can talk to the device it is
running on. Consumed as a git submodule and built via Rust.

**[AltSign](https://github.com/SideStore/AltSign)** — Apple Developer API client and code
signing. Also a submodule.

## Building

```bash
make build      # xcodebuild ARCHIVE → SideStore.xcarchive
make fakesign   # ldid fake-sign with release entitlements
make ipa        # package the archive → SideStore.ipa
```

`make build` performs an archive, not a plain build. Only the archive path runs the
SideBackup packaging phase, so a plain `xcodebuild build` can pass on code that fails CI.

Versions and identifiers live in `Build.xcconfig`. Don't hard-code bundle IDs. Local signing
overrides belong in `CodeSigning.xcconfig`, which is gitignored.

## Contributing

Bug reports and fixes that aren't MiniStore-specific belong
[upstream at SideStore](https://github.com/SideStore/SideStore): a fix merged there reaches
every user of both projects and costs this fork nothing to inherit. See
[CONTRIBUTING.md](./CONTRIBUTING.md) for build and PR conventions.

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

Nothing ships without being built and run on a real device first, and the diff against
upstream is kept short enough that a person can read all of it. So if something in here is
broken, a human merged it.
