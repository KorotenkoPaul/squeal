# Squeal for iPhone — how to build it natively (research, version 2, 2026-11-23)

> Research only: nothing in `ios/` was changed. Version 2 replaces the first version (commit 3284633) after the
> owner asked for a deeper study whose goal is that **all 169 bugs of `BUGS.md` become impossible**, each by a named
> mechanism. It studies every screen and line of the current SwiftUI app (`ios/Squeal`, ≈ 8 400 lines: App 420,
> Core 1 405, UI 6 564), all 169 entries of `BUGS.md`, `ios/BUGS_PASS.md`, `ios/PLAN.md`, the 47 owner decisions in
> `IDEAS.md`, the source code of mature chat apps and libraries (Signal-iOS, Telegram-iOS, Exyte Chat, ChatLayout,
> MessageKit, Ice Cubes), and Apple's documentation, WWDC sessions and developer-forum bug reports for each API.

## Кратко для владельца (по-русски)

1. Сейчас приложение — перевод сайта на Swift: вручную сделано то, что iPhone умеет сам (листание, свайп назад,
   списки, анимации). Баги рождаются именно там (например, №169).
2. Я прошёл **все 169 багов по одному** и для каждого записал, *почему* он был и *что в новом устройстве
   приложения делает его невозможным* (раздел 9). Итог по всем 169:
   - **109** — невозможны «по устройству»: системный механизм просто не позволяет так сломаться;
   - **40** — невозможны «по данным»: такое состояние нельзя даже записать в программе;
   - **15** — ловятся автоматическим тестом, который упадёт, если баг вернётся (тест назван в таблице);
   - **5** — были только в браузере (масштаб двойным касанием, шрифты из интернета и т. п.); в iPhone-приложении
     их причины нет — объяснено, почему.
   Ни одной строки без механизма. Ваши 47 решений по интерфейсу (IDEAS) тоже разобраны (раздел 10).
3. Главное изменение после углублённой проверки: **чат строим на том же системном списке, что Signal и
   «Сообщения»** (UIKit + проверенная библиотека ChatLayout), а не на SwiftUI-прокрутке. Я проверил, как сделаны
   зрелые чаты, и нашёл, что SwiftUI-способ «держать низ чата» у многих приложений даёт рывки.
4. Логику (истории, прогресс, поиск, выборы, бесплатные тапы) **оставляем** — она хорошая и проверена тестами.
   Экраны **пишем заново** на системных деталях iPhone.
5. Запрещённые приёмы (те, что вызвали №169 и подобные) будут **запрещены автоматической проверкой кода**:
   программа просто не соберётся, если кто-то их напишет.
6. Новый «записыватель движения» в тестах проверяет каждый кадр анимаций чата (ничего не прыгает, не налезает),
   как это делали веб-тесты.
7. Минимальная версия — **iOS 26** (как на вашем телефоне). Приложение будет подстраиваться под любой размер окна
   (в iOS 27 iPhone-приложения можно растягивать на iPad и Mac).
8. Несколько ваших решений придётся заменить стандартом iPhone (раздел 12), например: «сова» и «рулетка» тянутся
   системной «резинкой», ✕ срабатывает при отпускании пальца. Каждое — только с вашего «да».
9. Порядок: 4 короткие пробы рискованных мест с видео для вас → Меню → Поиск → Избранное → Главная → История →
   Чат. Оценка — **18–24 рабочих дня**.
10. Напоминание (по `CLAUDE.md`): когда начнём писать Swift-версию — проверить на iPhone баг №52: потянуть главную
    вниз 5–10 раз на разных жанрах, надпись жанра не должна мигать.

---

## 1. What changed since version 1

| Area | Version 1 | Version 2 (and why) |
|---|---|---|
| Chat list | SwiftUI `ScrollView` + `defaultScrollAnchor(.bottom, for: .sizeChanges)`, prototype-gated | **`UICollectionView` + ChatLayout + UIKit cells.** Evidence (§5): every mature chat with insertion choreography uses a collection-view layout (Signal, Telegram, Exyte, ChatLayout); `.sizeChanges` anchoring "pulls the reader down" and needed hand fixes in several apps; `UIHostingConfiguration` cells do not animate their resize |
| Genre oval / part selectors | segmented `Picker` preferred | **one `OvalPicker` everywhere.** A `UISegmentedControl` is a `UIControl`, and `UIScrollView.touchesShouldCancel(in:)` returns `false` for controls — a vertical drag starting on it would not scroll Home: the #169 class again |
| Owl refresh hold | animate `contentMargins` | **`.refreshable` holds the page**, the eyes are an overlay pinned to the content's top; no source shows `contentMargins` can hold a scroll view during a bounce |
| Slider endless wrap | copies at the ends + silent jump at rest | **virtual index space** (n × 1 000 cards): no jump ever happens; forum threads show silent repositioning of paged SwiftUI scroll views is fragile |
| Tiles | already `Button` + long press | adds evidence that today's `PressSurface` fix of #169 itself depends on `touchesEnded`, reported as not delivered inside scroll views on newer iOS |
| Proof | ≈ 90 / 169 "impossible" | **169 / 169** with a named mechanism each (§9) |
| Testing | unit, snapshot, UI, perf | adds a DEBUG **motion recorder** (frame-by-frame invariants of the chat and lists), SwiftLint rules that forbid the dangerous APIs, `performAccessibilityAudit`, a CI matrix of iOS 26.0 + newest 26.x + scheduled newest beta |
| Size handling | portrait only | **any scene size**: iOS 27 makes iPhone apps resizable on iPad and in iPhone Mirroring [27]; no `UIScreen.main` (lint) |
| Unified motion | SwiftUI springs | the same `Motion` springs drive UIKit too, via `UIView.animate(_ animation: SwiftUI.Animation)` (iOS 18) [12b] |
| Effort | 15–21 days | 18–24 days (chat in UIKit, motion recorder, lint, matrix) |

---

## 2. Method and sources

Read in full: all Swift files of `ios/Squeal/**`, the test targets, `project.yml`, the CI workflow, `BUGS.md` 1–169,
`ios/PLAN.md`, `ios/BUGS_PASS.md`, `IDEAS.md`. Cloned and read (shallow, read-only, in the scratchpad):
Exyte Chat, ChatLayout, MessageKit, Ice Cubes, Pow, swift-clocks, swift-snapshot-testing, SwiftUI-Introspect, the
`Signal/ConversationView` folder of Signal-iOS; read Telegram-iOS's `ListView.swift`. Web: Apple documentation, WWDC
2019–2026 sessions, Apple Developer Forums threads for the known iOS 18/26/27 bugs of each API, articles by
recognised engineers. Every source is numbered in §15 and cited as [n].

How alternatives were judged, in order: (1) correctness in edge cases — touch cancelled, second finger, fast repeats,
Reduce Motion, Dynamic Type, VoiceOver, resizing, background, Low Power Mode; (2) how many past bugs it makes
impossible by construction; (3) battery and CPU — does anything run per frame on the main thread while nothing moves;
(4) code we own; (5) testability on CI without a phone; (6) risk — private API, known regressions, device-only
behaviour.

Mechanism classes used in §9 and §10:

* **C — by construction.** The structure or API used cannot express the bug (e.g. there is no flying copy, so it cannot
  be 8 px off; the system's gesture owns the touch, so two jobs cannot run at once). Where the dangerous API could be
  re-introduced, a SwiftLint rule makes the build fail.
* **S — by state model / types.** The illegal state cannot be represented (an enum, a single source of truth, a
  value computed by one pure function).
* **T — by an automated test** that fails if the bug comes back; the test is named.
* **W — web-only**, with the reason its cause cannot exist in a native app.

Every C and S row also names a test, so each bug has a structural guard *and* a regression test.

---

## 3. Diagnosis — what is most wrong now, and why it produces bugs

The Core layer (`ios/Squeal/Core`) is good: pure Swift, no UI, verified against recordings of the web prototype
(`web-expected.json`: 18 chat walks, 285 search queries, 100 progress cases, 16 double-tap scenarios). Keep it.
The problems are in the UI layer and share eight root causes.

**R1. The browser's event loop was re-created by hand.** 37 `asyncAfter`, 7 own `CADisplayLink` loops (`FrameLoop` ×6
+ `SliderEngine`), 8 `tween()` call sites, `Timer`s, and 36 `token`/`gen`/`rev` guards against stale callbacks;
`PreviewView.glide` re-schedules itself every 1/120 s. Every callback can fire after the screen, the part or the intent
changed; tokens patch that one race at a time (#40, #57, #68, #72, #117, #132–135, #141, #143).

**R2. The app fights the system's touch handling.** `UIWindow.sendEvent` is swizzled so a global `Taps.shared` sees
every touch (37 `allows()` calls); `ScrollFinder` digs out SwiftUI's private `UIScrollView` and `HeldPan` makes its pan
wait for ours; hit-testing by comparing points with `.global` frames; `DragGesture(minimumDistance: 0)` as a press
detector. Direct cause of #169 (zero-distance drags and, on iOS 26, even `simultaneousGesture` inside a `ScrollView`
block scrolling [1][2][3]) and of #48, #50, #54, #98, #103–105, #114, #118, #149, #154, #155, #160.

