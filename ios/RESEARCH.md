# Squeal for iPhone — how to build it natively (research, 2026-11-23)

> Research only: nothing in `ios/` was changed. This document studies every screen and every line of the current
> SwiftUI app (`ios/Squeal`, ≈8 400 lines: App 420, Core 1 405, UI 6 564), the 169 entries of `BUGS.md`,
> `ios/BUGS_PASS.md`, `ios/PLAN.md` and the owner's decisions in `IDEAS.md`, and compares, for every feature,
> several ways to build it. It ends with an architecture, a migration plan and a critical second pass.

## Кратко для владельца (по-русски)

1. Приложение сейчас — почти дословный перевод сайта на Swift. Сайт не умеет того, что iPhone даёт «из коробки»
   (листание, свайп назад, списки с удалением, анимации-пружины), поэтому всё это написано вручную — и именно в
   этих самодельных местах рождаются баги (например, №169: главная не листалась на iOS 26).
2. Главные «костыли»: перехват всех касаний всего окна, свои жесты поверх системного листания, ручные таймеры
   (37 штук) и покадровые моторы (7 штук) вместо системных анимаций, «пересчитай всё» через счётчики.
3. Слайдер на главной перерисовывается 60–120 раз в секунду всё время, пока главная открыта, даже когда ничего
   не происходит, — это расход батареи. Пустое «Избранное» тоже крутит анимацию без конца.
4. Предлагаю: логику (истории, прогресс, поиск, выборы, тапы) **оставить** — она хорошая и проверена тестами.
   Экраны **переписать заново** на системных деталях iPhone: системная навигация со свайпом назад, системные
   списки (свайп «Удалить»), системный поиск, системные пружины, листание — только системное.
5. Так большая часть прошлых багов (по моей оценке ≈90 из 169) просто не сможет появиться: им негде жить.
6. Минимальная версия iOS — **iOS 26** (ваш телефон на ней; так проще, надёжнее и сразу «жидкое стекло»).
7. Несколько ваших решений придётся чуть изменить под стандарт iPhone (список в разделе 9): например, «сова» и
   «рулетка» будут тянуться с системной «резинкой», ✕ сработает при отпускании пальца, языки в меню откроются
   как обычный экран настроек. Каждое такое изменение — только с вашего «да».
8. Порядок: сначала 4 маленьких пробы самых рискованных мест (чат, «сова/рулетка», открытие истории, жанры),
   потом экраны по одному: Меню → Поиск → Избранное → Главная → История → Чат. Оценка — 15–20 рабочих дней.
9. Каждый шаг проверяется на CI: тесты логики, снимки экранов на маленьком и большом iPhone, тесты реальных
   касаний на iOS 26 и новый тест «главная в покое почти не тратит процессор».
10. Напоминание (по правилам `CLAUDE.md`): когда начнём писать Swift-версию — проверить на iPhone баг №52
    (мигание выбранного жанра при обновлении главной): потянуть главную вниз 5–10 раз на разных жанрах.

---

## 1. Method and sources

Read in full: every Swift file in `ios/Squeal/**`, the tests' structure (`ios/SquealTests`, `ios/SquealUITests`,
≈1 300 lines), `ios/project.yml`, `.github/workflows/ios.yml`, all of `BUGS.md` (1–169), `ios/PLAN.md`,
`ios/BUGS_PASS.md` (summary and verdicts), `IDEAS.md` (owner decisions, App Store checklist, the 2026-11 web
redesign). External sources are listed at the end (§12); claims taken from them are marked with [n].

How alternatives were judged, in this order: (1) correctness in edge cases (touch cancelled, second finger, fast
repeats, Reduce Motion, rotation/resizing, background), (2) how many past BUGS entries the approach makes impossible
*by construction*, (3) battery and CPU (does anything run per frame on the main thread while nothing moves?),
(4) amount of code we own, (5) testability on CI without a phone, (6) risk (private API, regressions across iOS
versions, things only a device can show).

---

## 2. Diagnosis — what is most wrong now, and why it produces bugs

The Core layer (`ios/Squeal/Core`) is good: pure Swift, no UI, verified step by step against recordings of the web
prototype (`web-expected.json`, 18 chat walks, 285 search queries, 100 progress cases, 16 double-tap scenarios).
Keep it. The problems are all in the UI layer, and they share seven root causes.

### R1. The browser's event loop was re-created by hand (timers, frame loops, generation tokens)

| Technique (count in `ios/Squeal`) | Where |
|---|---|
| `DispatchQueue.main.asyncAfter` — **37** | ChatController, PreviewView, TileView, GenreOval, HomeView, FavRows, MenuView, SearchView, Haptics.ramp |
| own `CADisplayLink` frame loops — **7** (`FrameLoop` ×6 + `SliderEngine`) | SliderEngine, GenreOval, HomePulls.sink, ScrollPin, SlideEngine, WallKeeper, `tween()` |
| `tween()` (frame-by-frame CSS tween) — 8 call sites | HomePulls (owl lids, reel settle) |
| `Timer.scheduledTimer` — recording timer, voice progress, CI autoplay | ChatController, VoiceClip |
| "token / gen / rev" guards against stale callbacks — **36** `token` + `gen`, `progressRev`, `tabRev`, `refreshRev`, `holdToken`, `noteToken`, `outToken`, `settleToken`, `frameGlide` | everywhere |
| `PreviewView.glide` animates by re-scheduling itself every 1/120 s with `asyncAfter` | PreviewView |

Every one of these is a callback that can fire after the screen, the part, or the user's intent has changed. The
tokens are patches for that, one race at a time. The BUGS log is full of exactly this class: #40 (chat frozen after a
cancelled swipe: the typing timer was cancelled), #57, #68 (permanent "typing…"), #72 (a leaving chat still read and
saved), #117 (recording timer kept running), #132, #133, #134, #135 (a refresh / reel finishing on another tab),
#141, #143. In Swift the fix is structural: one `Task` per screen lifetime (`.task(id:)`), `Task.sleep(for:)` for
pacing, and **cancellation instead of tokens** — when the view or the part goes, its task is cancelled and nothing
of it can run again.

### R2. The app fights the system's touch handling instead of using it

* `Touches.swift` exchanges `UIWindow.sendEvent` for its own (method swizzling) so that a global `Taps.shared`
  sees every touch before any control (`SpotRule` = the web's double-tap rule). Every control must ask
  `Taps.shared.allows("name")` (37 call sites). This is a private-behaviour dependency on UIKit internals and a
  global mutable singleton consulted from every view.
* `ScrollFinder` walks the superview chain to find the `UIScrollView` SwiftUI uses internally; `HeldPan` then adds
  a pan recogniser to it and makes the scroll view's own pan *wait for ours to fail*. Home's slider drag, genre-oval
  drag, owl pull and reel pull are four "modes" of that one pan; Favourites' swipe is another `HeldPan`.
  Hit-testing for these modes is done by comparing touch points with frames collected through `GeometryReader`
  in `.global` space (`sliderFrame`, `rowFrame`, `FavRows.frames`).
* `DragGesture(minimumDistance: 0)` used as a "press" detector on buttons (`PressArea`, ↺, ♥, ✕, part frame, part
  disc) plus a `@GestureState` + `onChange` + `DispatchQueue.main.async` trio to detect cancellations.
* `PressSurface` (a raw `UIView` reading `touchesBegan/Moved/Ended`) — the fix for #169.

This is the direct cause of #169 (zero-distance drag inside a ScrollView stops scrolling on iOS 18/26 — a known
platform change, see [1][2]; on iOS 26 even `simultaneousGesture` inside a ScrollView can block it [3]) and of the
long chain #48, #50, #54, #98, #103, #104, #105, #114, #118, #149, #154, #155, #160. Each new iOS release can move the
ground under this code again; the CI only caught #169 after it moved to iOS 26.

### R3. Layout is measured, published, and replayed

* Every chat `Row` publishes its own `size` and `slot` from `GeometryReader`s; `LogModel` publishes `innerH`,
  `viewport`, `hold`; `Grow` computes a negative margin from them; `GrowLayout` / `FootLayout` read the **current
  time inside `sizeThatFits`** (a layout pass per frame), and `FootLayout` **writes** to `FootBox.shown` from inside
  layout (a side effect in layout).
* `ScrollPin` observes the real `UIScrollView`'s `contentSize` and `bounds` by KVO and sets `contentOffset` from
  inside those callbacks, plus its own display link, to keep the bottom of the chat at the panel's edge.
* `FearWatch` observes `contentOffset` by KVO and hops to the next run-loop turn to publish it.

Measure → publish → re-layout → measure again is a feedback loop; its symptoms are one-frame jumps — exactly the
BUGS family #61, #64, #66, #67, #69, #73, #76, #92, #93, #97, #151, #157, #163 that the web needed frame-by-frame
recorders to chase. A native list that animates its own insertions and keeps its own anchor has no such loop.

### R4. State is scattered and redraws are forced

* `AppModel` is an `ObservableObject` whose every `@Published` change invalidates every view that holds it; to make
  screens redraw after progress changes there is `progressRev` and the idiom `let _ = model.progressRev` in bodies.
