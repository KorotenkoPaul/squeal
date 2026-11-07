# Squeal

Chat-fiction app: horror and thriller stories told as a text conversation, one message per tap.

- `legacy/` — the original 2018–2019 iOS app (Swift 4, UIKit, Firebase) and story manuscripts, imported from Google Drive. Secrets removed; see `legacy/SUMMARY.md` and `legacy/INVENTORY.md`.
- `content/convert.py` — converts the manuscripts (`Name` / `message` lines) into JSON; output in `content/stories/en/`.
- `web/` — web preview: `template.html` + `build.py` → `squeal-preview.html` (published as a private Claude artifact).

Next: new iOS app in SwiftUI with stories bundled locally (no Firebase), StoreKit 2 subscriptions, cloud builds.