**R3. Layout is measured, published and replayed.** Rows publish `size`/`slot`; `GrowLayout`/`FootLayout` read the clock
inside `sizeThatFits`; `FootLayout` writes state during layout; `ScrollPin` sets `contentOffset` from KVO callbacks.
Feedback loops → one-frame jumps (#61, #64, #66, #67, #69, #73, #76, #92, #93, #97, #151, #157, #163).

**R4. State is scattered and redraws are forced.** One `ObservableObject` invalidates everything; `progressRev` and
`let _ = model.progressRev`; string routes; statics (`BarMemory.seen`, `FavRows.probe`, `ChatDebug`); each chat row a
class mutated from five places.

**R5. Navigation is a ZStack of overlays.** Edge swipe on the window, manual `isModal`, safe areas read from
`UIApplication…windows.first`, `UIScreen.main.bounds` for sizes, an `asyncAfter` to remove the preview under the chat
(#11, #12, #75, #109, #110, #111, #148).

**R6. Battery: work every frame while nothing moves.** The slider's display link runs at up to 120 Hz all the time
Home is on screen; the empty Favourites `TimelineView(.animation)` never pauses; typing dots, the hint's breathing, every
chat row and the bottom panel re-evaluate per frame; the wallpaper redraws a whole `Canvas` per frame; covers are
decoded full-size on the main thread and filtered at draw time. Apple: the display rate follows the fastest animation
on screen, so a secondary element at 120 Hz drains the battery [8].

**R7. Web fidelity against the platform.** Fixed Avenir sizes (no Dynamic Type), CSS béziers copied, rubber bands in JS
numbers, test hooks in production views, iOS 17 target forbidding the APIs that replace the hand-made parts.

**R8. Even the newest fix is fragile.** `PressSurface` (the #169 fix) reads raw `touchesBegan/Ended` of a view inside a
scroll view; a 2026 forum report describes `touchesEnded` not being delivered inside a `UIScrollView` on newer iOS while
it was on iOS 18 [3b]. Fixing one hand-made touch path with another keeps the app exposed to every iOS update.

---

## 3b. Inventory: every feature, where it lives, how it works now, which BUGS touched it

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

---

## 4. Platform baseline

| Option | Gives | Costs |
|---|---|---|
| iOS 17 (now) | reach | no scroll geometry/phase, `ScrollPosition`, `UIGestureRecognizerRepresentable`, zoom transitions, SwiftUI animations in UIKit — forces the hand-made parts |
| iOS 18 | all APIs the architecture needs [4][5][6][10][12b] | two visual generations to design/test with one phone and one simulator |
| **iOS 26** ✔ | the above + Liquid Glass, `glassEffect`, tab bar minimise, scroll-edge effects [9], `@Animatable` [11], SF Symbols *Draw On* [14], `interactiveContentPopGestureRecognizer` control [29]; one OS family = what CI and the owner run | excludes iPhones still on iOS 18: Apple's June 2026 figure is 86 % of four-year-old iPhones on iOS 26 [7]; iOS 27 shipped in September, so iOS 26 is "current minus one" |

Swift 6 language mode, Xcode 26's default `MainActor` isolation for app/feature targets, SwiftLint in CI.
Scene size: **assume any size.** iOS 27 runs iPhone apps resizable in iPhone Mirroring and on iPad;
`UIRequiresFullScreen` no longer opts out [27]. Portrait-only stays for the phone, but no code may read the screen
size (lint rule `no_uiscreen_main`; today `ChatController`, `SearchView` and `PreviewView` do).

---

## 5. Resolving the open question: how to build the chat list

**Question from v1:** can a SwiftUI `ScrollView` keep the newest message glued above the panel while a bubble grows
from its corner and the room opens at the same pace, never jumping, never pulling a reader who scrolled up?

**Evidence, from source code and reports:**

| App / library | How the message list is built | What it shows |
|---|---|---|
| Signal-iOS | `UICollectionView` with its own `ConversationViewLayout: UICollectionViewLayout` (`Signal/ConversationView/ConversationViewLayout.swift`) and `targetContentOffset(forProposedContentOffset:)` handling [16b] | a top messenger chose a custom collection-view layout |
| Telegram-iOS | own `ListView` on AsyncDisplayKit nodes (`submodules/Display/Source/ListView.swift`) [16c] | full custom engine — beyond our scale |
| Exyte Chat | `UITableView` **rotated 180°**, cells built with `UIHostingConfiguration` and rotated back (`UIList.swift`: `tableView.transform = CGAffineTransform(rotationAngle: .pi)`); iOS 17+ [15] | even a SwiftUI chat library drops to UIKit for the list; the flip trick reverses VoiceOver order and has iOS 26 bar-fade bugs [20b] |
| ChatLayout | custom `UICollectionViewLayout`; `keepContentOffsetAtBottomOnBatchUpdates`, `keepContentAtBottomOfVisibleArea`, delegate hooks `initialLayoutAttributesForInsertedItem` / `finalLayoutAttributesForDeletedItem`; not rotated; iOS 15–27, Swift 6.3, MIT [16] | exactly our two needs: bottom kept during animated batch updates, and per-item insertion attributes (scale from a corner) |
| MessageKit | `UICollectionView` + flow-layout subclass [16d] | older, less control of insertion |
| Ice Cubes (Mastodon) | SwiftUI `ScrollView` + `LazyVStack` + `.safeAreaInset(edge: .bottom)`; after each new message `DispatchQueue.main.async { withAnimation { proxy.scrollTo(bottomAnchor) } }` (`ConversationDetailView.swift`) [17b] | the SwiftUI way is two steps (insert, then scroll) — precisely the jump the owner rejected (#61) |
| Several 2026 SwiftUI chat projects | `.defaultScrollAnchor(.bottom, for: .sizeChanges)` "pulls the reader down as the turn grows"; fixes narrowed it to `.initialOffset` and added hand-written offset restoration [4c] | `.sizeChanges` does not respect a reader who scrolled up (our rule: "scrolled up meanwhile: left where it is", #74, #151) |
| Apple forum | `UIHostingConfiguration` cells "shrink without animation"; `selfSizingInvalidation` did not help [16e] | SwiftUI cell content cannot drive the animated resize of the typing → message morph |
| Apple, WWDC26 lab | lazy stacks are usually enough for lists; content offset in lazy stacks is an *estimate* [13] | fine for plain lists; not for pixel-exact bottom anchoring |

**Decision (definite):**

* **Primary:** the conversation is a `UICollectionView` with **ChatLayout** (pinned exact version), wrapped once in
  `ChatListView: UIViewControllerRepresentable`. Cells are **UIKit views** (a bubble view whose background layer is
  drawn by `CAShapeLayer`, text in `UILabel` with `adjustsFontForContentSizeCategory`), so a cell's size change animates
  with its frame. Data flows through a diffable snapshot from `ChatSession`. Every change is one
  `UIView.animate(Motion.bubble) { collectionView.performBatchUpdates { … } }` (SwiftUI `Animation` values drive UIKit
  since iOS 18 [12b]), with `keepContentOffsetAtBottomOnBatchUpdates = true` only while the reader is at the bottom
  (ChatLayout exposes the flag; when the reader scrolled up, it is off and nothing moves under them).
  - New bubble: `initialLayoutAttributesForInsertedItem` returns the final frame with
    `transform = translate(corner) · scale(0) · translate(−corner)`; the layout moves every other cell in the same
    animation, so the room opens at the bubble's pace (#97, I33, I43).
  - Typing → message: the same item is *reconfigured* inside an animated batch update; the bubble layer animates from
    the typing size to the message size from its pointed corner; the words fade (#78, #80, I31, I32).
  - Bottom panel: a SwiftUI view outside the list; its height change and the list's `contentInset.bottom` change are
    made in the same `UIView.animate(Motion.panel)` (#64, #92, #93, I34, I36).
  - Part switch: per-cell horizontal transforms animated with springs (`Motion.slideOut/slideIn`), retargeted
    from the presentation value; arrivals start in the leave animation's completion (#82, #85, #87, #90, #96, #101).
* **Fallback 1** (if ChatLayout misbehaves in the step-0 spike): our own append-only `UICollectionViewLayout`
  (≈ 300 lines: vertical stack of self-sized items, bottom-keeping offset in `prepare(forCollectionViewUpdates:)` and
  `targetContentOffset(forProposedContentOffset:)`) — Signal's approach.
* **Fallback 2** (only if the owner prefers fewer UIKit parts and accepts slight differences): SwiftUI eager `VStack` +
  `defaultScrollAnchor(.bottom, for: .initialOffset)` + manual bottom-following; rejected as primary for the evidence above.

Why not the rotated-table trick (Exyte): reversed VoiceOver swipe order [20b], reversed scroll-indicator side,
transformed coordinate spaces that break bar effects on iOS 26 [20b].

---

## 6. Feature by feature: alternatives and choice (final)

✔ marks the choice. "Kills" = bug numbers made impossible (details per bug in §9).

### 6.1 App shell and tabs (F1)
A. custom tab bar in a ZStack (now) · ✔ B. `TabView` + `Tab` API, Liquid Glass bar, `Tab(role: .search)` for Search,
each tab its own `NavigationStack(path:)` · C. custom glass bar. Pitfalls: `.searchable` placed on the `TabView`
applies to every tab and resets per tab [21b] → put it only inside the search tab, keep the query in the model; tab bar
can show early during swipe-back on iOS 26 [29b] → snapshot the transition midpoint. Kills #21.

### 6.2 Story page and chat presentation (F2, F3)
A. overlays (now) · B. sheet/fullScreenCover · ✔ C. pushes on the tab's `NavigationStack`: story page with
`.navigationTransition(.zoom(sourceID:in:))` from the tile (interactive dismiss by drag-down/edge) [6]; chat a normal
push with tab bar hidden; on arrival of the chat the `.story` route is replaced by `.chat` (Back lands where the story
was opened) · D. custom container controller.
Pitfalls and their guards: zoom transitions have iOS 26 regressions on interactive dismissal (source disappears,
flash in light mode) [6b] → `FlowTests.zoomDismissKeepsSourceVisible` + a one-line flag to fall back to a plain push;
`navigationBarBackButtonHidden` does not disable the back gesture with zoom [29c] (we do not hide it); iOS 26 adds the
content-area back swipe [29] → the story page's horizontal part-frame drag must win: its recogniser is required to
fail before `interactiveContentPopGestureRecognizer` (`GestureTests.storyPagePartDragDoesNotPop`). Kills #11, #12, #55,
#72, #75, #102, #109, #110, #111, #118, #125, #131, #133, #137, #148, #150.

### 6.3 Home: scrolling, owl refresh, random reel (F7, F8)
A. own pan on SwiftUI's private scroll view (now) · ✔ B. **native scrolling, decorated:** `.refreshable { await
model.refresh() }` holds the page while the eyes blink, waits for a resting finger, releases natively; the eyes are an
overlay pinned to the content's top whose lids are a function of the overscroll read with `onScrollGeometryChange`
[4][5]; the system spinner is hidden (`UIRefreshControl.appearance().tintColor = .clear`, public API; spike verifies;
fallback: the eyes' own backdrop covers it). The reel lives in the bottom overscroll gap, its turn = overscroll × 0.9;
`onScrollPhaseChange` (interacting → decelerating, with geometry and velocity [5]) decides "release past the line →
pick". · C. `UIRefreshControl` subclass found by introspection (silently stops working when the hierarchy changes [22])
· D. Home as a UIKit collection view with a custom refresh control (works, but moves the most SwiftUI-friendly screen
to UIKit).
Pitfalls: `.refreshable` misaligns tap targets in some states on iOS 18/26 [23b] → `GestureTests.tapTileRightAfterRefresh`;
the refresh threshold becomes the system's (owner decision D1). Kills #21, #22, #44, #46, #47, #98, #103, #104, #105,
#114, #134, #135.

### 6.4 Slider (F4)
A. display-link engine (now) · ✔ B. horizontal `ScrollView` + `LazyHStack` over a **virtual index space**
(`0 ..< n·1000`, starts in the middle, card = `index mod n`), `.scrollTargetBehavior(.viewAligned)`,
`.containerRelativeFrame(.horizontal)` for card width, `.scrollPosition(id:)` binding. Auto-advance: a `Task` that sleeps
the card's remaining time, then `withAnimation(Motion.slide) { position = index + 1 }`; it is cancelled whenever
`scrollPhase != .idle`, the scene is not active, Home is covered, or a refresh runs. Worm dots and the time line: pure
functions of the fractional index (`onScrollGeometryChange(for: Double.self)`), the line is a subview of the pill.
· C. `TabView(.page)` · D. UIKit paging collection view (fallback if the forum bugs below bite).
Pitfalls and guards: paging with `contentMargins` misaligns [24b] → use `.viewAligned` + `containerRelativeFrame`;
`ScrollPosition` *object* ignored commands in an iOS 26 beta [24c] → use the `id` binding; a programmatic target set
while the user drags hangs a paged view [24a] → never set the position unless `scrollPhase == .idle`; position off when
the start index ≠ 0 on iOS 26 [24d] → `SnapshotTests.sliderStartsOnSavedCard` and `GestureTests.sliderBothWays`.
Kills #1, #2, #3, #4, #54, #71, #94, #115, #126, #128, #143, #147, #169.

### 6.5 Genre oval, story-page part frame, chat part disc (F5, F10, F17) — one `OvalPicker`
A. three hand-made controls (now) · B. segmented `Picker` — **rejected for scrolling pages**: a `UISegmentedControl` is a
`UIControl`, and `UIScrollView.touchesShouldCancel(in:)` "returns false" for controls by default, so a vertical drag
starting on it does not scroll the page [30] — the #169 failure again · ✔ C. `OvalPicker` in `SquealDesign`: `HStack`
of `Button`s (tap), one capsule lens whose centre/width are a pure function of a continuous `position` (width blends
between neighbours, as now), drag = `UIPanGestureRecognizer` via `UIGestureRecognizerRepresentable` [10] with
`maximumNumberOfTouches = 1` and `gestureRecognizerShouldBegin` = `|vx| > |vy|`; release/tap →
`withAnimation(Motion.snap) { position = Double(index) }`. On the story page it is required to fail the content-pop
recogniser first (§6.2). Kills #13, #14, #48, #49, #50, #52, #56, #86, #149, #160, #169.

### 6.6 Tiles: tap, hold-to-like, heart (F6, F12)
A. `PressSurface` (now; fragile, R8) · B. `Button` + `.simultaneousGesture(LongPressGesture)` — rejected (iOS 26
simultaneous gestures in scroll views [3]) · ✔ C. `Button` (tap, pressed look from `ButtonStyle.isPressed`) + a
`UILongPressGestureRecognizer` representable (0.38 s, 8 pt) — the UIKit long press fails as soon as the scroll view's
pan begins, by design · D. `.contextMenu` (most native hold; changes the owner's decision — option D9).
Heart: `KeyframeAnimator` triggered by a like *event* (not by state) [12c]; on iOS 26 a custom SF Symbol with
`.symbolEffect(.drawOn)` for the pen [14]; `.sensoryFeedback(.impact(weight: .light), trigger: likeEvent)` [25] — the
trigger is a value type (class triggers can be compared stale [25]). Kills #19, #20, #51, #99, #140, #160, #169.

### 6.7 Grid and refresh fade (F9)
`LazyVGrid`; genre change = container `.id(genre)` + `.transition(.opacity.combined(with: .offset(y: 18)))` in one
`withAnimation`; refresh = `.transition(.opacity)`. With Observation, `GenreBar` reads only `genre`, so a refresh cannot
re-evaluate it (#49, #52 — verified by a DEBUG body-evaluation counter). Kills #49, #52, #100.

### 6.8 Story page content (F10, F11, F12)
Water: `Canvas` wave drawn from an animatable phase (`@Animatable` [11]) driven by `KeyframeAnimator` (rise 1 s, waves
3.3 s, drain 1 s); nothing runs when calm. ↺: `Button` (tap = selected part) + the long-press representable for "all
parts"; ring = `Circle().trim(to:)` animated linear 0.3 s and wound back by retargeting; ramp haptic = Core Haptics
`CHHapticAdvancedPatternPlayer` with one continuous event and an intensity `CHHapticParameterCurve` 0.2 → 1.0 over
0.3 s, stopped on release [26]. ✕ = toolbar button (touch-up, D2). Kills #7, #8, #9, #10, #53, #137, #139, #140, #153.

### 6.9 Chat list (F13, F14, F16) — see §5
Kills #32, #42, #61, #63, #64, #65, #66, #67, #69, #73, #76, #78, #80, #88, #89, #91, #92, #93, #95, #97, #125, #151,
#157, #163.

### 6.10 Chat pacing and lifetime (F15, F18, F19, F20)
A. `ChatController` with work items, timers, tokens, time guards (now) · B. Combine · ✔ C. `@Observable @MainActor
final class ChatSession` with value-typed rows and **one script `Task`**, started by `.task(id: route)` on the chat
screen; `ChatReader` (Core) decides *what*, the session adds *when* with an injected `Clock` (`swift-clocks`'
`TestClock` in tests [18]). The clock is wrapped so it **pauses while the scene is not active** (same rule as the
slider, #149). Pending part switch = one `Task?` field replaced on every tap (only the last survives, #57) and cancelled
with the session (#132). Pick while scrolled up = `await list.scrollToBottom()` then send (#74). End reveal waits
for the pick animation's completion (#142). Kills #39, #40, #41, #57, #68, #72, #74, #117, #132, #142, #152, #164.

### 6.11 Choices as drafts (F19)
The draft cell *is* the future message cell (same class, same width); pick = one batch update that fills the chosen
draft, removes the others (they slide right), and the chosen cell moves up by layout. Drafts are `.armed(after: 0.6)`.
Kills #70, #79, #81, #123, #124, #129.

### 6.12 Part switch (F17)
Per-cell springs retargeted from the presentation value (UIKit animations with `beginFromCurrentState` semantics are the
default for `UIView.animate` springs [12]); a `SwitchPhase` enum (`idle`, `leaving`, `arriving`) in the session;
arrivals start in the completion of the departures; only `transform` is animated, never `alpha` (lint rule in the chat
module). Kills #55, #63, #82, #85, #87, #90, #96, #101, #102.

### 6.13 Wallpaper (F23)
A. own physics + per-frame `Canvas` · B. SpriteKit · ✔ C. one view per doodle animated by the system: fly-in spring;
fall = a `CustomAnimation` implementing `y = ½gt²` that merges with an in-flight fly-in (`shouldMerge`) [12d];
`Wall` state machine in Core decides groups and timings · D. `Canvas` + paused `TimelineView` (fallback). Doodles are
vector assets, not parsed paths. Kills #58, #62, #159.

### 6.14 Voice and round video (F21, F22)
`@Observable MediaCenter`, one sound at a time; `AVPlayer` for both; `AVQueuePlayer` + `AVPlayerLooper` for silent
previews [26b]; interruption and route-change notifications reset the look [26c]; previews play only while visible
(`onScrollVisibilityChange` / cell display callbacks) — today every circle loops a decoder forever; label =
`rounded(currentTime)` capped by `dur`. Kills #41, #149, #163, #166.

### 6.15 Favourites (F24)
✔ `List` + `.swipeActions(edge: .trailing, allowsFullSwipe: true)`, sections per genre, card look via
`.listRowBackground(Color.clear)` and the card inside the row. Pitfalls: iOS 26 swipe-action glitches in sectioned
lists (FB19602925) and rounded-corner inconsistencies with custom row backgrounds [21a] → `MotionTests.favouritesRemovalHasNoJump`
+ fallback: our own row swipe with the pan representable. Empty state: `KeyframeAnimator` that plays once. Kills #18,
#84, #136, #160, #166, #167.

### 6.16 Search and fear dial (F25, F26)
✔ `Tab(role: .search)` + `.searchable` inside that tab only [21b][21c]; the list bounces always; with an empty query the
same fear list shows (nothing swaps under the finger). Fear dial: horizontal `ScrollView`, `.viewAligned`,
`.contentMargins` from the row's own width, `.scrollTransition` for the look (render-time) [31], level set on
`onScrollPhaseChange → .idle`. Kills #24, #25, #35, #36, #37, #45, #106, #138, #158, #167.

### 6.17 Menu and languages (F27, F30)
`Form` "like Settings" (as the web redesign does); Language pushed (D5); strings in a String Catalog read through a
tiny typed lookup for the in-app language (SwiftUI `Text` resolves from the bundle language, not from `\.locale`).
Kills #28, #107, #153.

### 6.18 The double-tap guard (F28)
✔ Three local mechanisms instead of a window swizzle: (1) system transitions block input while they run; (2) an
`.armed(after:)` modifier — `allowsHitTesting(armed)` set by a `.task` on appear — only on controls that *appear where a
finger just was* (end buttons, drafts, paywall, the new part's tap target, the languages list, Remove); (3) idempotent
model actions. The 16 recorded web scenarios and the 146-control sweep of #168 become `DoubleTapTests`. Kills #36, #75,
#112, #124, #130, #141, #148, #161, #166, #167, #168.

### 6.19 Data (F29), fonts/icons (F31–F33), haptics, Reduce Motion, accessibility (F34–F36), test hooks (F37)
* Data: keep `Store` rules; typed `@Observable` stores (`ProgressStore`, `FavouritesStore`, `Settings`, `TopWeek`);
  SwiftData rejected (migration risk for a few small values).
* Covers: asset catalog or ImageIO downsampling (`preparingThumbnail(of:)`); colour grading baked at build time.
* UI text: SF Pro text styles, Dynamic Type; chat cells use `UIFontMetrics`. Icons: custom SF Symbols.
* Reduce Motion: one `Motion` helper reads `accessibilityReduceMotion`; pacing never depends on it (#161).
* Accessibility: system modality; `AccessibilityNotification.Announcement` for arriving messages; `XCUIApplication.performAccessibilityAudit()` in UI tests [28].
* Test hooks: one `#if DEBUG` `DebugLaunch`; state read from ordinary accessibility values.

### 6.20 Libraries evaluated

| Library | Verdict | Why |
|---|---|---|
| ChatLayout [16] | **use** (pinned) | bottom-keeping batch updates + insertion attributes; not rotated; iOS 15–27 |
| swift-clocks [18] | **use** (tests + injected clock) | deterministic time for the chat script |
| swift-snapshot-testing [19] | **use** | layout matrix (sizes × languages × Dynamic Type × Reduce Motion) |
| SwiftLint | **use** (CI) | custom rules ban the dangerous APIs (§7.3) |
| Exyte Chat [15] | reject | rotated table (VoiceOver order), input-bar-centred design |
| MessageKit [16d] | reject | flow-layout based, less control, heavier |
| TCA / swift-dependencies [32] | reject | Point-Free itself does not recommend it for newcomers; plain Observation + an injected clock covers our needs |
| SwiftUI-Introspect [22] | reject | reaches UIKit views through the hierarchy; silently stops when Apple changes it — the R2 problem in library form |
| Pow [33] | reject | effects we do not need |
| Lottie | reject | the owl eyes are three PNGs and a mask; Lottie needs After Effects assets and adds size |
| Nuke [17] | reject | covers are local; system decoding/downsampling suffices |
| ViewInspector [20] | reject | inspects SwiftUI's private tree; breaks across releases |

---

## 7. Architecture

### 7.1 Modules
```
SquealCore      pure logic: Story, StoryLibrary, Reading/Progress, ChatReader, Search, Fear, TopWeek, Shelf rules,
                Wall (doodle state machine), PyJSON, JSONOrder, ContentValidator, Motion spec numbers
SquealData      Store, @Observable stores, content loading, Repository protocol (server later)
SquealDesign    Theme tokens, Motion (SwiftUI.Animation values used by SwiftUI and UIKit), OvalPicker, HeartBadge,
                ArmedModifier, LongPressRepresentable, PanRepresentable, Toast
SquealChat      ChatSession, ChatListView (UICollectionView + ChatLayout + UIKit cells), panel, header, MediaCenter
SquealFeatures  Home, StoryPage, Favourites, Search, Menu
App             SquealApp, AppModel (composition root), Router, DebugLaunch
```

### 7.2 State
`@Observable @MainActor` models; enum `Tab`, enum `Route { story(Story.ID), chat(ChatRoute) }`, `Router` with one path
per tab; value-typed chat rows; no singletons; nothing per-frame in the environment [13].

### 7.3 Gesture policy, enforced
1. System controls first. 2. In feature code, no `DragGesture(minimumDistance: 0)`, `simultaneousGesture`,
`highPriorityGesture`, `touchesBegan/Ended` overrides, method swizzling, window recognisers, `.global` coordinate
space, `UIScreen.main`, `DispatchQueue.main.asyncAfter`, `Timer`, `CADisplayLink` — **SwiftLint custom regex rules**
(`no_zero_distance_drag`, `no_simultaneous_gesture`, `no_raw_touches`, `no_swizzle`, `no_global_space`,
`no_uiscreen_main`, `no_async_after`, `no_timer`, `no_display_link`, `no_alpha_in_part_switch`) fail the CI build;
the DEBUG motion recorder is the one whitelisted display link. 3. Custom continuous gestures are the two
representables in `SquealDesign`, each with a `shouldBegin` rule, one touch, reset on `.cancelled` (unit-tested with a
fake recogniser state). 4. Scroll state only through scroll geometry/phase/position APIs.

### 7.4 Motion
One `Motion` table (owner numbers as durations, zero-bounce springs where the web used ease-outs; exact
`.timingCurve` where the owner tuned a curve), used by SwiftUI and — through `UIView.animate(_:changes:)` — by UIKit
[12b]. Springs keep velocity on retarget [12]. No display links; `TimelineView` only with `paused:`; ambient loops
(`typing…` dots, breathing hint) are `repeatForever`/`PhaseAnimator` on the render server.

### 7.5 Concurrency
Swift 6; one task per screen/session; injected pausable clock; AVFoundation callbacks hop to the main actor.

### 7.6 CI matrix
Unit + content + session tests (`swift test`, seconds); snapshot + UI + motion + perf tests on the iPhone simulator
with **iOS 26.0** and the **newest 26.x** runtime (`xcodebuild -downloadPlatform`), plus a weekly scheduled run on the
newest Xcode beta (catches the next #169 before users do); `-retry-tests-on-failure` against the Xcode 26 UI-test
hangs reported in CI services [19b]; snapshot references recorded on the CI image only.

---

## 8. Test catalogue (names used in §9 and §10)

| Suite | Kind | Contents |
|---|---|---|
| `CoreTests` | Swift Testing, `swift test` | existing web-verified cases (progress, chat walks, reading time, search, top week, store, fingerprint, first language) + new `dotsLayoutAcrossWrap`, `reelPickRule`, `ovalShapeBlend`, `queryTrim`, `setFavouriteIsAbsolute`, `removeIsIdempotent`, `topWeekCountsOpeningsOnly`, `motionSpecMatchesIdeas`, `partSwitchMakesOldDoodlesFall` |
| `ContentTests` | on bundled stories | existing `storyTextIsClean`, `storyShape`, `wallpaperNamesExist`, `everyStoryOpensInEveryState` + new `noLongOneSidedRuns`, `longestPathEqualsMessages` |
| Session tests | Swift Testing + `TestClock` | `ChatSessionTests` (pacing, switches, picks, leaving, background), `SliderClockTests`, `HomeModelTests`, `StoryPageModelTests`, `MediaCenterTests`, `HapticsTests` |
| `LayoutTests` | UIKit cells measured off-screen | `typingCellHeightEqualsOneLine`, `draftWrapsLikeMessage` (5 languages × 3 widths × Dynamic Type) |
| `SnapshotTests` | swift-snapshot-testing, iOS 26 | screens × sizes (320, 375, 393, 440 pt, an iPad-hosted size) × en/ru/de × default/XXL/AX5 × Reduce Motion; keyframe midpoints |
| `ViewUpdateTests` | DEBUG body counters | `genreBarNotReevaluatedOnRefresh` |
| `FlowTests` | XCUITest, iOS 26 | the 12 existing flows, ported |
| `GestureTests` | XCUITest, iOS 26 | scroll from every element, swipes, second finger, cancelled back swipe, taps at 0–450 ms after transitions |
| `DoubleTapTests` | XCUITest | the 16 web `spot` scenarios + the 146 control/state sweep at 0.08–0.8 s |
| `MotionTests` | XCUITest + DEBUG motion recorder | per display frame: last message never steps down unless the panel shrinks; no two cells overlap; nothing under the panel; message alpha = 1 during a switch; velocity continuous on retarget; switch stress (84 series); main-thread stall injection |
| `AccessibilityTests` | `performAccessibilityAudit` [28] + labels in 5 languages | |
| `PerfTests` | `XCTCPUMetric`, `XCTMemoryMetric`, scroll-deceleration hitch metric | idle Home / Home under chat / empty Favourites / idle chat; memory over 100 navigation loops |

---

## 9. All 169 bugs, one by one

Counts by primary mechanism: **C 109 · S 40 · T 15 · W 5 = 169.** No row lacks a mechanism; every non-W row also
names its regression test.

| # | Bug | Root cause | Mech. | How the new design makes it impossible | Test that fails if it ever comes back |
|---|---|---|---|---|---|
| 1 | Slider rested between two cards | own tween interrupted; finger-up missed | **C** | The slider is a paging `ScrollView` (`.scrollTargetBehavior(.viewAligned)`): UIKit always decelerates onto a target, also after cancel, second finger, background | GestureTests.sliderAlwaysRestsOnACard (drag half, cancel, background mid-drag) |
| 2 | Slider restarted from card 1 after a tab switch | state lived in the view | **S** | `SliderClock` lives in `HomeModel` (app lifetime); the view only renders it | SessionTests.SliderClockTests.resumesWhereItWas |
| 3 | Wrap last→first visibly jumped; worm crawled back | copy cards + silent jump | **C** | Virtual index space (n × 1 000 cards, start in the middle): there is no wrap and no silent jump at all; dots = pure function of `index mod n` | CoreTests.dotsLayoutAcrossWrap |
| 4 | A plain touch paused the slider | pause tied to touch-down | **S** | The clock pauses only while `scrollPhase != .idle`; a touch that does not move never changes the phase | SliderClockTests.touchWithoutMoveDoesNotPause |
| 5 | "Unwanted Guest" lettering overflowed the card | fit by guessed sizes | **T** | Fit computed by layout (`onGeometryChange` + scale); every story × 5 languages × 3 widths is snapshotted | SnapshotTests.letteringFitsEveryCard |
| 6 | A story page did not open (missing JS constant) | dynamic language | **C** | A missing symbol does not compile in Swift; plus every story × every saved state is opened | ContentTests.everyStoryOpensInEveryState |
| 7 | Seams in the water waves | tiles joined | **C** | One continuous `Path` per wave; no tiling exists | SnapshotTests.waterMidWave |
| 8 | Reset: water vanished instead of draining | state flipped without motion | **C** | Drain is a `KeyframeAnimator` from the old level to 0 triggered by the reset event; there is no code path that sets 0 without it (Reduce Motion: cross-fade) | SnapshotTests.waterDrainMidway |
| 9 | Icons off-centre in round buttons | SVG boxes + button padding | **C** | SF Symbols (custom symbols) are optically centred; buttons use `.buttonStyle` with no implicit padding | SnapshotTests.roundButtons |
| 10 | "Part N starts over" note misplaced/overlapping | absolute positioning | **C** | The note lives in the same `HStack` as ↺ and ♥ (layout, not offsets), wraps to 2 lines | SnapshotTests.resetNoteLongestLanguage |
| 11 | Chat closed by a swipe from anywhere (header too) | window-level custom swipe | **C** | System back gesture of `NavigationStack`; the header is the navigation bar. iOS 26 also pops from the content area — owner decision D3; if the edge-only rule stays, `interactiveContentPopGestureRecognizer.isEnabled = false` (public UIKit API) | GestureTests.swipeOnHeaderDoesNotClose |
| 12 | Back returned to the wrong screen | overlay bookkeeping | **S** | `Router` path: opening the chat replaces `.story` by `.chat`, so Back pops to the origin by definition | FlowTests.openAStoryReadAndComeBack |
| 13 | Part disc glowed / could not be dragged | hand-made control | **C** | The part selector is the shared `OvalPicker` (drag + tap built in, no glow drawn) | SnapshotTests.partPicker |
| 14 | Progress bars under part numbers (unwanted) | extra drawing | **C** | `OvalPicker` has no progress input — it cannot draw one | SnapshotTests.partPicker |
| 15 | Tap counter visible / limit not working | UI showed internal count | **S** | `taps` is in `Settings` only, read by `ChatReader`; no view model exposes it | ChatSessionTests.freeReaderHitsPaywallAtZero; FlowTests.aFreeReaderHitsThePaywall |
| 16 | Table markup in message text | dirty source | **T** | Build-time validator + bundled-content test fail on table pipes, `\!` and `:-:` | ContentTests.storyTextIsClean |
| 17 | A speaker "revealed a real name" (side changed) | free-text speaker | **S** | `Message.side` is an enum decoded from `from == left/right`; an unknown speaker is a decode error | ContentTests.storyShape |
| 18 | Favourites removal: rows jerked up | hand-made removal | **C** | `List` deletion animation (`onDelete`/swipe action) | MotionTests.favouritesRemovalHasNoJump |
| 19 | Unlike by hold / by heart tap failed | two recognisers side by side | **C** | Heart = its own `Button`; hold = `UILongPressGestureRecognizer` representable; tap = the card `Button` | FlowTests.likeUnlikeAndFavourites |
| 20 | "Added" toast unwanted; like not visible | design | **C** | No toast path exists for likes; like = `KeyframeAnimator` swell + heart draw | SnapshotTests.heartKeyframes |
| 21 | Reel peeked from under the tab bar | always-present layer | **S** | The reel is drawn only while bottom overscroll > 0 (`if overscroll > 0`); at rest it does not exist | SnapshotTests.homeAtRestHasNoReel |
| 22 | Reel not pulled far enough vanished instead of sinking | own spring | **C** | The reel sits in the overscroll gap; the system bounce closes the gap | GestureTests.shortReelPullSinks |
| 23 | Chosen reel row: outline only | design | **T** | Style asserted | SnapshotTests.reelChosen |
| 24 | Fear row blinked on focusing search | fade-out/in on focus | **C** | The fear row stays: with `.searchable`, an empty query shows the same list; nothing is removed on focus | SnapshotTests.searchFocusedEmpty |
| 25 | Gap above the pinned search field | CSS sticky | **C** | The field is the system search field in the bar | SnapshotTests.searchTop |
| 26 | Captions must be genre + time only | design | **S** | `MetaLine(genre:minutes:)` has no fear parameter | SnapshotTests.metaLine |
| 27 | Progress differed between screens | several computations | **S** | One `ProgressStore`; every screen observes the same value | CoreTests.progressRulesMatchTheWeb; FlowTests.openAStoryReadAndComeBack |
| 28 | Menu overflowed at 320 pt | fixed layout | **C** | `Form` rows wrap and use Dynamic Type | SnapshotTests.menuSE_allLanguages_XXL |
| 29 | Reset must also clear choices | two separate fields | **S** | `Progress.reset(part:)` is the only reset API and clears `path` with `pos` | CoreTests.chatWalksMatchTheWeb |
| 30 | Saved path from an older story version | unchecked path | **S** | `ChatReader.init` validates the path against the story's nodes; invalid → start | ContentTests.everyStoryOpensInEveryState (state "stale path") |
| 31 | Progress from an older text version | no version | **S** | Progress is stored with the content fingerprint; mismatch → fresh | CoreTests.versionFingerprintMatchesBuildPy; CoreTests.progressRulesMatchTheWeb |
| 32 | Scroll bar in the chat | CSS | **C** | The chat list type sets `showsVerticalScrollIndicator = false` once, in its initialiser | SnapshotTests.chatScrolled |
| 33 | Private-use character in a text | dirty source | **T** | Validator rejects U+E000–U+F8FF | ContentTests.storyTextIsClean |
| 34 | Gamepad badge below the caption's centre | SVG box offset | **C** | SF Symbol inline in `Text` aligns to the font's cap height | SnapshotTests.metaLine |
| 35 | Search: Cancel jumped to the top | focus scrolled the list | **C** | Focus does not scroll the results; the system field's Cancel leaves the list untouched | GestureTests.searchCancelKeepsPlace |
| 36 | Tap that hid the keyboard opened a story | list swapped under the finger | **C** | With an empty query the list does not change on focus/blur, so nothing new appears under the finger; keyboard dismissal is the system's | DoubleTapTests.keyboardDismissTapOpensNothing |
| 37 | First/last fear level off centre | % margins | **C** | `.contentMargins(.horizontal, (w-132)/2)` computed from the row's own width + `.viewAligned` | SnapshotTests.fearRowLevels1and5_threeWidths |
| 38 | Empty Favourites picture off centre / small | frame vs content | **T** | Picture centred on its squares; asserted | SnapshotTests.emptyFavourites |
| 39 | A choice cost two free taps | reply charged | **S** | `ChatReader.begin(free:)`: the auto-reply is `.free` by type | CoreTests.chatWalksMatchTheWeb |
| 40 | Chat froze after a cancelled back swipe | timer cancelled at swipe start | **C** | Interactive pop does not end the view's `.task`; only a completed pop does. Nothing is cancelled by a swipe that is called off | GestureTests.cancelledBackSwipeWhileTypingThenTapReads |
| 41 | Voice kept playing after leaving | no lifetime | **C** | `MediaCenter.stop()` in the session task's `defer` + scene background | ChatSessionTests.leavingStopsMedia |
| 42 | 320 pt: ending title under the buttons | scroll before panel grew | **C** | The panel is the list's bottom inset; the list's visible area always ends at the panel's top | SnapshotTests.endingSE; MotionTests.endingNothingUnderPanel |
| 43 | Reel opened from the touched cover | source = touch-down element | **S** | The zoom source id is the *picked* story's reel row, a value computed at release | CoreTests.reelPickRule |
| 44 | Reel jerks (a–e) | own tweens and springs | **C** | One motion only: the system bounce; reel position is a pure function of the overscroll | MotionTests.reelPullNoJump; PerfTests.reelHitches |
| 45 | Search list did not bounce; field moved with it | one scrolling page | **C** | System search field outside the list; `.scrollBounceBehavior(.always)` on the list | GestureTests.searchListBouncesWithOneResult |
| 46 | 30 quick reel pulls misbehaved | re-entrant own spring | **C** | No own spring; every pull is a new system pan | GestureTests.thirtyQuickReelPulls |
| 47 | Owl eyes left before the page | eyes and page moved separately | **C** | Eyes are an overlay pinned to the content's top: they move with the page by construction; the hold is `.refreshable`'s | GestureTests.refreshWithFingerHeld |
| 48 | Oval drag and refresh at once | one pan, two jobs | **C** | Oval pan (`UIPanGestureRecognizer` representable) begins only if abs(vx) > abs(vy); UIKit gives a touch to one recogniser; no simultaneity is declared | GestureTests.ovalSidewaysOnly / verticalFromGenreRowScrolls |
| 49 | Refresh blinked the genre row | whole page faded | **S** | `@Observable` tracking: `GenreBar` reads only `genre`; a refresh changes `stories` and cannot invalidate it; only grid/slider fade | ViewUpdateTests.genreBarNotReevaluatedOnRefresh (DEBUG body counter) |
| 50 | Small sideways then down: oval jumped back, refresh began | scroll stole the touch | **C** | Once the oval pan has begun, UIKit keeps the touch with it to the end | GestureTests.ovalSidewaysThenDown |
| 51 | Like replayed on the tile after closing the preview | animation keyed to state | **S** | Animation is triggered by a local like *event*; state arriving from elsewhere just sets the value | FlowTests.likeUnlikeAndFavourites; SnapshotTests.tileAfterPreviewLike |
| 52 | Genre label vanished/blinked on refresh (device) | web layer compositing + re-creation | **S** | As #49: never re-evaluated, never re-created (stable identity); owner checks on device | ViewUpdateTests.genreBarNotReevaluatedOnRefresh; device check |
| 53 | Reset hit the wrong part; selection jumped | derived selection | **S** | `reset(part: selected)` takes the selection; selection is view state, not derived from progress | StoryPageModelTests.resetUsesSelectedPartAndKeepsIt |
| 54 | Slider clock ran while dragged | cancel = lift | **S** | Clock pauses while `scrollPhase != .idle` (dragging, decelerating, animating) | SliderClockTests.pausedWhileDraggingAndGliding |
| 55 | Part switch flashed, preview visible | screen recreated | **C** | A part switch is a data change inside one chat screen; the preview is not in the stack under the chat | MotionTests.partSwitchNoBlank |
| 56 | Tap on a part number did not switch | disc held the touch | **C** | `OvalPicker` segments are `Button`s | FlowTests.partsNextPartAndThePartDisc |
| 57 | Quick switches opened not the last one | uncancelled delayed work | **S** | `switchPart(k)` replaces the pending switch task (one `Task?` field), so only the last survives | ChatSessionTests.fiveQuickSwitchesOpenTheLast |
| 58 | A doodle name did not exist | free text | **T** | Doodle names decode into a generated `Doodle` enum; unknown → test/build failure | ContentTests.wallpaperNamesExist |
| 59 | Preview time ≠ card time | two computations | **S** | One `Story.minutes` property | CoreTests.readingTimeMatchesTheWebEverywhere |
| 60 | Reel pulled far up then down still picked | start-relative position | **S** | `pick = overscroll(at release) ≥ line`, one pure function of the release geometry | CoreTests.reelPickRule |
| 61 | Chat jumped on each new message | insert then scroll | **C** | `UICollectionView` + `ChatLayout` with `keepContentOffsetAtBottomOnBatchUpdates`: insertion and offset change are one animated batch update | MotionTests.newMessageNoDownwardStep |
| 62 | Doodles stopped falling on a part switch | logic regression | **T** | `Wall` state machine; fall/arrive asserted | CoreTests.partSwitchMakesOldDoodlesFall (exists as Stage4) |
| 63 | Part switch: messages jumped and overlapped the description | snapshot copies | **C** | Both parts are cells of the same list, animated by layout attributes in the list's own coordinates | MotionTests.partSwitchNoOverlap |
| 64 | Panel height jumped; "Tap to continue" over the flying answer | panel and list separate | **C** | Panel height and list inset change in one `UIView.animate(Motion.panel)`; no flying copy exists | MotionTests.panelEdgeFollowsList |
| 65 | Fast taps left "typing…" half hidden | tap stopped the glide | **C** | The glide is the batch update's animation; taps never interrupt UIKit animations, only a pan does | MotionTests.tripleTapsTypingFullyVisible |
| 66 | Ending: messages slid under title and buttons | parallel animations | **C** | End title inserted as a cell after the panel animation's completion (sequenced by completion handlers) | MotionTests.endingNothingUnderPanel |
| 67 | Before choices / after choice the chat jumped down | measured inset | **C** | The list never computes inset from measurements; ChatLayout keeps the bottom on batch updates | MotionTests.choiceNoDownwardStep |
| 68 | Tap other part and back: eternal "typing…" | typing stopped at intent | **S** | A part switch is an intent until committed; the reading task is cancelled only on commit | ChatSessionTests.switchAndBackKeepsTyping |
| 69 | Reduce Motion: jump after a choice | different code path | **C** | Same layout path, `Motion.animation` returns nil; no alternative branch | MotionTests.choiceNoDownwardStep_reduceMotion |
| 70 | Flying answer 8 px off | copy in another coordinate space | **C** | No flying copy exists: the draft cell becomes the sent cell | SnapshotTests.draftBecomesMessage |
| 71 | After refresh the slider flashed card 1 | slider recreated | **S** | Slider position is model state; refresh replaces stories only | HomeModelTests.refreshKeepsSliderIndex |
| 72 | Tap on a leaving chat read a message | still interactive | **C** | UIKit disables interaction during pop; the session's task is cancelled at disappear; `ChatReader.leaving` | GestureTests.tapDuringBackAnimationSavesNothing |
| 73 | Pick while the panel opened: panel snapped | measured final height | **C** | UIKit animations start from the presentation value (spring retarget) | MotionTests.pickAt0_120_300ms |
| 74 | Pick while scrolled up: chat slid under the answer | no sequencing | **S** | Session: if not at bottom → `scrollToBottom` and await its completion, then send | ChatSessionTests.pickWhileScrolledUpScrollsFirst; MotionTests |
| 75 | ✕ opened the card under it | close on touch-down | **C** | Buttons act on touch-up; the same touch cannot reach what is revealed; transitions block input | DoubleTapTests.closeThenTapSamePlace |
| 76 | Old messages over the panel during a switch | copy taller than area | **C** | Cells are clipped by the list's frame, which ends at the panel | MotionTests.partSwitchNothingOverPanel |
| 77 | The Doctor: speaker labels shifted in the source | source data | **T** | New content check: no part has a run of more than 15 consecutive messages from one side (measured today: The Doctor has 29 in every language, every other story at most 9 — so it fails exactly on the broken file) — owner fixes the text | ContentTests.noLongOneSidedRuns |
| 78 | "typing…" squeezed to a strip | flex shrink | **C** | Self-sizing cells take their intrinsic size; a collection layout never compresses a cell | LayoutTests.typingCellHeightEqualsOneLine |
| 79 | Flying answer lost its last word | copy narrower by border | **C** | No copy; border drawn inside the bubble (`strokeBorder` / layer border inside) | LayoutTests.draftWrapsLikeMessage |
| 80 | "typing…" height wrong on iPhone | measured by script | **C** | Typing cell contains a hidden one-line label in the message font | LayoutTests.typingCellHeightEqualsOneLine |
| 81 | Answer re-wrapped when sent | different widths | **C** | Draft and message are the same cell class with the same max width | LayoutTests.draftWrapsLikeMessage (5 languages × 3 widths) |
| 82 | Quick re-switch replayed messages | restart from snapshot | **C** | UIKit spring animations are retargeted from the current presentation value | MotionTests.switchStress84 |
| 83 | A finished story opened from the start | rule | **T** | `Reading.nextPart` / ChatReader rule | CoreTests.chatWalksMatchTheWeb |
| 84 | Removing the last row jerked rows above | scroll cut | **C** | `List` animates deletion and content size | MotionTests.favouritesRemovalHasNoJump |
| 85 | 1→2→1: messages froze for a frame | restart on next frame | **C** | Retarget happens in the same transaction; render server keeps time | MotionTests.switchStress84 |
| 86 | Quick taps on part numbers lost | selector recreated | **C** | The header (with its picker) is one view for the chat screen's life | FlowTests.partsNextPartAndThePartDisc |
| 87 | Quick switches twitched | velocity sign flip | **C** | Springs keep velocity on retarget (WWDC23) | MotionTests.switchVelocityContinuous |
| 88 | Fling to the top stopped dead | own bounce | **C** | Native bounce of the collection view; the description is the first cell | GestureTests.chatFlingBounces |
| 89 | Chat sometimes would not scroll | own bounce caught the touch | **C** | No own bounce | GestureTests.scrollRightAfterNewMessage |
| 90 | Messages faded/came from nowhere on switch | opacity animated | **C** | Switch animations change only `transform.tx`; cell alpha is never animated (lint: no alpha in switch code) | MotionTests.switchAlphaAlwaysOne |
| 91 | Odd spring; description stood still | own spring | **C** | Native bounce, description is a cell | GestureTests.chatFlingBounces |
| 92 | Chosen answer stood too high | freed room math | **C** | ChatLayout keeps the bottom; panel inset animates with the batch | MotionTests.choiceLandsAtBottom |
| 93 | "What do you say?" vanished; jerk | panel measured late | **C** | Panel content and height change in one animation | MotionTests.panelEdgeFollowsList |
| 94 | Slider white line stayed behind the pill | separate layers | **C** | The time line is a subview of the pill view | SnapshotTests.dotsMidDrag |
| 95 | Strong fling stopped at the description | own bounce | **C** | Native | GestureTests.chatFlingBounces |
| 96 | Leaving message vanished after a long frame | main-thread clock | **C** | Core Animation runs on the render server's clock; a long main-thread frame cannot advance a spring by "missed" time | MotionTests.switchUnderMainThreadStall |
| 97 | New bubble overlapped the one above | scale ≠ room | **C** | Inserted cell gets its final frame; only its transform starts at 0 from its corner (initial layout attributes); neighbours move in the same animation | MotionTests.insertNoOverlap |
| 98 | Reel: page rose in jumps | our pull + system bounce | **C** | There is only the system's motion | MotionTests.reelPullNoJump |
| 99 | Preview heart drawn differently | two implementations | **C** | One `HeartBadge` component | SnapshotTests.heartKeyframes |
| 100 | After refresh content rode up | rise transition | **C** | Refresh uses `.transition(.opacity)` only | MotionTests.refreshNoMovement |
| 101 | 1→2→1: messages vanished/reappeared | waiting rows had velocity | **S** | Switch state machine `enum SwitchPhase { idle, leaving(parts), arriving }`; arrivals start in the leave animation's completion | ChatSessionTests.switchPhases; MotionTests.switchStress84 |
| 102 | Read messages shown then slid in again | screen-space start offsets | **C** | Start offsets come from layout attributes in the list's coordinate space | MotionTests.openingNoPrematureRows |
| 103 | Home stopped pulling both ways | own "already handled" rule | **C** | No own pan on Home | GestureTests.refreshAndReel |
| 104 | No native bounce on Home | bounce disabled | **C** | Native bounce | GestureTests.homeFlingBounces |
| 105 | A touch during the bounce cut it | style changed on touch | **C** | Nothing changes on touch-down | GestureTests.touchDuringBounce |
| 106 | Search: tap on a match needed two taps | guard too wide | **C** | No guard; the system delivers the tap to the row | GestureTests.tapResultWithKeyboardUp |
| 107 | 320 pt: chat name truncated early | fixed paddings | **C** | Navigation title with layout priorities; snapshots in 5 languages | SnapshotTests.chatHeaderSE_allLanguages |
| 108 | Touch handlers piled up | global listeners | **C** | No global handlers exist (lint forbids swizzling and window recognisers) | PerfTests.memoryStableOver100Loops |
| 109 | Tap right after swipe-dismissing the preview was lost | overlay still "open" | **C** | Router state changes at dismissal; NavigationStack owns the transition | GestureTests.tapAfterSwipeDismiss_0_80_200_400ms |
| 110 | Tap right after leaving the chat was lost | token bookkeeping | **S** | Router has no "leaving" state; a new push is a new route | GestureTests.tapAfterBack_0_100_250_450ms |
| 111 | Rotation/resize left chat at old size | window-sized layout | **C** | All sizes from layout (no `UIScreen.main`, lint); iOS 27 resizable scenes covered | SnapshotTests.allScreensFiveSizes |
| 112 | Double "Read again" read the first message | second tap landed on new chat | **C** | `.armed(after: 0.5)` on the new part's tap target; transitions block input | DoubleTapTests.doubleReadAgain |
| 113 | Broken saved data stopped the app | strict parsing | **S** | Lenient decoding: wrong kind = default | CoreTests.brokenSavesAreIgnored |
| 114 | Home stayed pulled down after refresh | missed finger-up | **C** | `.refreshable` owns hold and release | GestureTests.refreshWithFingerHeld |
| 115 | Last dot lit for a frame across the wrap | wrap state | **S** | Dots are a pure function of the fractional virtual index; no wrap moment exists | CoreTests.dotsLayoutAcrossWrap |
| 116 | Double-tap zoom swallowed taps | browser viewport zoom | **W** | Native views have no page zoom and no 300 ms tap delay | — |
| 117 | Recording timer left running | timer outlived the chat | **C** | The recording seconds are a `TimelineView(.periodic)` inside the typing cell; it exists only while the cell exists | ChatSessionTests.reopenDuringRecordingLeavesNoTimer |
| 118 | Second finger left screens shifted | gesture restarted | **C** | System gestures; our two custom recognisers have `maximumNumberOfTouches = 1` and reset on `.cancelled` | GestureTests.secondFingerDuringEveryDrag |
| 119 | Long press selected text / "Save photo" menu | browser defaults | **W** | SwiftUI `Text` and `UILabel` are not selectable and images have no context menu unless added | — |
| 120 | Whole page bounced; grey tap flash | browser body scroll and tap highlight | **W** | The root of a native app is not a scroll view; no tap highlight exists | — |
| 121 | Part switches counted as reads | count on every open | **S** | `TopWeek.countRead` is called only by `Router.openStory` | CoreTests.topWeekCountsOpeningsOnly |
| 122 | Progress line refilled on every return | animation on appear | **S** | `.animation(_, value: fraction)` animates only value changes; "seen" values stored | SnapshotTests.progressLineNoReplay; UI |
| 123 | Scrolling under the flying answer | flight | **C** | No flight exists in the drafts design | MotionTests.scrollDuringPickNoOverlap |
| 124 | Double "back to a choice" picked an answer | drafts under finger | **C** | Drafts are `.armed(after: 0.6)` | DoubleTapTests.doubleBackToChoice |
| 125 | Chat scrolled sideways during a switch | CSS overflow | **C** | Vertical-only collection view (`alwaysBounceHorizontal = false`, content width = bounds) | GestureTests.chatNoHorizontalScroll |
| 126 | Home worked every frame under a chat | display link | **C** | No display link in the app (lint); idle CPU measured | PerfTests.homeIdleCPU; PerfTests.homeUnderChatCPU |
| 127 | Late web fonts moved the layout | network fonts | **W** | Fonts are bundled and registered via `UIAppFonts` before the first frame | — |
| 128 | Tap during auto turn opened the next card | card under finger at lift | **C** | Each card is its own `Button`; the touched button is fixed at touch-down | GestureTests.tapDuringAutoTurn |
| 129 | Answer water filled in 1.75 s | timing from flight | **C** | The drafts design has no water fill | ChatSessionTests.pickTimeline (sent at 0.24 s, reply typing at +1 s) |
| 130 | Double "Next part"/triple "Read again" read a message | short guards | **C** | New part's tap target `.armed(after: 0.5)`; transitions block input | DoubleTapTests.doubleNextPart |
| 131 | Reset added duplicate swipe handlers | re-render added listeners | **C** | Gestures are declared in the view tree once | GestureTests.resetThenSwipeOpensChatOnce |
| 132 | Part number then Back: chat opened later | delayed work survived | **C** | Pending switch is a child task of the session; cancelled at disappear | ChatSessionTests.pendingSwitchCancelledOnLeave |
| 133 | Cancelled swipe then Back: preview flashed | timer revived preview | **C** | The preview is not under the chat | FlowTests |
| 134 | Refresh then other tab: handlers on Favourites | refresh continued on hidden page | **C** | `.refreshable`'s task is cancelled with Home; it touches only Home's model | SessionTests.HomeModelTests.refreshAfterTabSwitchChangesNothingElse |
| 135 | Reel then tab switch: preview over another tab | global preview | **S** | The reel pushes onto Home's own stack only | HomeModelTests.reelPickPushesOnHomeStack |
| 136 | Double "Remove" re-added the story | toggle | **C** | Swipe-action deletion removes the row from data; idempotent `remove(id)` | CoreTests.removeIsIdempotent; FlowTests |
| 137 | Preview did not resize (water running) | size frozen | **C** | Layout-driven; no stored sizes | SnapshotTests.allScreensFiveSizes |
| 138 | Search row progress stale after reset | no refresh | **S** | Rows observe `ProgressStore` | FlowTests.resetUpdatesEveryRow |
| 139 | Picking a part during drain reverted | redraw reset selection | **S** | Selection is independent view state | StoryPageModelTests.selectDuringDrain |
| 140 | Like/unlike: circle colour snapped | animation chain broken | **C** | Colour animated by value with retargeting | SnapshotTests.heartKeyframes |
| 141 | Double "Next part" skipped a part | same button reappeared | **C** | `.armed` + idempotent `open(part:)` intent | DoubleTapTests.doubleNextPartFinishedStory |
| 142 | End buttons before the answer landed | no sequencing | **S** | Session awaits the pick animation's completion before revealing end | ChatSessionTests.endAfterAnswerLands |
| 143 | Refresh started the slider twice | re-init | **S** | One `SliderClock` instance; refresh does not touch it | SliderClockTests.refreshDoesNotRestart |
| 144 | Service listeners accumulated on elements | DOM `addEventListener` per render | **W** | SwiftUI/UIKit gestures are owned by their views and released with them | PerfTests.memoryStableOver100Loops |
| 145 | Progress inaccuracies (99.6→100, read again, nextPart, refund, broken data) | rules | **T** | Core rules | CoreTests.progressRulesMatchTheWeb; chatWalksMatchTheWeb; brokenSavesAreIgnored |
| 146 | Timings drifted from owner decisions | numbers in many places | **T** | All timings in `Motion`, each with its IDEAS reference | CoreTests.motionSpecMatchesIdeas |
| 147 | Returning during chat exit: dots misplaced | partial first frame | **S** | Dots are computed from model on every render | CoreTests.dotsLayoutAcrossWrap; SnapshotTests |
| 148 | Double ✕/back pressed what was under it | touch-down close | **C** | Touch-up buttons; transitions block input; system modality for VoiceOver | DoubleTapTests.doubleCloseAndBack |
| 149 | Interruptions left wrong state (background, call, home bar) | no cancel paths | **C** | `scenePhase` pauses clocks; system gestures cancel cleanly; `AVAudioSession` interruption/route-change notifications | SliderClockTests.backgroundTimeNotCounted; MediaCenterTests.interruptionResetsLook; GestureTests.cancelledTouches |
| 150 | Side effects of #130–149 fixes | patch interactions | **C** | The patched mechanisms (redraw, global guards, timers) do not exist | DoubleTapTests; GestureTests |
| 151 | Video ending: chat jumped 43/63 px | title added same frame | **C** | End title inserted in the completion of the video cell's insertion animation | MotionTests.videoEndingNoJump (Two Knocks stay→hide) |
| 152 | Choices shown with 0 taps; disc stuck after swipe | foot ignored taps | **S** | `ChatReader.foot` returns `.paywall` at a choice with 0 taps; picker bound to session `ep` | CoreTests.chatWalksMatchTheWeb; ChatSessionTests.cancelledSwipeRestoresPicker |
| 153 | Narrow screens / long languages overflowed | fixed widths | **T** | Wrapping layout + matrix | SnapshotTests.allScreensSE_5languages_XXL |
| 154 | Six gesture details (spring catch, pause, arc, cancel…) | own gestures | **C** | System gestures implement these rules | GestureTests.* |
| 155 | Six follow-ups of #151–154 | own gestures | **C** | As #154 | GestureTests.* |
| 156 | Launch clock, top-week ties, 3-letter typo search | rules | **T** | Rules in Core; clock starts at `.active` | CoreTests.topOfTheWeekIsTheSameInEveryLanguage; searchFindsWhatTheWebFinds; SliderClockTests.startsWhenActive |
| 157 | New message during a glide: one-frame stall | restart timing | **C** | UIKit animations on the same property are additive/retargeted | MotionTests.messageDuringGlideNoStall |
| 158 | Spaces-only query stuck; like inverted after outside change | raw text; toggle | **S** | `query` trimmed in the model; `setFavourite(id, on:)` takes the wanted state | CoreTests.queryTrim; CoreTests.setFavouriteIsAbsolute |
| 159 | Performance on iPhone (decode, layers) | web rendering | **C** | Asset-catalog/downsampled covers, no per-frame filters, no display links | PerfTests.homeScrollHitches; PerfTests.homeIdleCPU |
| 160 | Disc held through part open; quick unlike-like; two removals | recreated selector; timing | **C** | Stable picker; immediate model writes; List deletions | FlowTests; GestureTests |
| 161 | Fast taps at end erased progress; Reduce Motion gaps | short guards; branches | **C** | `.armed` end buttons; one `Motion` path; pacing never tied to motion | DoubleTapTests.fastTapsThroughEnding; ChatSessionTests.reduceMotionKeepsPacing |
| 162 | Builder missed broken stories | no validation | **T** | Validator + bundled-content tests | ContentTests.storyShape; longestPathEqualsMessages |
| 163 | Counter 0:09 for a 9.5 s clip; video pushed chat | floor; first frame | **S** | Label = `rounded(currentTime)` capped by `dur`; insertion via layout | MediaCenterTests.labelReachesDuration; MotionTests.videoInsertNoJump |
| 164 | Return after answering: no auto-reply; ↶ issues | owesReply lost | **S** | `ChatReader.owesReply` drives a free reply in the session; ↶ is not ported (IDEAS) | ChatSessionTests.returnAfterAnswerGetsFreeReply |
| 165 | Builder longest path wrong; ↶ loop | algorithm | **T** | Content test per branch; ↶ absent | ContentTests.longestPathEqualsMessages |
| 166 | Double tap card near bottom hit "Read"; Remove not closing; paused voice label | overlay + guards | **C** | Push transition blocks input; List closes swipe actions on any touch; label from `currentTime` | DoubleTapTests.doubleTapCardNearBottom; MediaCenterTests.pausedLabelShowsElapsed |
| 167 | Guards ate normal taps; paywall/menu/cancel double taps | global time guards | **C** | No global guard; per-control `.armed` on controls that appear | DoubleTapTests.sweep (all controls, 0.08–0.8 s) |
| 168 | Second tap of a double tap hit a newly appeared control | browser hit-testing | **C** | Transitions block input; controls that appear under a finger are `.armed`; actions idempotent | DoubleTapTests.sweep (146 control/state pairs from the web test) |
| 169 | iOS 26: Home did not scroll from tiles/slider/genres | zero-distance DragGesture in ScrollView | **C** | Gesture policy + SwiftLint rules forbid `DragGesture(minimumDistance: 0)`, `simultaneousGesture`, raw `touches*` overrides in features; CI on iOS 26 | GestureTests.scrollFromEveryElement (iOS 26 and newest 26.x) |

---

## 10. All 47 owner decisions (IDEAS.md → `BUGS_PASS.md` numbering I1–I47)

Counts: C 28 · T 16 · S 2 · W 1 (I30 is a content question, not a behaviour). Decisions that change are marked with the
owner-decision number of §12.

| # | Owner decision (IDEAS.md) | Where it lives in the new design | Mech. | Test / note |
|---|---|---|---|---|
| I1 | Answers are drafts in the chat (on trial) | Draft cell = future message cell; pick = one batch update | **C** | LayoutTests.draftWrapsLikeMessage; FlowTests.answersAtAChoice… |
| I2 | ≤ 3 messages = no progress | `Reading.prog` (Core, unchanged) | **T** | CoreTests.thePartOpenInTheChatKeepsAShortCount |
| I3 | Tile like: badge 39/21 pt, pop → pen → ink 0.39 s | `HeartBadge` + `KeyframeAnimator` (iOS 26: custom symbol `.drawOn`); numbers in `Motion`/`Theme` | **T** | SnapshotTests.heartKeyframes; CoreTests.motionSpecMatchesIdeas |
| I4 | Unlike: crack, 0.32 s / 0.2 s | Same component, crack keyframes | **T** | SnapshotTests.heartKeyframes |
| I5 | Empty Favourites picture and spacing | Custom empty view, `KeyframeAnimator` plays once | **T** | SnapshotTests.emptyFavourites; PerfTests.emptyFavouritesIdleCPU |
| I6 | Reel turns only with the finger, stretch, sink | Reel row offset = f(overscroll); native band = D1 | **C** | GestureTests.refreshAndReel (owner approves D1) |
| I7 | Search: only the list moves | System search field | **C** | GestureTests.searchListBouncesWithOneResult |
| I8 | Story page buttons, swipes, frame, ring, note | Toolbar buttons, zoom push (swipe down/edge), `OvalPicker`, ring `trim` + Core Haptics | **C** | FlowTests; SnapshotTests (D2, D4) |
| I9 | Doodles fly in, fall on part switch | `Wall` state machine; views animated by springs and a gravity `CustomAnimation` | **T** | CoreTests.partSwitchMakesOldDoodlesFall; MotionTests.doodlesLandOnTheirPlaces |
| I10 | Interactive: closed endings' doodles fall and return | `Wall.setVisible(groups)` | **T** | CoreTests (existing Stage4 wallpaper test) |
| I11 | Reading time = waits + 3 s per message | Core `Reading` | **T** | CoreTests.readingTimeMatchesTheWebEverywhere |
| I12 | Answer line breaks = sent message | Same cell, same width | **C** | LayoutTests.draftWrapsLikeMessage |
| I13 | (superseded by I1) | — | **C** | — |
| I14 | New messages like WhatsApp: glide 0.26 s | ChatLayout batch update in `UIView.animate(Motion.bubble)` | **C** | MotionTests.newMessageNoDownwardStep |
| I15 | Genre oval: 1:1 drag, blend width, tap glide, one touch one job | `OvalPicker` (Buttons + horizontal-only pan representable) | **C** | GestureTests.ovalSidewaysOnly; CoreTests.ovalShapeBlend |
| I16 | Slider cards not liked by a hold | Slider cards have no long-press recogniser | **C** | SnapshotTests / code review |
| I17 | Refresh: eyes stop where they blink; wait for the finger; clock stands | Eyes pinned to content top, `.refreshable` hold, clock pauses during refresh | **C** | GestureTests.refreshWithFingerHeld; SliderClockTests.pausedDuringRefresh |
| I18 | Haptics: light tap on like/unlike; ramp on reset hold | `.sensoryFeedback(.impact(weight: .light))`; Core Haptics continuous curve 0.2→1.0 / 0.3 s | **T** | MediaCenterTests-like HapticsTests.rampPatternShape (pattern parameters) |
| I19 | Slider clock stands while held / gliding | Pauses on `scrollPhase != .idle` | **S** | SliderClockTests.pausedWhileDraggingAndGliding |
| I20 | Slider worm dots | Pure function of fractional index | **T** | CoreTests.dotsLayoutAcrossWrap; SnapshotTests.dotsMidDrag |
| I21 | Slider both ways round and round | Virtual index space | **C** | GestureTests.sliderBothWays |
| I22 | (superseded by I45) | — | **C** | — |
| I23 | After reset: still water; note look | Water keyframes not replayed; note in HStack | **T** | SnapshotTests.resetNoteLongestLanguage |
| I24 | Waves 3.3 s; a re-picked calm part replays | `KeyframeAnimator` trigger = (part, wakeCount) | **T** | StoryPageModelTests.repickWakesCalmPart |
| I25 | White time line inside the pill | Subview of the pill | **C** | SnapshotTests.dotsMidDrag |
| I26 | Favourites bounce; removal at end glides | `List` | **C** | MotionTests.favouritesRemovalHasNoJump |
| I27 | A finished story opens at its end | Core | **T** | CoreTests.chatWalksMatchTheWeb |
| I28 | Story page swipes: right/down close, left/up open | Zoom push: edge/down dismiss native; left/up = "Read" (D4) | **C** | GestureTests.storyPageSwipes |
| I29 | 5 languages; menu fade 0.3+0.3; tick; swipe back | String catalog + in-app lookup; Settings-style push (D5) | **T** | SnapshotTests.menu_allLanguages; FlowTests.languageAndSubscription |
| I30 | Open question: voices English in all languages | Content (owner, paid generation needs yes) | **W** | — |
| I31 | "typing…" stretches into the message | Same cell reconfigured inside an animated batch update; bubble background is a UIKit layer that animates with the cell frame | **C** | MotionTests.typingMorphNoSecondBubble |
| I32 | Typing bubble = one-line message by construction | Hidden one-line label | **C** | LayoutTests.typingCellHeightEqualsOneLine |
| I33 | New bubble grows from its pointed corner | Initial layout attributes: transform scale 0 about the corner | **C** | SnapshotTests.insertMidway; MotionTests.insertNoOverlap |
| I34 | Panel height never jumps (0.4 s) | Panel + list inset in one `UIView.animate(Motion.panel)` | **C** | MotionTests.panelEdgeFollowsList |
| I35 | "Start over" text exactly where "Tap to continue" was | Same text style and baseline in both panel states | **T** | SnapshotTests.panelTapVsEndAligned (pixel diff of the word's frame) |
| I36 | Bottom of conversation at the panel's edge | List bottom inset = panel height | **C** | MotionTests.panelEdgeFollowsList |
| I37 | Chat spring = Search's (native) | Native bounce | **C** | GestureTests.chatFlingBounces |
| I38 | End buttons move nothing (0.125 s fades) | Fade-only transition, `.armed` | **C** | SnapshotTests; DoubleTapTests |
| I39 | End title rides up like a message | End title is a cell | **C** | MotionTests.endingNothingUnderPanel |
| I40 | A tap never stops the glide | UIKit animations ignore taps | **C** | MotionTests.tripleTapsTypingFullyVisible |
| I41 | Part selector 40 pt, step 44 pt | `OvalPicker` metrics in `Theme` | **T** | SnapshotTests.partPicker |
| I42 | Part switch: one spring per message, keep speed | UIKit springs per cell (`UIView.animate(Motion.slideIn/out)`), retargeted | **C** | MotionTests.switchVelocityContinuous; switchStress84 |
| I43 | New bubble grows from zero | Initial transform scale 0 | **C** | MotionTests.insertNoOverlap |
| I44 | Home: native bounce + our pulls, never both | Only native motion exists | **C** | GestureTests.refreshAndReel |
| I45 | Story page like = tile like | One `HeartBadge` | **C** | SnapshotTests.heartKeyframes |
| I46 | VoiceOver labels in 5 languages | String catalog holds a11y strings | **T** | AccessibilityTests.everyControlLabelledInEveryLanguage (XCUITest audit `performAccessibilityAudit`) |
| I47 | Progress line fills only when new | Value-keyed animation + seen store | **S** | SnapshotTests.progressLineNoReplay |

---

## 11. Critical review passes

### Pass 1 — attack the design with the bug list
Method: for each of the 169 rows, try to make the bug happen in the proposed design. Changes made:
1. **Chat list → UIKit + ChatLayout.** #61/#67/#74/#151 could recur with `.sizeChanges` anchoring (it pulls a reader
   down; evidence §5). With ChatLayout the "keep bottom" flag is switched off while the reader is scrolled up.
2. **Segmented control rejected on Home.** Attacking #169 with "drag up starting on the genre row": a `UIControl` keeps
   its touch in a scroll view by default [30]. → `OvalPicker` everywhere.
3. **Owl hold via `.refreshable`.** Attacking #114 ("page stays pulled down"): no evidence that animating
   `contentMargins` holds a bouncing scroll view [23]; `.refreshable` owns the hold and the release.
4. **Slider without silent jumps.** Attacking #3/#115 with fast swipes during repositioning: forum reports of paged
   views hanging on a programmatic target while the user drags [24a] → virtual index space, programmatic moves only
   when idle.
5. **#77 had no mechanism** (content error) → new `ContentTests.noLongOneSidedRuns`, which fails on today's The Doctor.
6. **#49/#52 needed proof, not hope** → DEBUG body-evaluation counter test.
7. **"Chat jumps" bugs need frame-level proof** → the motion recorder (§8), the native counterpart of the web's
   frame recorders.
8. **Dangerous APIs could creep back** → SwiftLint rules make them unbuildable.

### Pass 2 — edge cases
1. **Rotation / resizing.** Portrait on iPhone, but iOS 27 resizes iPhone apps on iPad and in iPhone Mirroring [27];
   the current code reads `UIScreen.main.bounds` in three places. → All sizes from layout, `no_uiscreen_main` lint,
   snapshots at five sizes including 320 pt (no iOS 26 iPhone is narrower than 375 pt, but a resized scene can be).
2. **Dynamic Type.** The web spec's fixed sizes become the default "Large" category; chat cells use `UIFontMetrics` and
   self-size; ChatLayout supports dynamic sizes; snapshots at XXL and AX5. The slider lettering is art (fixed), with a
   plain accessibility label.
3. **VoiceOver.** No rotated list (reading order natural); system modality for pushes; arriving messages announced;
   drafts are buttons with a hint; `performAccessibilityAudit` in CI [28]; custom actions (Favourite, Remove) kept.
4. **Low Power Mode.** The system may cap frame rates (e.g. ProMotion at 60 Hz) [8b]; system animations adapt, and with
   no display links nothing in the app assumes a frame rate. Covers decoding happens once, off the main thread.
5. **Backgrounding mid-animation.** Model state is committed before any animation starts (animations are only visual),
   so an interrupted animation lands on the final state. Clocks pause while the scene is not active — the slider (#149)
   and, new in this pass, the chat's typing/recording pacing (`ChatSessionTests.backgroundPausesPacing`); media stops.
6. **Fast repeated taps.** Each tap target is either a system control during a transition (blocked), `.armed`, or an
   idempotent action; `ChatReader` ignores reads while the other side is typing; the sweep test covers all controls.
7. **Interrupted gestures.** System gestures cancel cleanly; our two representables reset on `.cancelled`
   (`GestureHandlerTests.cancelledPanResets` with a fake recogniser state, because XCUITest cannot inject a system
   cancel mid-drag).
8. **Memory warnings.** No unbounded caches (today `CoverCache` keeps every full-size cover forever): asset catalog /
   `NSCache`; video players live only in visible cells; `PerfTests.memoryStableOver100Loops`.
9. **iPhone SE → Pro Max.** Snapshot matrix; the slider card width comes from `containerRelativeFrame`, the tile grid
   from the container width.
10. **iOS 26.x point releases.** CI on 26.0 and newest 26.x, weekly run on the newest beta; forum-reported regressions
    for each API used are listed next to it in §6 with a guard test.

### Pass 3 — attack dependencies, integration and process
1. **ChatLayout as a dependency.** Pinned exact version; wrapped behind `ChatListView`; fallback layout specified (§5).
2. **SwiftUI inside cells.** `UIHostingConfiguration` cells do not animate size changes [16e] → chat cells are UIKit;
   SwiftUI stays for header, panel and every other screen. (Changed in this pass.)
3. **One motion language across UIKit and SwiftUI** via `UIView.animate(SwiftUI.Animation)` [12b] (changed in this
   pass; v1 had none for UIKit).
4. **iOS 26 content back swipe vs. our horizontal drags.** Only the story page has one (part frame); its recogniser is
   required to fail the content-pop recogniser; test added. The chat has no horizontal content gestures (the part
   picker is in the navigation bar).
5. **Known API bugs → guard tests:** `.refreshable` tap misalignment [23b]; zoom dismissal regressions [6b]; List swipe
   glitches on iOS 26 [21a]; search state per tab [21b]; `ScrollPosition` object [24c]; paging misalignment [24b][24d].
6. **Snapshot flakiness.** Rendered in the iOS simulator host (not a macOS window, a known CI mismatch [19c]), references
   recorded on the CI image, fixed simulator model and runtime.
7. **Swift 6 strictness with AVFoundation.** Callbacks wrapped to the main actor; `MediaCenter` is `@MainActor`.
8. **Process.** Each screen ships only with its rows of §9 turned into passing tests; `BUGS_PASS.md` gets a new column
   "mechanism" and is re-walked at the end.

---

## 12. Owner decisions needed (deviations that make the app native)

| # | Today's rule | Native proposal | Why |
|---|---|---|---|
| D1 | Owl/reel follow the finger with the web's band; refresh line 64 pt | iOS's own band and refresh threshold; eyes and reel drawn in the gap | no custom pan on Home |
| D2 | ✕ closes on touch-down | closes on lift | the same touch cannot hit what is revealed (#75, #148) |
| D3 | Chat back only from the very left edge (#11) | iOS 26 standard: edge and content-area back swipe (can be limited to the edge with a public flag) | system navigation |
| D4 | Swipe up on the story page: chat comes from below | chat always comes from the right | one navigation stack |
| D5 | Languages fade in place; swipe right back | Settings-style pushed list | system navigation, Dynamic Type |
| D6 | Genre oval look | kept exactly (`OvalPicker`); segmented control no longer proposed | §6.5 |
| D7 | Our stretched red "Remove" | system swipe action | §6.15 |
| D8 | Search field on top of the fear row | system search field (tab bar on iOS 26) | `.searchable` |
| D9 | Hold on a tile = instant like | keep (recommended) or a context menu | optional |
| D10 | Global double-tap rule (SPOT) | transitions + `.armed` + idempotent actions | same behaviour in all recorded scenarios |

---

## 13. Migration plan

Keep Core (1 405 lines) and its tests; rewrite the UI (6 564 lines → ≈ 3 500 including the UIKit chat) screen by
screen in a new shell; delete the old UI at the end.

| Step | Work | Proof on CI | Days |
|---|---|---|---|
| 0 | Spikes with simulator videos for the owner: (a) ChatLayout list — insert/grow, typing morph, panel inset, part switch, 300 rows, Dynamic Type; (b) `.refreshable` + owl overlay + hidden spinner, bottom reel; (c) zoom push + interactive dismiss on iOS 26.0 and newest; (d) `OvalPicker` in a scroll view (vertical drags scroll) | recordings + first `MotionTests` | 3 |
| 1 | Packages, Swift 6, iOS 26, SwiftLint rules, `Motion`, theme, stores, `Router`, shell, DebugLaunch, snapshot harness, motion recorder | unit + lint + first snapshots | 3 |
| 2 | Menu, Search, Favourites | snapshots, Flow/Gesture/DoubleTap tests for them | 2–3 |
| 3 | Home: slider, `OvalPicker`, tiles, refresh, reel, grid | Gesture + Perf (idle CPU) tests | 3–4 |
| 4 | Story page | Flow, Snapshot, Gesture (part drag vs back swipe) | 2 |
| 5 | Chat: session + clock, ChatLayout list, cells, panel, drafts, endings, part switch, wallpaper, media | session tests replaying the 18 web walks; Motion tests; Flow tests | 5–6 |
| 6 | Accessibility audit, Dynamic Type, Reduce Motion, all 169 + 47 rows re-walked, old UI deleted | full matrix green | 2–3 |
| | **Total** | | **18–24** |

---

## 14. Remaining risks (after three passes)

1. **ChatLayout spike** might show an edge case (e.g. reconfigure + insert in one batch); fallback layout is specified.
2. **Hiding the refresh spinner** through the appearance proxy is public API but not documented for SwiftUI's
   `.refreshable`; fallback: the eyes' backdrop covers it.
3. **Zoom transition** regressions may persist in 26.x; fallback: plain push (one flag).
4. **Owner acceptance** of D1–D10; until approved, the spike videos show both behaviours where possible.
5. **Device-only checks** remain for feel (bands, haptics, sound) and #52; the tests prove structure, not taste.
6. **iOS 27** changes (resizable scenes, `@State` laziness, search-tab behaviour [21c]) — the weekly beta run is the guard.

---

## 15. Sources

1. Apple Developer Forums — "SwiftUI Gestures prevent scrolling with iOS 18": https://developer.apple.com/forums/thread/760035
2. Apple Developer Forums — "iOS 26 Beta breaks scroll/gesture in SwiftUI chat (worked in iOS 18)": https://developer.apple.com/forums/thread/794212
3. Apple Developer Forums — "simultaneousGesture no longer works when inside a scrollView on Xcode 26": https://developer.apple.com/forums/thread/802903
   3b. Apple Developer Forums — "touchesEnded: not triggered on newer iOS when view is inside UIScrollView (was working on iOS 18)": https://developer.apple.com/forums/thread/817555
4. Apple — Scroll views: https://developer.apple.com/documentation/swiftui/scroll-views ; Nil Coalescing — Modern SwiftUI APIs for programmatic scrolling: https://nilcoalescing.com/blog/ModernSwiftUIAPIsForProgrammaticScrolling
   4b. Apple Developer Forums — iOS 27 `scrollTo` and unrealised LazyVStack rows: https://developer.apple.com/forums/thread/848608
   4c. GitHub issue — "Chat: scrolling a session makes the transcript jump" (`.sizeChanges` pulls the reader down): https://github.com/alexec/Agents/issues/2169
5. Apple — `ScrollPhaseChangeContext` (geometry, velocity; iOS 18): https://developer.apple.com/documentation/swiftui/scrollphasechangecontext ; `onScrollPhaseChange`: https://developer.apple.com/documentation/swiftui/view/onscrollphasechange(_:)
6. WWDC24 — Enhance your UI animations and transitions (zoom transition): https://developer.apple.com/videos/play/wwdc2024/10145/
   6b. Apple Developer Forums — zoom transition regressions on iOS 26: https://developer.apple.com/forums/thread/807208 , https://developer.apple.com/forums/thread/807715 , https://developer.apple.com/forums/thread/806833
7. MacRumors — iOS 26 adoption, June 2026: https://www.macrumors.com/2026/06/09/ios-26-adoption-stats-wwdc/
8. WWDC22 — Optimize for variable refresh rate displays: https://developer.apple.com/videos/play/wwdc2022/10083/
   8b. Apple — `CADisplayLink` (frame rates change with Low Power Mode, thermal state): https://developer.apple.com/documentation/quartzcore/cadisplaylink
9. WWDC25 — Build a SwiftUI app with the new design: https://developer.apple.com/videos/play/wwdc2025/323/
10. WWDC24 — What's new in UIKit (UIGestureRecognizerRepresentable): https://developer.apple.com/videos/play/wwdc2024/10118/ ; Swift with Majid: https://swiftwithmajid.com/2024/12/17/introducing-uigesturerecognizerrepresentable-protocol-in-swiftui/
11. WWDC25 — What's new in SwiftUI: https://developer.apple.com/videos/play/wwdc2025/256/
12. WWDC23 — Animate with springs: https://developer.apple.com/videos/play/wwdc2023/10158/
    12b. Apple — Unifying your app's animations (SwiftUI animations in UIKit, iOS 18): https://developer.apple.com/documentation/swiftui/unifying-your-app-s-animations
    12c. WWDC23 — Wind your way through advanced animations in SwiftUI (PhaseAnimator, KeyframeAnimator): https://developer.apple.com/videos/play/wwdc2023/10157/
    12d. Apple — `CustomAnimation`: https://developer.apple.com/documentation/swiftui/customanimation ; WWDC23 Explore SwiftUI animation: https://developer.apple.com/videos/play/wwdc2023/10156/
13. WWDC26 — SwiftUI group lab (lazy stacks vs hosted collection views; offset is an estimate; scroll state out of the environment): https://developer.apple.com/videos/play/wwdc2026/8006/
14. WWDC25 — What's new in SF Symbols 7 (Draw On): https://developer.apple.com/videos/play/wwdc2025/337/
15. Exyte Chat (read: `Sources/ExyteChat/Views/UIList.swift`): https://github.com/exyte/Chat
16. ChatLayout (read: README, `StateController.swift`, `ChatLayoutDelegate.swift`): https://github.com/ekazaev/ChatLayout
    16b. Signal-iOS (read: `Signal/ConversationView/ConversationViewLayout.swift`): https://github.com/signalapp/Signal-iOS
    16c. Telegram-iOS (read: `submodules/Display/Source/ListView.swift`): https://github.com/TelegramMessenger/Telegram-iOS
    16d. MessageKit: https://github.com/MessageKit/MessageKit
    16e. Apple Developer Forums — UIHostingConfiguration cells resize without animation: https://developer.apple.com/forums/thread/766875 ; WWDC22 Use SwiftUI with UIKit: https://developer.apple.com/videos/play/wwdc2022/10072/
17. Nuke: https://github.com/kean/Nuke
    17b. Ice Cubes (read: `Packages/Conversations/Sources/Conversations/Detail/ConversationDetailView.swift`): https://github.com/Dimillian/IceCubesApp
18. Point-Free swift-clocks: https://github.com/pointfreeco/swift-clocks
19. Point-Free swift-snapshot-testing: https://github.com/pointfreeco/swift-snapshot-testing
    19b. CircleCI — tests hanging on Xcode 26: https://discuss.circleci.com/t/tests-hanging-on-xcode-26/54156
    19c. dev.to — SwiftUI snapshot tests pass locally, fail on CI: https://dev.to/d4g4/our-swiftui-snapshot-tests-passed-locally-but-failed-on-ci-heres-the-actual-fix-5fhd
20. ViewInspector: https://github.com/nalexn/ViewInspector
    20b. Apple Developer Forums — inverted collection views and VoiceOver: https://developer.apple.com/forums/thread/759997 ; inverted ScrollViews and the iOS 26 bar fade: https://developer.apple.com/forums/thread/803130
21. Stream — building a SwiftUI message list: https://getstream.io/blog/build-message-list-swiftui/
    21a. Apple Developer Forums — List swipe actions on iOS 26: https://developer.apple.com/forums/thread/805835 , https://developer.apple.com/forums/thread/811328
    21b. Apple Developer Forums — `.searchable` in a TabView on iOS 26: https://developer.apple.com/forums/thread/804537 ; Nil Coalescing — Search in iOS 26: https://nilcoalescing.com/blog/SwiftUISearchEnhancementsIniOSAndiPadOS26
    21c. Apple Developer Forums — iOS 27 search tab: https://developer.apple.com/forums/thread/834952 ; Donny Wals — tab bars on iOS 26: https://www.donnywals.com/exploring-tab-bars-on-ios-26-with-liquid-glass/
22. SwiftUI-Introspect (read: README): https://github.com/siteline/swiftui-introspect
23. Donny Wals — stretchy header with `onScrollGeometryChange`: https://donnywals.com/building-a-stretchy-header-view-with-swiftui-on-ios-18
    23b. Apple Developer Forums — `.refreshable` misaligned tap targets: https://developer.apple.com/forums/thread/807103
24. Apple — `PagingScrollTargetBehavior`: https://developer.apple.com/documentation/swiftui/pagingscrolltargetbehavior
    24a. Apple Developer Forums — `scrollPosition(id:)` stale target hangs a paged ScrollView: https://developer.apple.com/forums/thread/845646
    24b. Apple Developer Forums — paging misaligned with contentMargins: https://developer.apple.com/forums/thread/750926
    24c. Apple Developer Forums — iOS 26 ScrollPosition object ignores commands: https://developer.apple.com/forums/thread/793716
    24d. Apple Developer Forums — ScrollView paging position off in iOS 26: https://developer.apple.com/forums/thread/801904
25. Apple — `sensoryFeedback(_:trigger:condition:)`: https://developer.apple.com/documentation/swiftui/view/sensoryfeedback(_:trigger:condition:) ; Use Your Loaf — SwiftUI Sensory Feedback: https://useyourloaf.com/blog/swiftui-sensory-feedback/
26. WWDC19 — Introducing Core Haptics: https://developer.apple.com/videos/play/wwdc2019/520/
    26b. Apple — `AVPlayerLooper`: https://developer.apple.com/documentation/avfoundation/avplayerlooper
    26c. Apple — Handling audio interruptions: https://developer.apple.com/documentation/avfaudio/handling-audio-interruptions
27. WWDC26 session 278 (iPhone apps resizable in iOS 27): https://developer.apple.com/videos/play/wwdc2026/278/ ; TN3192 — migrating from `UIRequiresFullScreen`: https://developer.apple.com/documentation/technotes/tn3192-migrating-your-app-from-the-deprecated-uirequiresfullscreen-key
28. WWDC23 — Perform accessibility audits for your app: https://developer.apple.com/videos/play/wwdc2023/10035/
29. Apple Developer Forums — iOS 26 content-area back swipe (`interactiveContentPopGestureRecognizer`): https://developer.apple.com/forums/thread/791605
    29b. Apple Developer Forums — tab bar during swipe-back on iOS 26: https://developer.apple.com/forums/thread/805740
    29c. Apple Developer Forums — back gesture with zoom transition: https://developer.apple.com/forums/thread/818848
30. Apple — `UIScrollView.touchesShouldCancel(in:)` ("The default returned value is true if view is not a UIControl object; otherwise, it returns false"): https://developer.apple.com/documentation/uikit/uiscrollview/touchesshouldcancel(in:)
31. WWDC23 — Beyond scroll views (`scrollTargetBehavior`, `contentMargins`, `scrollTransition`): https://developer.apple.com/videos/play/wwdc2023/10159/
32. Point-Free — TCA FAQ: https://pointfree.co/blog/posts/141-composable-architecture-frequently-asked-questions
33. Pow: https://github.com/EmergeTools/Pow
