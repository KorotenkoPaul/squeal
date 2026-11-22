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
- 2026-11-22: stage 2 done — the chat (green CI, unit tests against the web, screenshots iPhone 16 + iPhone SE in en and ru).
  - Logic, no screen: `ios/Squeal/Core/ChatReader.swift` = everything openStory() decides (which part opens, the path through
    an interactive part and its check against the story's current branches, what a tap / an answer does, what is saved —
    the same `squeal:p:<id>` shape { ep, pos, path?, v } — "an ending reached = read", free taps, the tap given back when
    the chat closes before the message comes, the paywall, "Read again" (whole story or this part), back to a choice,
    the endings still in reach). `JSONOrder` reads the order of `nodes` / `wallpaperEndings` from the file's own text
    (JSONSerialization forgets it; "Ending 2 of 3" and the wallpaper's groups need it) → `Part.nodeOrder`, `.endingsOrder`.
  - Screen, `ios/Squeal/UI/Chat/`: `ChatController` (one open chat: typing / recording timers, the bottom panel, part
    switch, auto-reply after an answer, double-tap guards, leaving); `ChatScreen` (header, part disc, edge swipe back,
    toast); `ChatLog` (the conversation; `ScrollPin` = glideDown/keep on the real UIScrollView, followed inside its
    contentSize / bounds changes; `SlideEngine` = the SLIDE springs of a part switch); `ChatRows` (`Grow` / `GrowLayout` /
    `GrowEffect` = inflate() and morph(): a bubble grows from its corner while its room opens); `ChatBubbles` (text,
    typing, recording, voice, round video, end title); `ChatFoot` (hint, end buttons, paywall; `FootLayout` = the 0.4 s
    height change); `ChoiceDrafts` — THE CHOICE POINT, alone in its file (the "drafts" design is on trial: swap this file
    to change it); `Wallpaper` + `Doodles` (WALL keeper, wallItems / wallLay) and `DoodleData.swift`, generated from the
    web's DOODLE by `node ios/tools/gen-doodles.js`; `ChatMedia` (AVAudioPlayer / AVPlayer; files `web/voice`, `web/video`
    are bundled as folders `voice`, `video`; a clip whose file is missing shows and simply does not play).
  - `AppModel.openStory` only sets `chat` (a `ChatRoute`); `ChatScreen` builds itself from it and slides in on its own.
    `ChatRoute.live` = this chat's part keeps a count of 3 or fewer (false before it is up and while it leaves).
  - Tests: `ios/SquealTests/ChatTests.swift` — 18 walks (175 steps) recorded from the web by `node ios/tools/web-expected.js`
    (adds "chat", "wall", "voiceBars" to web-expected.json; time is faked, it takes under a minute): saved state, progress
    on every screen, free taps, what the chat shows, after every step; the wallpaper layout of 5 parts; the waveform.
  - Reference pictures of the web: `node ios/tools/web-shots.js <dir> [width height]` (same states as the CI shots).
  - Launch args (CI): `-chat <id> [-part N] [-pos N] [-path a,b] [-premium 0 -taps N] [-autotap N] [-autopick K] [-autopart K]`.
  - Not ported on purpose: the web's test button ↶ (IDEAS.md: «В Swift не переносить»). The web's own rubber band is the
    phone's native bounce here. Haptics: the web chat has none.