* Tabs, routes and modes are strings (`"home"`, `"fav"`, `"lang"`, `dragAxis = "x"`), so typos compile.
* Globals: `Taps.shared`, `BarMemory.seen` (static dictionary), `FavRows.probe`, `ChatDebug` (static vars),
  `CoverCache.shared`, `SliderClock` held by AppModel but mutated by an engine; launch arguments are parsed inside
  views (`HomeView`, `MenuView`).
* Each chat row is its own `ObservableObject` class mutated from five places (controller, slide engine, drafts,
  grow timers, views).

### R5. Navigation is a ZStack of overlays, not presentations

`RootView` stacks the tab page, the toast, `PreviewView` and `ChatScreen` with `zIndex`, and they move themselves
with `.offset`. So everything iOS gives a presented or pushed screen had to be rebuilt: the edge swipe back
(`EdgeSwipe` adds a `UIScreenEdgePanGestureRecognizer` to the window), blocking input under the new screen
(`.accessibilityAddTraits(.isModal)` added by hand — #148), safe areas (read from `UIApplication…windows.first`),
"the page under the chat goes away after 0.4 s" (`asyncAfter`), "a new preview must not wait for the old one's
closing animation" (#109, #110). The web had no choice; Swift does.

### R6. Battery: work every frame while nothing moves

* `SliderEngine` runs a `CADisplayLink` **for as long as Home is on screen**, at the display's full rate (up to
  120 Hz on ProMotion), even with Home covered or the slider frozen: each tick computes, publishes `fill`, and calls
  `save()`. Apple: the display's refresh rate follows the fastest animation in the app, and secondary elements
  refreshing faster than needed drain battery [8].
* `EmptyFavourites` wraps its 1.8 s picture in `TimelineView(.animation)` that **never pauses** — the empty
  Favourites page redraws every frame forever.
* `Blink` (typing dots) and `HintLine` (10-s "breathing") use `TimelineView(.animation)`: per-frame body
  re-evaluation on the main thread for what a `repeatForever` animation does on the render server.
* `RowView` wraps every chat row in a `TimelineView`, and the bottom panel re-runs layout every frame for 0.4 s.
* `WallKeeper` publishes `frame += 1` every frame while doodles fly; the whole `Canvas` is redrawn per frame.
* Covers are decoded at full size with `UIImage(contentsOfFile:)` on the main thread and filtered at draw time
  (`.saturation`, `.colorMultiply`), which costs an offscreen pass in every tile, every frame they move.

### R7. Web fidelity where it conflicts with the platform

Fixed Avenir sizes (no Dynamic Type), CSS cubic-béziers copied into Swift (`CubicBezier`, `keyframes()`), a 1:1
rubber band specified in JavaScript numbers, the double-tap rule built for a browser that delivers the second tap of
a double tap to whatever has just appeared, launch-argument test hooks inside production views, and a deployment
target of iOS 17 that forbids the very APIs (iOS 18: scroll geometry/phase, `ScrollPosition`,
`UIGestureRecognizerRepresentable`, zoom transitions) that replace the hand-made parts.

**In one sentence:** the bugs are not careless code — the code is careful — they come from rebuilding, in a
foreign idiom, things iOS already does correctly; every rebuilt thing has edge cases the platform has already solved.

---

## 3. Inventory: every feature, where it lives, how it works now, which BUGS touched it

| # | Feature | Files | Current technique | BUGS |
|---|---|---|---|---|
| F1 | App shell, tab bar, toast | `RootView`, `TabBar`, `AppModel.showToast` | ZStack + custom HStack tab bar; `.id(tabRev)` redraws a page on every tab tap; toast via `asyncAfter` | 21, 28, 153 |
| F2 | Story page presentation and dismissal | `RootView`, `PreviewView.swipe`, `close()` | overlay at zIndex 2, own `DragGesture` swipes right/down (close) and left/up (open chat); ✕ fires on touch-down | 75, 109, 110, 131, 137, 148, 150, 166 |
| F3 | Chat presentation, back, edge swipe | `ChatScreen`, `EdgeSwipe`, `ChatController.close/swipe*` | overlay at zIndex 3 slid by `.offset`; window-level `UIScreenEdgePanGestureRecognizer` | 11, 12, 40, 55, 72, 102, 110, 111, 118, 125, 133 |
| F4 | Top-of-week slider (endless, auto every 4 s, worm dots with time line) | `Slider.swift`, `HomePulls` (`.slider` mode), `SliderClock`, `TopWeek` | `CADisplayLink` engine with its own tween, copy cards at both ends, drag from Home's `HeldPan` | 1, 2, 3, 4, 54, 71, 94, 115, 126, 128, 143, 147, 149, 156, 161 |
| F5 | Genre chips + draggable oval | `GenreChips.swift` (`GenreOval`), `HomePulls` (`.genre`), `Taps.onDown` | own frame loop, global-frame hit testing, press-then-90 ms slide-over, `.genre` pan mode | 48, 49, 50, **52**, 149, 153 |
| F6 | Tiles: tap opens, hold 0.38 s likes/unlikes, heart badge tap unlikes, progress line | `Tile.swift`, `Heart.swift` | `PressSurface` (raw UIView touches) + `asyncAfter` hold timer + `HeartMotion` driven by `TimelineView` | 19, 20, 51, 122, 168, 169 |
| F7 | Owl pull-to-refresh | `HomePulls`, `OwlEyes`, `RefreshPull` | `.refresh` pan mode moves the page by `.offset`; lids via `tween`; waits on `Taps.fingers` (max 8 s) | 47, 98, 103, 104, 105, 114, 118, 134, 154, 155 |
| F8 | Random-story reel (pull up at the bottom) | `HomePulls`, `ReelView`, `ReelGeometry`, `Shelf.randomPool` | `.reel` pan mode, own critically-damped sink spring in a frame loop, `tween` settle | 21, 22, 23, 43, 44, 46, 60, 98, 135, 149 |
| F9 | Genre change on the grid, refresh fade | `HomeView.swapGrid`, `refreshRev` | `asyncAfter(0.12)` + two transactions | 49, 52, 100 |
| F10 | Story page: water parts, draggable part frame | `PreviewView.parts`, `Water.swift` | `TimelineView` (paused when idle — good), frame glide via `asyncAfter(1/120)` | 6, 7, 53, 137, 139, 161 |
| F11 | ↺ reset: tap (part) / hold with ring (all), haptic ramp, note | `PreviewView.reset*`, `Haptics.ramp` | `DragGesture(0)` + state machine `holdState` + nested `asyncAfter`; 6 timed `UIImpactFeedbackGenerator`s | 8, 10, 53, 139, 150, 153 |
| F12 | ♥ like on the story page | `PreviewView.likeButton`, `HeartBadge` | `DragGesture(0)` press + `TimelineView` motion | 99, 140, 160 |
| F13 | Chat conversation list, glide to bottom, native bounce | `ChatLog.swift` (`LogView`, `ScrollPin`) | eager `VStack` in `ScrollView`; KVO + frame loop on the real UIScrollView | 32, 61, 65, 67, 69, 74, 88, 89, 91, 95, 123, 157 |
| F14 | Bubble grows from its corner; typing morphs into the message | `ChatRows.swift` (`Grow`, `GrowLayout`, `GrowEffect`) | negative margin computed per frame inside `Layout`, `GeometryEffect` scale | 61, 78, 80, 97, 151, 163 |
| F15 | Typing / recording pacing, recording timer, status line | `ChatController.step/arrive` | `DispatchWorkItem` + 0.25 s `Timer` + gen checks | 40, 68, 117, 161 |
| F16 | Bottom panel (tap / ask / end / paywall), 0.4 s height change | `ChatFoot.swift`, `FootLayout`, `FootBox` | per-frame layout from `TimelineView`, layout side effect | 42, 64, 66, 73, 92, 93, 112, 130, 161, 167 |
| F17 | Part disc in the header (tap or drag) and part switch choreography | `ChatScreen.PartDisc`, `ChatController.goPart/open`, `SlideEngine` | `DragGesture(0)`; own spring integrator per row on a frame loop; ghost log | 13, 55, 56, 57, 63, 76, 82, 85, 86, 87, 90, 96, 101, 102, 125, 141, 152, 160 |
| F18 | Endings, Next part, Read again, Back to a choice | `ChatController.showEnd`, `ChatFoot.EndButtons`, `ChatReader` | timed title insertion and button fade; `early()`, `endEarly()` time guards | 29, 42, 66, 83, 112, 124, 130, 141, 142, 145, 151, 161, 168 |
| F19 | Choices as drafts in the chat; auto-reply 1 s later | `ChoiceDrafts.swift` | `Row` flags (`enter`, `chosen`, `melted`, `lift`), `asyncAfter`, `hold` room | 39, 64, 67, 69, 70, 73, 74, 79, 81, 92, 93, 123, 124, 129, 164, 165 |
| F20 | Free taps and paywall | `ChatReader`, `ChatFoot` | pure logic (good) + `payAt` time guard | 15, 39, 145, 152, 167 |
| F21 | Voice messages | `ChatMedia.swift` (`VoiceClip`) | `AVAudioPlayer` + 0.1 s `Timer`; session category toggled | 41, 149, 163, 166 |
| F22 | Round video messages | `ChatMedia.swift` (`VideoClip`, `PlayerSurface`) | `AVPlayer` per bubble, muted loop by seek on end, 20 Hz time observer | 41, 149, 163 |
| F23 | Doodle wallpaper: fly-in, fall, still layer | `Wallpaper.swift`, `Doodles.swift`, `DoodleData.swift` | own physics in a frame loop, `Canvas` redrawn per frame, separate still `Canvas` | 58, 62, 146, 159 |
| F24 | Favourites: grouped rows, swipe to remove, empty state | `FavouritesView.swift`, `RowSwipe` | `HeldPan` + global frames + `Taps.onDown` + `UIViewPropertyAnimator` on the scroll view | 18, 38, 84, 136, 149, 152, 160, 166, 167 |
| F25 | Search field, Cancel, keyboard, back-to-place | `SearchView.swift` | custom field, keyboard-frame notifications, `Taps.onDown`/`eatThisTouch`/`pin` | 24, 25, 35, 36, 45, 106, 158, 167 |
| F26 | Fear dial | `SearchView.FearRow`, `FearWatch`, `Fear.paint` | horizontal `ScrollView` + `.viewAligned` (good) + KVO + 140 ms debounce | 37, 143, 168 |
| F27 | Menu, languages, subscription toggle | `MenuView.swift` | five rows faded in place (0.3 + 0.3 s), own swipe-back `DragGesture`, `swapAt` guard | 28, 153, 167 |
| F28 | Double-tap guard app-wide | `Touches.swift`, `SpotRule.swift` | window `sendEvent` swizzle + global rule consulted by every control | 36, 75, 106, 112, 124, 130, 141, 148, 161, 166, 167, 168 |
| F29 | Store, progress, favourites, taps, top-week counts | `Store.swift`, `Progress.swift`, `TopWeek.swift` | JSON text in `UserDefaults` with web semantics (wrong kind = default) — good | 27, 30, 31, 113, 121, 145, 156, 158 |
| F30 | Localisation (5 languages), VoiceOver labels | `L10n*.swift` | dictionaries in code; `\.locale` set app-wide | 166 (IDEAS), 183 |
| F31 | Slider lettering (per-story art fonts, fitting) | `HeroLettering.swift`, `Theme.Lettering` | bundled OFL fonts, fit by measured size | 5, 127 |
| F32 | Covers | `Cover.swift` | full decode on main thread, cached forever; filters at draw time | 159 |
| F33 | Icons | `Icons.swift`, `SVGPath.swift` | SVG path strings parsed into `Shape`s | 9, 34 |
| F34 | Haptics | `AppModel.Haptics` | `UIImpactFeedbackGenerator` created per call; ramp as 6 timed impacts | IDEAS «Вибрация» |
| F35 | Reduce Motion | `reduceMotion()` — 55 call sites | a global function read imperatively | 69, 161 |
| F36 | Accessibility | throughout | manual `isModal`, actions, identifiers; fixed font sizes | 148, IDEAS VoiceOver |
| F37 | Test hooks (launch args, TouchProbe, ChatDebug, `-letterings`) | `SquealApp`, `RootView`, `HomeView`, `MenuView`, `ChatController` | parsed inside production views; probe polls every 0.25 s | — |

