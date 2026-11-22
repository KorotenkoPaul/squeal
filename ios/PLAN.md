# Squeal for iPhone — port plan (started 2026-11-22)

Goal: a native SwiftUI app that looks and behaves exactly like the web prototype
(`web/template.html`, built into `web/squeal-preview.html` by `python3 web/build.py`).
The web prototype is the spec. Every fix in `BUGS.md` and every owner decision in
`IDEAS.md` → «Решения по интерфейсу — перенести в Swift как есть» must hold in Swift too.

## Build and check (no Mac here)
- Project: `ios/project.yml` (XcodeGen) → `ios/Squeal.xcodeproj` is generated in CI, never committed.
- CI: `.github/workflows/ios.yml` on every push to master touching `ios/**`, `content/**` or the workflow
  (also runnable by hand). macOS runner: xcodegen → xcodebuild (simulator) → boots an iPhone simulator,
  runs the app / UI tests, takes screenshots → force-pushes them to branch `ci-shots`, folder `<short sha>/`.
- Read results: `git fetch origin ci-shots:refs/remotes/origin/ci-shots`, `git show origin/ci-shots:<sha>/<file>.png > file`.
  Build errors: GitHub MCP `get_job_logs` (owner KorotenkoPaul, repo squeal).
- Reference: render the web prototype with Playwright (Chromium is preinstalled) at 393×852 for the same screen.

## Stages
1. Foundation: story data (content/stories/<lang>/*.json, same rules as build.py: version fingerprint, covers,
   languages), storage, colours/fonts, tab bar (Home, Favourites, Search, Menu). Home: slider, genre chips,
   tiles with progress and hearts. Story preview sheet (parts, reset, like, Read).
2. Chat: messages, typing/recording, voice and video bubbles, doodle wallpaper, bottom panel, glide, part disc,
   endings, Next part / Read again / Back to a choice, interactive drafts at a choice, progress rules
   (≤3 messages = 0), free taps + paywall, swipe back.
3. Favourites, Search (fear dial), Menu (languages, subscription toggle), random story, everything else.
4. Pass over all of BUGS.md and IDEAS.md UI decisions; fix every difference. TestFlight setup notes.

## Progress log
- 2026-11-22: skeleton + CI pipeline working (simulator screenshot on ci-shots).
- 2026-11-22: stage 1 done (green CI, 12 unit tests, screenshots iPhone 16 + iPhone SE 3rd gen).
  - Code: `ios/Squeal/Core` — plain logic (Story model + `StoryLibrary` loader with build.py rules: order, English
    version/cover, fallback to English; `PyJSON` reproduces build.py's version fingerprint; `Reading` = prog()/percent/
    nextPart/reading time; `Store` = web `store` on UserDefaults, same keys "squeal:*" as JSON text; `TopWeek`; `L10n`
    = the web UI strings in 5 languages + VoiceOver labels). `ios/Squeal/App` — `AppModel` (shared state), launch args.
    `ios/Squeal/UI` — Theme (colours, Avenir Next as on iPhone Safari, bundled OFL lettering fonts with Cyrillic
    fallbacks), SVG path reader (icons from the web's own path data), Home (slider engine with CADisplayLink, worm dots,
    genre oval, tiles with hearts and progress line), Preview (water, reset tap/hold ring, like/unlike, swipes),
    placeholders for Favourites/Search/Menu and the chat.
  - Content is bundled straight from `content/stories` and `web/covers` (folder references in project.yml): no copies.
  - Tests: `ios/SquealTests/web-expected.json` is produced by running web/squeal-preview.html in Chromium (versions,
    minutes in all languages, 100 progress cases, top of the week); regenerate it when content or the rules change.
  - CI screenshots: launch args `-reset 1 -demo 1 -still 1 -lang en|ru -scroll 600 -preview <id> -letterings <page>`.
