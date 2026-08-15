# Store page screenshots

These are served straight from this folder over `raw.githubusercontent.com` and listed in
`scripts/ci/source-template.json` under `app.screenshotURLs`, which is what renders the
screenshot strip on MiniStore's page in the app.

Expected filenames, exactly:

- `MiniStore-1.png`
- `MiniStore-2.png`
- `MiniStore-3.png`

**Case matters.** `raw.githubusercontent.com` is case-sensitive, so `Ministore-1.png` will
404 while the template asks for `MiniStore-1.png`. Adding, removing or renaming a screenshot
means editing the `screenshotURLs` array to match — nothing discovers this folder
automatically.

A missing file does not break the feed: `screenshotURLs` decodes as `[URL]`, which only
checks that the string parses, never that it resolves. The page renders with a blank slot
instead, so a typo fails quietly.

The app assumes 9:16 (750×1334) for entries given this way — see `StoreApp.init(from:)`,
which maps legacy `screenshotURLs` to that aspect ratio. Screenshots from a taller device
still display, but are letterboxed to fit.