---

## 4. Platform baseline: which iOS to target

| Option | What it gives | What it costs |
|---|---|---|
| iOS 17 (now) | widest reach | no scroll geometry/phase, no `ScrollPosition`, no `UIGestureRecognizerRepresentable`, no zoom transition → forces the hand-made parts (R7) |
| iOS 18 | everything needed for the architecture below: `onScrollGeometryChange`, `onScrollPhaseChange` (with velocity), `ScrollPosition`, `defaultScrollAnchor(_:for: .sizeChanges)`, `UIGestureRecognizerRepresentable`, `.navigationTransition(.zoom)`, `onScrollVisibilityChange`, `Tab` API [4][5][6][10] | two visual generations (pre-glass and Liquid Glass) to design and test; CI and the owner's phone see only one of them |
| **iOS 26** | the above, plus Liquid Glass bars and `glassEffect`, tab bar minimise/accessory, scroll-edge effects [9], `@Animatable` macro [11], SF Symbols 7 *Draw On* (the "pen draws the heart" effect for free) [14], the iOS 26 SwiftUI performance work [11]; one OS family = what CI runs and what the owner holds | excludes iPhones still on iOS 18: Apple's June 2026 figure is 86 % of iPhones from the last four years on iOS 26 [7]; iOS 27 shipped in September 2026, so "current minus one" = iOS 26 |

**Recommendation: iOS 26.0.** Reasons: the app is not released; by release, iOS 26 is "current minus one", a common
minimum; the redesign the owner asked for is the iOS 26 look; and — decisive for reliability — this project has
exactly one test phone and one CI simulator, both on iOS 26. #169 was an OS-difference bug that slipped through
because tests ran on another OS. Supporting iOS 18 would be possible (the core APIs are iOS 18; only glass,
`drawOn` and the macro would need `if #available`), so revisit only if reach matters more at launch.

Also: Swift 6 language mode with Xcode 26's default `MainActor` isolation for the app target (UI code is
main-thread by default; background work is explicit). Today `SWIFT_VERSION` is `5.0`.

---

## 5. Feature by feature: alternatives, comparison, choice

Notation for each: **A** = the current approach, then the alternatives; ✔ = chosen. "Kills" lists BUGS entries
that become impossible by construction (not merely fixed).

### 5.1 App shell, tabs (F1)

* A. Custom HStack tab bar in a ZStack, `.id(tabRev)` rebuilds the page on every tap.
* B. ✔ `TabView` with the `Tab` API; iOS 26 gives the Liquid Glass tab bar, `Tab(role: .search)` for Search,
  `tabBarMinimizeBehavior(.onScrollDown)` if wanted [9]. Each tab owns a `NavigationStack(path:)`.
  Tapping the current tab pops to root / scrolls to top — system behaviour, replacing "draw afresh".
* C. Custom glass bar with `glassEffect` — only if the owner insists on a non-standard bar.

B is fewer lines, VoiceOver/large-content viewer/keyboard support for free, and it is what the web redesign imitates
("Таб-бар как в iOS 26"). Kills #21 (nothing can show from under a system tab bar that hides on push).
The "page drawn afresh" rule (web `render()`) is dropped: state that must reset on a tab tap is reset explicitly.

### 5.2 Story page and chat presentation (F2, F3)

* A. Overlays in a ZStack with hand-made swipes (current).
* B. `.sheet` / `.fullScreenCover` for the story page, chat pushed inside it.
* C. ✔ **Push both on the tab's `NavigationStack`.** Story page: `.navigationTransition(.zoom(sourceID: id, in: ns))`
  with `.matchedTransitionSource` on the tile/slider card/row [6] — it grows out of the card and can be dismissed
  interactively by dragging down or swiping from the edge (owner: "swipe right / swipe down closes; follows the
  finger"). Chat: a normal push (slides in from the right; system edge swipe back; tab bar hidden with
  `.toolbar(.hidden, for: .tabBar)`). When the chat is up, the story page is removed from the path beneath it
  (path `[story, chat]` → `[chat]` without animation) so Back lands where the story was opened (#12).
* D. A custom container view controller with `UIViewControllerAnimatedTransitioning` — full control, much more code.

C makes the following impossible: touches reaching the page under a transition (UIKit ignores input to the
navigation stack during push/pop), a half-dismissed screen after a second finger (#118), stale "preview under the
chat" (#110, #133), the swipe starting on the header (#11 — header bar items are controls), VoiceOver escaping to
the page below (#148), the chat closing/reading while it leaves (#72), the edge swipe on the window leaking to other
screens. Kills: 11, 12, 55, 72, 102, 109, 110, 111, 118, 125, 131, 133, 137, 148, 150.

Risks: (1) zoom transitions had iOS 26 regressions on interactive dismissal (source view disappearing, flashes)
reported through 26.4 [6b] — prototype first; fallback is the default push. (2) On iOS 26 the system back gesture
also works from the content area, not only the very edge — this contradicts #11's rule ("only from the very left
edge") but is now the platform's standard; owner decision (§9). (3) "Swipe up on the story page opens the chat
from below" becomes "opens like Read" (from the right) — owner decision.

### 5.3 Home page scrolling and the double "pull" (F7, F8)

* A. Own pan attached to SwiftUI's private UIScrollView; the page moved by `.offset`; own springs (current).
* B. `.refreshable` — native, robust, but always shows the system spinner and gives no access to the pull
  distance; no way to draw the owl's eyes from it; nothing for the bottom reel.
* C. ✔ **Native overscroll, read and decorated.** The `ScrollView` keeps its own pan and bounce. With
  `onScrollGeometryChange` we read the overscroll (`contentOffset.y + contentInsets.top < 0` at the top, past the
  maximum at the bottom) and draw the owl's eyes (lids from the distance) in the gap at the top, and the reel in the
  gap at the bottom, turning with the distance. With `onScrollPhaseChange` we see the release (`.interacting` →
  `.decelerating`/`.animating`, with velocity [5]) and decide: owl past the line → refresh; reel past the line →
  settle on the nearest row and open it. While refreshing, the page is held down by animating
  `.contentMargins(.top, rest, for: .scrollContent)` (or a top spacer), released after the blink. "A finger still
  on the screen holds the page" is simply the phase still being `.interacting` — no global finger counter (#114).
* D. A `UIRefreshControl` subclass reached through introspection — private-hierarchy dependency, rejected.

C deletes `HeldPan`, `HomePulls` (411 lines), the sink spring, `tween`, the global finger watcher. Kills: 47, 98, 103,
104, 105, 114, 118, 134, 135, 154 (arc touches), 155. What changes for the owner: the band is iOS's (it gets stiffer
the further you pull, ≈ what the web's `150·(1−e^(−x/170))` imitates); the reel rises with the *page* (the gap),
not exactly 1:1 with the finger; "pulled past the top, the page stretches further while the reel holds" is just
the native band. Needs the owner's "yes" (§9).

### 5.4 Slider (F4)

* A. `CADisplayLink` engine, copies at the ends, drag via Home's pan (current).
* B. ✔ **Horizontal `ScrollView` inside the vertical one, paging.** `LazyHStack` of n+2 cards (copy of the last
  first, copy of the first last) with `.scrollTargetLayout()`, `.scrollTargetBehavior(.paging)` (or `.viewAligned`
  with the 18 pt inset via `.contentMargins`), `.scrollPosition($position)` [4]. Endless: when the phase becomes
  `.idle` on a copy, jump to the real card with animations disabled (they look the same). Auto-advance: a `Task`
  that sleeps until the card's 4 s are up, then `withAnimation { position.scrollTo(id: next) }`; it is cancelled
  while the phase is not `.idle` (finger on it, gliding — #54), while Home is not visible, or the scene is not
  active (`scenePhase` — #149), and on a refresh. The worm dots are a pure function of the fractional page,
  read with `onScrollGeometryChange(for: Double.self)`. The time line inside the worm: a width animated with
  `.linear(duration: remaining)` (the render server interpolates; no main-thread work per frame), re-targeted when
  the clock pauses.
* C. `TabView(.page)` — no endless wrap, little control over the index during a drag.
* D. A library (e.g. a SwiftUI pager) — nothing B lacks.

Nested scroll views resolve the axis natively (UIKit's direction locking): a sideways drag on the slider never
scrolls the page; a vertical one always does (#169 class impossible). The card's tap is a `Button` (`.buttonStyle`
with `isPressed` for the 0.96 sink): a button in a scroll view is cancelled by scrolling, and the card under the
finger at touch-down is the one that opens (#128). Kills: 1, 3 (wrap handled at rest), 54, 94 (the line is a child
of the worm), 115, 126 (no display link at all), 143, 147, 169. Battery: zero work while idle except one sleeping
task; during auto-turns the animation runs on the render server.

`SliderClock` (#2: the slider keeps its place when you come back) stays as a tiny model: `at`, `elapsed`,
`pausedAt`.

### 5.5 Genre chips and the oval (F5); also the story page's part frame (F10) and the chat's part disc (F17)

These three are the same control: a row of options with one "lens" that slides, can be dragged 1:1, blends its
width between neighbours and settles on the nearest.

* A. Three separate hand-made implementations (frame loops, global frames, `DragGesture(0)`).
* B. ✔ (first choice) **`Picker(selection:) { … }.pickerStyle(.segmented)`** — `UISegmentedControl` already lets
  you drag the selected thumb across segments, follows the finger, settles on the nearest, and on iOS 26 it is
  rendered in Liquid Glass. Styled with `UISegmentedControl.appearance()` (selected tint = accent, title font).
  Zero gesture code, VoiceOver "1 of 4", correct in every edge case. Its look is Apple's, not the web's oval.
* C. ✔ (if the owner wants the exact oval) **one `OvalPicker` component** in the design module: `HStack` of
  `Button`s for taps; the lens is one `Capsule` whose centre and width are a pure function of a continuous
  `position: Double` (blend between neighbours, exactly as now); the drag is a `UIGestureRecognizerRepresentable`
  wrapping a `UIPanGestureRecognizer` whose delegate begins only when the horizontal velocity dominates [10] — the
  enclosing scroll view's pan then fails for that touch, a vertical start is the page's. Release / tap →
  `withAnimation(Motion.snap) { position = Double(index) }` (springs keep velocity [12]).
* D. Keep three separate custom controls — rejected (three times the bugs).

Kills: 48, 50, 52 (a single value-typed control whose identity never changes on refresh — see also §6.2), 56, 86,
149 (the oval left on another genre), 160, 169.

### 5.6 Tiles: tap, hold-to-like, heart badge (F6, F12)

* A. `PressSurface` raw touches + own hold timer (current).
* B. `Button` + `.simultaneousGesture(LongPressGesture(minimumDuration: 0.38))` — simultaneous gestures inside a
  ScrollView are exactly what regressed on iOS 26 [3]; rejected.
* C. ✔ **`Button` for the tap + a `UILongPressGestureRecognizer` (minimumPressDuration 0.38, allowableMovement 8)
  via `UIGestureRecognizerRepresentable`.** The UIKit long-press and the scroll view's pan are designed to
  coexist (the long press fails the moment the pan begins), and a `Button` inside a scroll view cancels itself
  when scrolling starts. The pressed-in look comes from the `ButtonStyle`'s `isPressed`. The heart badge is its own
  small `Button` on top (its tap unlikes; #19).
* D. `.contextMenu { Button("Favourite") } preview: { … }` — the most iOS-native "hold" (a preview and a menu),
  accessible, no custom gesture at all; but it changes the owner's decision (hold = instant like with a swell).
  Offered as an option in §9.

Heart animation (draw / crack): replace `HeartMotion` + `TimelineView` + `Date` with **`KeyframeAnimator`**
(iOS 17) driven by a trigger value (like/unlike) — declarative keyframes for pop scale, pen trim, ink fill, crack
angle; runs only while animating. On iOS 26 the heart can be a custom SF Symbol with `.symbolEffect(.drawOn)` [14]
(the pen effect, by Apple). The same `HeartBadge` component is used on the tile and the story page (#99, #182).
Haptic: `.sensoryFeedback(.impact(weight: .light), trigger: isFav)` on the badge — fires once per change from any
screen. Kills: 19, 51 (the tile animates only on its own trigger, a change from elsewhere just sets the state),
99, 140, 160, 169.

### 5.7 Grid and refresh fade (F9)

`LazyVGrid` stays. Genre change: the grid's `ForEach` gets `.id(genre)` on its container with
`.transition(.opacity.combined(with: .offset(y: 18)))` and one `withAnimation` — instead of two timed transactions.
Refresh: only the stories array changes; with `@Observable` fine-grained tracking the genre control does not even
re-evaluate (it does not read the stories) — the structural answer to #49/#52. The 0.3 s fade-in-place is one
`.transition(.opacity)` keyed by a refresh generation. Kills: 49, 52 (verify on the phone), 100.

### 5.8 Story page content (F10, F11)

* Water: keep `WaterFill` drawn with `Canvas`/`Shape`, but drive it with `KeyframeAnimator` (rise 1 s, waves
  3.3 s, drain 1 s) or with an `Animatable` wave phase (`@Animatable` macro on iOS 26 [11]); nothing runs when
  settled (the current `TimelineView(paused:)` is already correct in spirit).
* Part frame: the `OvalPicker` of §5.5 (or segmented).
* ↺ reset: `Button` (tap = this part) + `.onLongPressGesture(minimumDuration: 0.45, perform:, onPressingChanged:)`
  is risky in scroll views but the story page does not scroll; still, use the same `UILongPressGestureRecognizer`
  representable as tiles for one consistent rule. Ring: `Circle().trim(to: ring)` animated
  `withAnimation(.linear(duration: 0.3))`, wound back by animating to 0 — the system interrupts and retargets.
  Haptic ramp: **Core Haptics** — one `CHHapticEvent` of type `.hapticContinuous` with a
  `CHHapticParameterCurve` 0.2 → 1.0 over 0.3 s, played by a `CHHapticAdvancedPatternPlayer` that is stopped on
  release or completion (exactly the owner's spec, "stop at once"). Replaces six `asyncAfter` impacts.
* ✕: a toolbar `Button` (glass on iOS 26). Native buttons fire on touch-up; the owner's rule is touch-down.
  Recommend touch-up (standard; also makes #75/#148 impossible because the same touch can never land on what is
  revealed underneath); owner decision.
* Kills: 8 (drain is an animation), 53, 139, 140, 150, 153 (note laid out by the toolbar), 160.

### 5.9 Chat conversation: list, glide, growth, panel (F13, F14, F16) — the heart of the app

Requirements distilled from BUGS/IDEAS: the newest message sits 8 pt above the bottom panel; new things grow from
their pointed corner over 0.26 s while the room opens at the same pace; the conversation glides up with them; a
finger scrolling stops the glide, a tap does not (#65); the panel changes height over 0.4 s and the conversation
moves with its edge; after a choice the freed room stays until filled (#67, #92 — current rule in IDEAS line 173:
the sent answer lands at its normal place, no empty gap); native bounce including the description (#88, #91,
#95); never a jump in any frame.

* A. Current: eager `VStack` + `ScrollPin` (KVO + frame loop) + per-frame `GrowLayout`/`FootLayout`.
* B. ✔ **SwiftUI `ScrollView` + eager `VStack`, bottom-anchored, panel as a safe-area inset.**
  - `.defaultScrollAnchor(.bottom)` (open on the last message read) and
    `.defaultScrollAnchor(.bottom, for: .sizeChanges)` (iOS 18: when the content grows, the bottom stays put) [4].
  - The panel goes in `.safeAreaInset(edge: .bottom) { ChatPanel(...) }`: its height change animates in the same
    transaction as everything else, and the scroll view's bottom inset moves with it — the "last message 8 pt above
    the panel, moving with its edge" rule by construction (#64, #66, #67, #73, #92, #93).
  - A new row is inserted inside `withAnimation(Motion.bubble)`; the row uses
    `.transition(.scale(scale: 0, anchor: .bottomLeading/.bottomTrailing).combined(with: .opacity))`. Its slot
    takes its full height at once, and every row above it animates up in the same transaction, so the bubble never
    overlaps the one above (#97) and the conversation "glides" with the system animation.
  - Typing → message: the same row identity changes its content; the bubble's background is a shape sized by its
    content, so the size change animates; the words fade in with `.contentTransition(.opacity)` (#78, #80: the typing
    bubble contains an invisible line of the message font — one line high by construction).
  - User scrolling interrupts system scroll animations; taps do not (#65).
  - Eager (`VStack`) rather than lazy on purpose: parts hold at most a few hundred short rows; eager layout gives
    exact content height, so bottom anchoring and `scrollTo` never deal with estimated heights (Apple's own advice:
    with lazy stacks the content offset is an estimate [13]; a 2026 forum report shows `scrollTo` not reaching
    unrealised lazy rows on iOS 27 [4b]).
* C. **`UICollectionView` + `UIHostingConfiguration` cells + a chat layout** (e.g. ekazaev/ChatLayout [16]),
  diffable data source, custom insert animations. The industry-proven path for chat; full control of anchoring
  during insertions; more UIKit code and two worlds to test. Apple's 2026 SwiftUI lab says a hosted collection view
  is "generally not needed" for scrolling lists [13].
* D. **Exyte Chat** [15] — built for chat apps with an input bar and a media picker; our chat has no input and a
  scripted choreography; we would fight its abstractions. Rejected.
* E. `List` — row separators/insets/selection to suppress, less control over insertion transitions. Rejected.

B is chosen **behind a prototype gate** (§8, step 0): the one behaviour I could not confirm from documentation is
whether `.sizeChanges` bottom anchoring tracks an *animated* height change frame by frame without a lag. If the
prototype shows any lag, switch the list (only the list) to C; the rest of the chat design is unchanged.
Kills (with B or C): 32, 61, 64, 65, 66, 67, 69, 73, 74, 76, 78, 80, 88, 89, 91, 92, 93, 95, 97, 123, 151, 157, 163.

The "hold room after a choice" rule becomes data: an explicit spacer row of a given height at the end of the list
(part of layout, animated by the transaction), not a measured `hold` value.

### 5.10 Chat pacing, timers and the session's lifetime (F15, F18, F19, F20)

* A. `ChatController` (654 lines) with `DispatchWorkItem`s, `Timer`s, `gen` tokens, time guards
  (`early()`, `endEarly()`, `payAt`, `pickT`, `born`).
* B. Combine pipelines — more machinery, same lifetime problem.
* C. ✔ **`@Observable @MainActor final class ChatSession`** owning value-typed rows and one script `Task`.
  `ChatReader` (Core, already web-verified) stays the authority on *what* happens; `ChatSession` only adds *time*:
  ```swift
  func readOn() async throws {            // one tap
      switch reader.begin() {
      case .theirs(let m):
          status = .typing(m.kind); rows.append(.typing(m.kind, id: m.id))
          try await clock.sleep(for: .milliseconds(m.wait))   // throws CancellationError if the chat goes
          withAnimation(Motion.bubble) { rows[last] = .message(m); reader.arrived() }
      ...
  ```
  The view starts it with `.task(id: route)`: leaving the screen, switching part, or opening another chat cancels
  the task and every pending sleep with it — nothing of the old chat can run later (#40, #68, #72, #117, #132,
  #135, #164). The recording seconds come from `TimelineView(.periodic(from:by: 1))` only while recording, or from a
  `Text(timerInterval:)` (system-updated). The injected `Clock` (Point-Free `swift-clocks`' `TestClock` in tests
  [18]) makes the whole choreography unit-testable without waiting.
* The time guards become *arming*: controls that appear under a finger take no hit until armed (§6.4).
* Kills: 40, 57, 68, 72, 117, 132, 135, 141, 142, 164, 165.

### 5.11 Choices as drafts (F19)

* ✔ A draft is a row whose identity is the future sent message: `.draft(choiceID)` → on pick, the same id becomes
  `.message` with the sent style (filled, pointed corner) in one `withAnimation`; the others leave with
  `.transition(.move(edge: .trailing).combined(with: .opacity))`; the chosen row glides to the first place because
  the rows above it disappeared (layout animation), not by a computed `lift`. Same view, same width constraint →
  identical line breaks before and after (#79, #81 impossible). Arrival stagger: `.animation(Motion.slide.delay(k*0.07))`
  per draft keyed on its appearance. Double pick impossible: the drafts are disabled (`.disabled(picked)`) in the
  same transaction that marks the pick. Auto-reply: `try await clock.sleep(for: .seconds(1))` in the session task.
* Kills: 70, 73, 74, 79, 81, 123, 124, 129.

### 5.12 Part switch choreography (F17)

* A. `SlideEngine`: one hand-integrated critically damped spring per row on a frame loop; ghost log copies.
* B. ✔ **System springs with retargeting.** Each visible row has a horizontal offset state (`0` or "past its side");
  a switch sets goals inside `withAnimation(.spring(duration: 0.4, bounce: 0))` (arrive) or
  `.spring(duration: 0.15, bounce: 0)` (leave) with per-row `.delay(k*0.025)`. SwiftUI springs retarget in flight
  and keep the current velocity [12] — exactly the owner's rule "what moves keeps its speed and turns smoothly"
  (#82, #85, #87, #90, #101). They run on the render server's clock, so a long main-thread frame cannot make a
  message jump forward (#96). The "arrive only when everyone has left" rule uses
  `withAnimation(_:completionCriteria: .removed) { … } completion: { … }` (iOS 17) to start the arrivals.
  The old conversation is not a ghost copy: the session keeps two row arrays (leaving, arriving) rendered in one
  `ZStack` clipped to the list's frame (#76).
* C. `UIViewPropertyAnimator` per row (what IDEAS line 179 suggested) — works only with UIKit views (option C of
  §5.9); same semantics.
* Kills: 63, 76, 82, 85, 87, 90, 96, 101, 102 (start positions computed in the list's own space by construction).

### 5.13 Doodle wallpaper (F23)

* A. Own physics on a frame loop, the whole `Canvas` redrawn per frame, a separate still `Canvas`.
* B. `SpriteView` + SpriteKit with gravity — real physics, GPU, but a second rendering world, harder to test,
  heavier at launch. Rejected.
* C. ✔ **One SwiftUI view per doodle (≈25–40), animated by the system.** Fly-in: spring from a start position;
  fall: a `CustomAnimation` (iOS 17) that implements `y = ½·g·t²` exactly and merges with an in-flight fly-in
  (`shouldMerge`) — the "stop where it is and fall" rule; random lag via `.delay`. At rest the same views simply stay
  (no swap to a "still layer", #159's flicker class is gone). Drawn from vector images in the asset catalog
  (converted once from `DoodleData`), not parsed paths.
* D. `Canvas` + `TimelineView(.animation(paused: !moving))` — keeps today's drawing code, still per-frame main
  thread while moving; acceptable fallback.
* Kills: 62, 146 (timings are declared, not integrated), 159.

### 5.14 Voice and round video (F21, F22)

* ✔ One `@Observable MediaCenter` (one sound at a time) using `AVPlayer` for both voice and video:
  `addPeriodicTimeObserver` (4–10 Hz is enough for a time label), `AVAudioSession.interruptionNotification` and
  `routeChangeNotification` (headphones out) → back to the silent/paused look (#149), stop on scene background and
  on the chat task's cancellation (#41).
* Silent looping preview: `AVQueuePlayer` + `AVPlayerLooper` (gapless, made for this) instead of seek-on-end.
* Play previews only while visible: `onScrollVisibilityChange` (iOS 18) pauses off-screen video circles — today
  every circle in a long chat loops a decoder forever (battery).
* Progress ring: animate `trim` with `.linear(duration: remaining)` once, re-targeted on pause; no 20 Hz state.
* AVKit `VideoPlayer` rejected (system controls, rectangular).
* Kills: 41, 149 (media part), 163 (label from the real current time, rounded).

### 5.15 Favourites (F24)

* A. `HeldPan` swipe + global frames + `Taps.onDown` "close Remove on next touch".
* B. ✔ **`List` with `.swipeActions(edge: .trailing, allowsFullSwipe: true) { Button(role: .destructive) }`**,
  sections per genre, custom row background (the cover card) via `.listRowBackground`, separators hidden,
  `.listRowInsets`. Full swipe removes, a tap elsewhere or a scroll closes the open action, removal animates the rows
  and the scroll offset (#84), an empty section's header disappears with its last row (#160), double "Remove" is
  impossible (the row is gone from the data source in the same transaction, #136), a cancelled touch removes
  nothing (#149). Haptic and VoiceOver actions are built in.
* C. Custom swipe on `LazyVStack` rows with `UIGestureRecognizerRepresentable` — only if the owner rejects the
  system look of the red action (the stretched red button exists natively, it is the system's).
* Empty state: `ContentUnavailableView`-like custom view whose picture is a `KeyframeAnimator` that plays once
  (fixes the never-pausing `TimelineView`).
* Kills: 18, 84, 136, 149, 152, 160, 166, 167.

### 5.16 Search and the fear dial (F25, F26)

* A. Custom field, keyboard-frame math, `Taps` pin/eat, KVO on the fear row.
* B. ✔ **`.searchable(text:)` on the Search tab's `NavigationStack`** (with `Tab(role: .search)` the iOS 26 tab bar
  turns into the search field), `.searchPresentationToolbarBehavior`, `.scrollDismissesKeyboard(.immediately)`;
  the results list is a `List` or `LazyVStack` that bounces natively with any count
  (`.scrollBounceBehavior(.always)`) and never moves the field (#45). Cancel and "a tap that only dismisses the
  keyboard opens nothing" are system behaviour (#36, #106). Keep the place on Cancel with `ScrollPosition` (#35).
* Fear dial: keep the horizontal `ScrollView` + `.viewAligned` + `.contentMargins` (already right), replace KVO with
  `.scrollTransition { content, phase in content.scaleEffect(…).opacity(…) }` (a render-time effect, no state per
  frame) and set the level on `onScrollPhaseChange` → `.idle` (no 140 ms debounce). Tap on a neighbour:
  `position.scrollTo(id:)`.
* Kills: 24, 25, 35, 36, 37, 45, 106, 143, 158 (trimmed query in the model), 167.

### 5.17 Menu and languages (F27, F30)

* ✔ `Form`/`List(.insetGrouped)` "like Settings" (as the web redesign does): Subscription as a `Toggle`, Language as
  a `NavigationLink` to a list with a checkmark (push, native swipe back), Restore/Idea/Mail as buttons. The
  0.3 + 0.3 s fade in place and its swipe become a standard push — owner decision. Kills 28, 153 (Dynamic Type and
  wrapping by the system), 167.
* Localisation: move strings to an `.xcstrings` String Catalog (plural rules, translator tooling, compile-time
  extraction) but keep **in-app** switching: SwiftUI's `Text("key")` resolves strings from the app's bundle language,
  not from `\.locale`, so the app keeps a tiny typed lookup that reads the catalog from the chosen language's
  `.lproj` bundle (or generated typed keys). Alternative: the system per-app language in Settings — native but the
  owner wants the in-app list. VoiceOver labels come from the same catalog (IDEAS «Подписи для VoiceOver»).

### 5.18 The double-tap guard (F28)

The web needed `SpotRule` because a browser delivers the second tap of a double tap to whatever has just appeared
under the finger. iOS has the same physics (a second tap is a new touch), so the *need* survives in a few places —
"Read again" erasing progress, an answer appearing where "back to a choice" was, the paywall button — but the
*mechanism* must not be a window swizzle consulted by every control.

* A. Window `sendEvent` swizzle + global `SpotRule` (current).
* B. ✔ **Three local, declarative mechanisms:**
  1. System transitions already block input while they run (push/pop/present) — covers #75, #109, #110, #148, #166.
  2. An `.armed(after: 0.45)` view modifier for controls that *appear* where the finger just was (end buttons,
     drafts, paywall, the languages list, Remove): `allowsHitTesting(armed)` set by a `.task` on appear. Local,
     visible in the view, testable in isolation — covers #112, #124, #130, #141, #161, #167, #168.
  3. Idempotent actions in the model (removing twice is a no-op, opening the same story twice is a no-op, a part
     switch to the open part does nothing) — covers #136, #57.
* C. Keep `SpotRule` but feed it from a `UIGestureRecognizerRepresentable` on the root instead of a swizzle —
  removes the private-API risk but keeps the global coupling.
* B removes `Touches.swift` (149 lines), `TouchProbe` polling, 37 `allows()` calls. The 16 recorded double-tap
  scenarios in `web-expected.json` become UI tests (a double tap at 0.08–0.8 s on each) so the behaviour is still
  proven.

### 5.19 Data and persistence (F29)

* A. `Store` (JSON text in `UserDefaults`, web key names, "wrong kind = default") + `Reading.prog` (web semantics).
* B. SwiftData — schema migrations and a model container for a handful of small values; overkill, and its
  migration failures would be worse than #113.
* C. ✔ **Keep the Store's rules, add typed, observable stores on top:** `ProgressStore`, `FavouritesStore`,
  `Settings` (lang, premium, taps), `TopWeekCounter`, each `@Observable`, each reading/writing through `Store` with
  lenient `Codable` decoding (unknown → default, #113). Views observe exactly the story they show
  (`progress[storyID]`), so no `progressRev` and no global redraw. A `Repository` protocol keeps a later server
  (top-week counts, taps, subscription — IDEAS) a drop-in.
* Covers: asset catalog images (system decoding and caching) or ImageIO downsampling to the tile size
  (`CGImageSourceCreateThumbnailAtIndex` / `UIImage.preparingThumbnail(of:)`); bake the "saturate .85, brightness
  .9" look into the JPEGs at build time (`web/build.py` step or a script) instead of filtering at draw time.
  Nuke [17] is unnecessary for local files.

### 5.20 Fonts, icons, lettering (F31–F33)

* UI text: SF Pro text styles (`.font(.body)` …) — the web redesign already moved to the system font; Dynamic Type
  for free; numbers from the redesign (34/22/17/14/13) map to `.largeTitle/.title2/.body/.subheadline/.footnote`.
* Icons: export the SVG paths once as **custom SF Symbols** (or vector assets): proper optical centring (#9, #34),
  `symbolEffect` (bounce, `drawOn` on iOS 26 [14]), weights matching text. Retire the runtime SVG parser.
* Slider lettering stays custom (it is art): bundled fonts, `onGeometryChange` fit (already used), snapshot-tested
  for every story × language × three widths (CI already renders "letterings" pages — make them assertions).

### 5.21 Haptics, Reduce Motion, accessibility (F34–F36)

* Haptics: `.sensoryFeedback` (declarative, trigger-based, iOS 17) for likes/unlikes and part/genre selection; Core
  Haptics only for the ↺ ramp (§5.8).
* Reduce Motion: read once from `@Environment(\.accessibilityReduceMotion)` inside the `Motion` helper:
  `Motion.animation(.bubble)` returns a short opacity cross-fade or `nil`; pacing ("typing…") is untouched (#161) —
  replaces 55 scattered `reduceMotion()` checks.
* Accessibility: system presentations give modality; `Button`s give traits; `accessibilityAdjustableAction` for the
  fear dial and pickers; `.accessibilityAction(named:)` for "Favourite" on tiles (already present — keep).
  `AccessibilityNotification.Announcement` for arriving messages (keep).

### 5.22 Test hooks (F37)

Move launch-argument parsing to one `#if DEBUG` `DebugLaunch` that configures the models before the first frame
(no parsing inside views); UI tests read state from accessibility values of ordinary elements (selected tab,
favourite state) instead of a polling probe.

---

## 6. Cross-cutting architecture

### 6.1 Modules (local Swift packages + a thin app target)

```
SquealCore      pure logic, no UIKit/SwiftUI: Story, StoryLibrary, Reading/Progress rules, ChatReader, Search, Fear,
                TopWeek, Shelf rules, PyJSON, JSONOrder, L10n keys        ← today's Core, kept almost as is
SquealData      Store (UserDefaults JSON), typed @Observable stores, content loading, Repository protocol
SquealDesign    Theme tokens, Motion (the one set of springs), components: OvalPicker, HeartBadge, Bubble,
                ArmedModifier, GlassToast, LongPress representable
SquealFeatures  Home, StoryPage, Chat (ChatSession + views), Favourites, Search, Menu
App             SquealApp, AppModel (composition root), Router, DebugLaunch
```
Packages compile and test independently (Core tests run in seconds without a simulator via `swift test`), and the
dependency direction (Features → Design/Data → Core) is enforced by the compiler.

### 6.2 State: one source of truth, observation, navigation

* `@Observable @MainActor` models (Observation framework): views re-render only for the properties they read.
  The genre control reads `genre`; the grid reads `stories` and `genre`; a refresh changes `stories` — the genre
  control is not even re-evaluated (#52's structural answer).
* `enum Tab: Hashable { home, favourites, search, menu }`, `enum Route: Hashable { story(Story.ID),
  chat(ChatRoute) }`, `Router { var tab: Tab; var paths: [Tab: [Route]] }`. Deep links/CI states are just router
  values.
* Value-typed rows in the chat (`struct ChatRow: Identifiable`), mutated only by `ChatSession`.
* No singletons except the composition root; services injected with `.environment(_:)`. Scroll-driven values are
  never put in the environment (Apple: it invalidates every reader [13]).

### 6.3 Gesture policy (written into `CONTRIBUTING`-style rules for every future session)

1. Use a system control when one exists: `Button`, `Toggle`, `Picker`, `List` swipe actions, `NavigationStack`
   pushes, `ScrollView` paging, `.searchable`, `.refreshable`.
2. Never put `DragGesture(minimumDistance: 0)`, `simultaneousGesture` or `highPriorityGesture` inside a
   `ScrollView` (all three are documented failure modes on iOS 18/26 [1][2][3]).
3. A custom continuous gesture inside a scroll view is a `UIGestureRecognizerRepresentable` [10] with an explicit
   `shouldBegin` (dominant axis) — UIKit's recognisers negotiate with the scroll view's pan by design.
4. Read scrolling through `onScrollGeometryChange` / `onScrollPhaseChange` / `ScrollPosition`; never find or
   observe SwiftUI's internal `UIScrollView`.
5. No swizzling, no window-level recognisers.
6. Every gesture has a tested cancel path (touch cancelled, second finger, app backgrounded).
7. Controls that appear where a finger just was are `.armed(after:)`.

### 6.4 Animation system

* `enum Motion` in `SquealDesign` is the only place with timings. Owner numbers are kept as *durations*, expressed as
  springs with zero bounce where the web used ease-out curves (a critically damped spring with the same perceptual
  duration looks the same and can be interrupted without a kink):
  `bubble = .spring(duration: 0.26, bounce: 0)`, `panel = .spring(duration: 0.4, bounce: 0)`,
  `slideIn = .spring(duration: 0.4, bounce: 0)`, `slideOut = .spring(duration: 0.15, bounce: 0)`,
  `snap = .snappy(duration: 0.3)`, `press = .spring(duration: 0.3, bounce: 0.15)`, `fade(…)`; where the owner fixed
  a curve that matters (e.g. the 0.125 s end-button fade) use `.timingCurve` with the same numbers.
* Interruptible by default (springs keep velocity [12]); sequencing with `withAnimation(…completion:)`; multi-step
  motions with `PhaseAnimator`/`KeyframeAnimator`.
* **No `CADisplayLink` in app code.** `TimelineView` only with `paused:` bound to "something is moving and visible".
  Repeating ambient motion ("breathing", typing dots) = `.animation(.easeInOut(duration: 1.2).repeatForever())` or
  `PhaseAnimator`, which the render server runs.
* Battery check on CI: a UI test that leaves Home idle for 10 s under `XCTCPUMetric` and fails above a threshold;
  the same for an idle chat and the empty Favourites.

### 6.5 Concurrency

Swift 6 language mode; app/features default to `@MainActor`; story loading and image downsampling run in
`Task.detached`/`nonisolated async` functions; timing via an injected `any Clock<Duration>`; AVFoundation callbacks
hop to the main actor explicitly. Structured cancellation replaces every token.

### 6.6 Testing strategy

| Layer | Tool | What it proves |
|---|---|---|
| Core | Swift Testing (`@Test`, parameterised) + existing XCTest cases; `web-expected.json` recordings kept | rules identical to the web (progress, search, chat walks, top week, wallpaper layout) |
| ChatSession, HomeModel, stores | Swift Testing + `TestClock` (swift-clocks [18]) | pacing and choreography in virtual time: "typing 1.2 s then message", "auto-reply after 1 s", part switch cancels the old script |
| Components and screens | swift-snapshot-testing [19] (image strategy) on iPhone SE / 16 / Pro Max sizes × en/ru/de × Reduce Motion × largest Dynamic Type | layout bugs: #5, #28, #34, #38, #42, #107, #153 |
| Real touches | XCUITest on the iOS 26 simulator (kept and extended): scroll from every element, double-tap scenarios from `spot`, cancel paths, swipe back | gesture arbitration (#169 class) |
| Performance | `XCTCPUMetric`, `XCTOSSignpostMetric.scrollDecelerationMetric` | idle cost, scroll hitches |

ViewInspector [20] is not recommended: it inspects SwiftUI's private view tree, which changes between iOS releases —
the same fragility this rewrite removes.

### 6.7 Project and CI

Keep XcodeGen (works, small); add the local packages; `SWIFT_VERSION: 6.0`; deployment target 26.0; CI as now
(Xcode 26, iOS 26 simulator) plus `swift test` for the packages (fast feedback) and the snapshot tests; record
snapshot references on CI and commit them.

---

## 7. Bugs made impossible by construction

Rough classification of the 169 entries against the chosen design (numbers from §5):

| Class | Entries (examples) | Mechanism that removes it |
|---|---|---|
| Touch arbitration (one touch, two jobs; scrolling blocked; cancelled touch acting) | 1, 11, 47, 48, 50, 54, 56, 60, 98, 103, 104, 105, 114, 118, 125, 149, 154, 155, 160, 169 | system scroll/paging/navigation/list gestures; UIKit recognisers only with explicit rules |
| Stale timers and races | 40, 57, 68, 72, 117, 132, 133, 134, 135, 141, 143, 164, 165 | structured concurrency: one task per screen/part, cancelled with it |
| Chat layout jumps | 61, 63, 64, 65, 66, 67, 69, 70, 73, 74, 76, 78, 80, 92, 93, 97, 123, 151, 157, 163 | bottom-anchored list + safe-area panel + transitions in one transaction |
| Part switch motion | 82, 85, 87, 90, 96, 101, 102 | retargeting system springs on the render clock |
| Overlays and presentation | 12, 55, 75, 109, 110, 111, 131, 137, 148, 150, 166 | NavigationStack pushes / zoom transition |
| Double tap on what appeared | 36, 106, 112, 124, 130, 136, 161, 167, 168 | system transitions + `.armed` + idempotent actions |
| Native list behaviour | 18, 24, 25, 35, 45, 84, 88, 89, 91, 95 | `List` swipe actions, `.searchable`, native bounce |
| Battery / work while idle | 126, 159 + R6 items | no display links; paused timelines |

≈ 90 entries cannot recur by construction; ≈ 40 are rules that stay rules (progress semantics, versions, content
checks, paywall logic — all already guarded by Core tests); ≈ 25 were web-only (fonts loading, viewport zoom, CSS
layers, mouse events) and ≈ 15 are owner decisions to carry over (§9). Device-only checks remain for #52 and feel.

---

## 8. Migration plan

### Rewrite or incremental?

* **Keep, unchanged in behaviour:** `ios/Squeal/Core` (1 405 lines) and its tests, content bundling, fonts, CI.
* **Rewrite:** the UI layer (6 564 lines) and `App/Touches.swift`. An in-place refactor would have to unpick
  `Taps`/`HomePulls`/`ScrollPin` from every screen at once — they are cross-cutting by design — so screen-by-screen
  replacement inside a new shell is safer and cheaper. Expected UI size after: ≈ 3 000 lines.
* Strategy: "strangler" inside one app — a new shell (`TabView` + `NavigationStack`s) hosts new screens; until a
  screen is replaced, its tab shows the old view wrapped as is (the old global `Taps` keeps working for it); the old
  UI folder is deleted at the end.

### Order (effort in focused working days for one agent session with CI round-trips of ≈30 min)

| Step | Work | Proof on CI | Days |
|---|---|---|---|
| 0. Risk spikes (throw-away targets) | (a) chat list: bottom anchor + grow + safe-area panel animation, 300 rows, typing morph; (b) Home overscroll owl + reel with geometry/phase, page hold during refresh; (c) zoom push from a grid cell + interactive dismiss on iOS 26; (d) segmented picker drag + styling vs `OvalPicker` | screen recordings from the simulator (`simctl io recordVideo`) attached to the run; owner looks at the videos | 2–3 |
| 1. Foundation | packages, Swift 6, iOS 26, `Motion`, theme tokens, `@Observable` stores over `Store`, `Router`, shell with `TabView`, DebugLaunch, snapshot test harness | unit + first snapshots | 2 |
| 2. Menu + Search + Favourites | Form/List, `.searchable`, fear dial with `scrollTransition`, List swipe actions, empty state | snapshots, UI flows for search/favourites, double-tap tests | 2–3 |
| 3. Home | slider (paging + clock), genre control, tiles (Button + long press), owl and reel over native overscroll, grid transitions | UI: scroll from every element, slider swipe/auto, refresh, reel; idle CPU metric | 3–4 |
| 4. Story page | zoom push, parts + water, ↺ with ring and Core Haptics, ♥ with KeyframeAnimator/drawOn | UI flows, snapshots | 1–2 |
| 5. Chat | `ChatSession` with clock, list, panel, drafts, endings, part switch, wallpaper, media | `TestClock` session tests replaying the 18 web walks; UI flows; recordings | 4–5 |
| 6. Pass | Reduce Motion, Dynamic Type, VoiceOver, all of BUGS.md and IDEAS decisions re-walked (update `BUGS_PASS.md`), delete old UI | full suite green | 1–2 |

Total ≈ 15–21 days including spikes (≈ 12–18 without them).

### Keeping the owner's decisions

Every IDEAS line in «Решения по интерфейсу» becomes either (a) a `Motion`/`Theme` constant with the owner's
number in a comment and the IDEAS date, or (b) an acceptance test, or (c) an explicit deviation listed in §9 and
approved before the step that needs it. `BUGS_PASS.md` is re-walked at step 6 with the new verdict column
"impossible by construction".

---

## 9. Owner decisions needed (deviations from the web spec that make the app native)

| # | Today's rule (IDEAS/BUGS) | Native proposal | Why |
|---|---|---|---|
| D1 | Owl / reel follow the finger with the web's own rubber band, page 1:1 | iOS's own rubber band; owl and reel drawn in the gap it opens | no custom pan on Home at all (§5.3) |
| D2 | ✕ closes on touch-down | closes on lift, like every iOS button | the same touch can never hit what is revealed (#75/#148) |
| D3 | Chat back: only from the very left edge (#11) | iOS 26 standard back swipe (also from the content area) | system navigation; same as every app on the phone |
| D4 | Swipe up on the story page: chat comes from below | chat always comes from the right (like Read) | one navigation stack |
| D5 | Menu → Language: words fade in place, swipe right goes back | a Settings-style list pushed (back arrow / swipe) | system navigation, Dynamic Type |
| D6 | Genre oval (and part frame/disc) look | either the iOS segmented control (zero custom code) or our `OvalPicker` (same feel as today) | choose look vs. zero code |
| D7 | Favourites: stretched red "Remove" drawn by us | the system swipe action (looks almost the same, full swipe deletes) | §5.15 |
| D8 | Search field above the fear dial at the top | iOS search field (in the tab bar on iOS 26 or at the top) | `.searchable` |
| D9 | Hold on a tile = instant like | keep (recommended) — or a context menu with a preview | optional |
| D10 | Double-tap rule everywhere (SPOT) | system transition blocking + "armed" controls where something appears | §5.18; same behaviour in all 16 recorded scenarios |

---

## 10. Second pass — critical review of the choices

1. **Is the SwiftUI chat list really enough?** The weakest link is whether `defaultScrollAnchor(.bottom, for:
   .sizeChanges)` keeps the bottom glued during an *animated* insertion, frame by frame, and how it behaves when the
   reader has scrolled up (it must not yank them down — today's `fromBottom < 8` rule). Docs do not settle this; the
   step-0 spike does. The fallback (UICollectionView + ChatLayout) is well-trodden and contained to one view.
   I considered starting with UICollectionView to avoid the risk, but it doubles the UI paradigms for the most
   complex screen and the Apple guidance of 2026 points the other way [13]; a 1-day spike is cheaper than the
   insurance.
2. **Zoom transition regressions on iOS 26** [6b]: if the spike shows the source tile vanishing after an interactive
   dismiss, use the plain push for the story page (still all the presentation benefits).
3. **Native overscroll vs. the owner's tuned pulls**: the owner spent many iterations on how the reel feels (#44, #46,
   #60). The native band will feel different; the spike produces a video for the owner before step 3. If rejected,
   option C of §5.5 applies to the pulls too: a `UIPanGestureRecognizer` representable that begins only at an edge
   and in the pull direction — still far less code than `HeldPan`, and without the introspection.
4. **Segmented control customisation on iOS 26**: Liquid Glass segmented controls restrict styling; if the oval's
   look is essential, `OvalPicker` is a small component (≈150 lines) used in three places — still a net reduction.
5. **Removing the global double-tap rule** is the riskiest *behavioural* change. Mitigation: the 16 recorded web
   scenarios plus the 146-button sweep of #168 become UI tests before the old rule is deleted.
6. **iOS 26 minimum** could cost users who stay on iOS 18; the architecture does not depend on iOS 26 except for
   cosmetics, so lowering to 18 later is a contained change (glass fallbacks, `drawOn` fallback to KeyframeAnimator).
7. **Springs vs. the owner's cubic curves**: a zero-bounce spring with the same duration is visually very close to an
   ease-out, but not identical. Where the owner tuned a curve visibly (end-button fades, slide-in 0.34 s), keep the
   exact `.timingCurve`; everything that can be interrupted uses springs.
8. **Eager VStack for chats**: fine for today's parts (≤ ~300 rows). If stories grow to thousands of messages per
   part, switch the list to `LazyVStack` with `ScrollPosition(id:)` and test scroll restoration carefully [4b].
9. **What I did not find a better option for:** the slider lettering (art, stays custom) and the reading rules
   (Core, stays). The web prototype stays the behavioural spec for *logic*; for *mechanics* the platform is the spec.

---

## 11. Summary of recommendations

* Keep Core and its web-verified tests. Rewrite the UI on system mechanisms, screen by screen, in a new shell.
* Target iOS 26, Swift 6, `@Observable` models, `NavigationStack` per tab, enums for routes.
* Gestures: system controls first; UIKit recognisers through `UIGestureRecognizerRepresentable` only with explicit
  begin rules; scroll state only via scroll geometry/phase APIs; no swizzling, no introspection.
* Motion: one `Motion` table of springs; no display links; paused timelines; render-server animations.
* Chat: `ChatSession` with one cancellable script task and an injected clock; bottom-anchored list with the panel
  as a safe-area inset; transitions for growth; retargeting springs for part switches; drafts as future messages.
* Tests: Core (as now) + clock-driven session tests + snapshots + iOS 26 UI flows + idle-CPU metrics.
* Start with four 1-day spikes; show the owner videos; then build in the order Menu → Search → Favourites → Home →
  Story page → Chat.

---

## 12. Sources

1. Apple Developer Forums — "SwiftUI Gestures prevent scrolling with iOS 18": https://developer.apple.com/forums/thread/760035
2. Apple Developer Forums — "iOS 26 Beta breaks scroll/gesture in SwiftUI chat (worked in iOS 18)": https://developer.apple.com/forums/thread/794212
3. Apple Developer Forums — "simultaneousGesture no longer works when inside a scrollView on Xcode 26": https://developer.apple.com/forums/thread/802903
4. Apple docs — Scroll views (`onScrollGeometryChange`, `ScrollPosition`, `defaultScrollAnchor`): https://developer.apple.com/documentation/swiftui/scroll-views ; Nil Coalescing — "Modern SwiftUI APIs for programmatic scrolling": https://nilcoalescing.com/blog/ModernSwiftUIAPIsForProgrammaticScrolling
   4b. Apple Developer Forums — "iOS 27: ScrollViewProxy.scrollTo no longer reaches unrealized LazyVStack rows": https://developer.apple.com/forums/thread/848608
5. Apple docs — `ScrollPhaseChangeContext` (geometry, velocity; iOS 18): https://developer.apple.com/documentation/swiftui/scrollphasechangecontext ; `onScrollPhaseChange`: https://developer.apple.com/documentation/swiftui/view/onscrollphasechange(_:)
6. WWDC24 "Enhance your UI animations and transitions" (zoom transition, works with push, sheet, fullScreenCover): https://developer.apple.com/videos/play/wwdc2024/10145/
   6b. Apple Developer Forums — zoom transition regressions on iOS 26: https://developer.apple.com/forums/thread/807208 , https://developer.apple.com/forums/thread/807715 , https://developer.apple.com/forums/thread/806833
7. MacRumors — iOS 26 adoption (June 2026: 86 % of iPhones from the last four years): https://www.macrumors.com/2026/06/09/ios-26-adoption-stats-wwdc/ ; 9to5Mac (Feb 2026 figures): https://9to5mac.com/2026/02/13/apple-announces-ios-26-usage-numbers-heres-how-they-compare/
8. WWDC22 "Optimize for variable refresh rate displays" (refresh rate follows the fastest animation; battery): https://developer.apple.com/videos/play/wwdc2022/10083/ ; Apple — Improving your app's rendering efficiency: https://developer.apple.com/documentation/xcode/improving-your-app-s-rendering-efficiency
9. WWDC25 "Build a SwiftUI app with the new design" (Liquid Glass, `tabBarMinimizeBehavior`, `tabViewBottomAccessory`, scroll edge effects): https://developer.apple.com/videos/play/wwdc2025/323/
10. WWDC24 "What's new in UIKit" (UIGestureRecognizerRepresentable, iOS 18): https://developer.apple.com/videos/play/wwdc2024/10118/ ; Swift with Majid — "Introducing UIGestureRecognizerRepresentable": https://swiftwithmajid.com/2024/12/17/introducing-uigesturerecognizerrepresentable-protocol-in-swiftui/
11. WWDC25 "What's new in SwiftUI" (`@Animatable`, list/scroll performance, Instruments): https://developer.apple.com/videos/play/wwdc2025/256/ ; WWDC Notes summary: https://wwdcnotes.com/documentation/wwdc25-256-whats-new-in-swiftui/
12. WWDC23 "Animate with springs" (velocity preserved on retarget, interruption): https://developer.apple.com/videos/play/wwdc2023/10158/
13. WWDC26 SwiftUI Group Lab (lazy stacks vs hosted UICollectionView, offset is an estimate, keep scroll state out of the environment): https://developer.apple.com/videos/play/wwdc2026/8006/
14. WWDC25 "What's new in SF Symbols 7" (Draw On/Off): https://developer.apple.com/videos/play/wwdc2025/337/ ; `SymbolEffect.drawOn`: https://developer.apple.com/documentation/symbols/symboleffect/drawon
15. Exyte Chat: https://github.com/exyte/Chat
16. ekazaev/ChatLayout (UICollectionView chat layout): https://github.com/ekazaev/ChatLayout
17. Nuke (image loading): https://github.com/kean/Nuke
18. Point-Free swift-clocks (`TestClock`, `ImmediateClock`): https://github.com/pointfreeco/swift-clocks
19. Point-Free swift-snapshot-testing: https://github.com/pointfreeco/swift-snapshot-testing
20. ViewInspector: https://github.com/nalexn/ViewInspector
21. Stream — building a SwiftUI message list (List vs LazyVStack for chat): https://getstream.io/blog/build-message-list-swiftui/
