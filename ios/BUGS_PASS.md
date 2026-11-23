# Stage 4 pass: every BUGS.md entry and every IDEAS.md UI decision against the Swift code

Verdicts: **holds** (the Swift code already does it) · **fixed** (changed in stage 4) · **n/a** (does not apply to a
native app, with the reason) · **device** (the code follows the rule, but only a real iPhone can confirm how it feels).
"tests" = covered by unit tests recorded from the web (`ios/SquealTests`), "ui" = covered by the XCUITest target.

## Summary

- BUGS.md, 168 entries (1–168, the special #52 counted once): **124 hold**, **20 fixed now**, **15 not applicable**, **9 hold in code but need a real iPhone to confirm** (52, 34, 44, 46, 98, 103, 104, 105, 159).
- IDEAS.md UI decisions, 47: **36 hold**, **5 fixed now**, **2 not applicable**, **4 need a real iPhone to confirm** (I6, I17, I18, I44).
- "Fixed" in the BUGS table means two things: the code was changed — BUGS 19, 48, 50, 54, 84, 114, 118, 126, 136, 148, 149, 155, 161 (13) — or the rule already held and is now guarded by a new test — BUGS 6, 16, 33, 58, 62, 113, 162 (7). IDEAS changed in code: I8, I15, I26, I45, I46.
- Green at the end: 40 unit tests, 10 UI test flows (`ios/SquealUITests`), screenshots on `ci-shots`.

## BUGS.md

| # | Entry | Verdict | Where / why |
|---|---|---|---|
| 52 | SPECIAL: chosen genre blinks / vanishes on Home refresh | holds + device | `HomeView`: `GenreChips` is one view outside the `fresh` fade, never rebuilt by a refresh; no web layers here. A downward pull that starts on the row never moves the oval (`HomePulls` decides by the first move). OWNER MUST TRY: pull Home down 5–10 times on different genres |
| 1 | Slider stuck between two cards | holds | `SliderEngine.tick` guard (0.3 s) + release on a taken touch (`TopSlider.onChange(touching)`) |
| 2 | Slider restarted from the first card on coming back | holds | `SliderClock` lives in `AppModel` |
| 3 | Endless slider: visible jump / worm crawling back | holds | copies at both ends, `SliderDots.layout` wrap |
| 4 | A plain touch must not pause for good | holds | clock stands only while held / covered |
| 5 | "Unwanted Guest" lettering did not fit | holds | `HeroLettering` fits by glyph bounds; CI `-letterings` pages |
| 6 | A story page did not open | fixed | new `DataTests.testEveryStoryOpensInEveryState` (all stories × 5 languages × 5 saved states) |
| 7 | Water: seams in the waves | holds | `Water.swift` draws one continuous path |
| 8 | Reset: water vanished instead of draining | holds | `PreviewView.redraw` (1 s drain) |
| 9 | Icons off centre in round buttons | holds | icons are centred frames, no button padding |
| 10 | "Part N starts over" note misplaced | holds | `PreviewView.noteView` |
| 11 | Chat closed by a swipe from anywhere | holds | `EdgeSwipe` (left edge only, below the top bar); ui |
| 12 | Back returned to the wrong screen | holds | `ChatController.close` drops the story page; ui |
| 13 | Part disc glowed; must be draggable | holds | `PartDisc` |
| 14 | No progress bars under part numbers | holds | none drawn |
| 15 | Tap counter never shown, limit works | holds | `ChatReader` (tests); ui (paywall) |
| 16 | Table markup in message text | fixed | new `DataTests.testStoryTextIsClean` (no `|`, `\!`, private-use characters, empty messages, unknown speakers) |
| 17 | A character "reveals a real name": sides must hold | holds | sides come from `from == part.right` only; `DataTests` checks every speaker is left or right |
| 18 | Favourites removal jerked | holds | `FavRows.remove`; ui |
| 19 | Unlike by hold / by a tap on the heart | fixed | found by the UI tests: with a tap recogniser and a long-press recogniser side by side on a tile, a hold never liked. Tap and hold are now one gesture that watches the finger (`TileView`, the web's longPress: 0.38 s, 8 pt); the heart's own tap still unlikes without opening the card; ui |
| 20 | No "Added" toast; a visible like | holds | `HeartBadge` draw + `playBeat`; ui (see 19) |
| 21 | Reel showed from under the tab bar | holds | `TabBar` zIndex over the page |
| 22 | Reel not pulled far enough must sink | holds | `HomePulls.sinkFrame` |
| 23 | Chosen reel row: thin outline only | holds | `ReelView` |
| 24 | Fear row blinked on focus | holds | `SearchView.focus` (no fade) |
| 25 | Gap above the pinned search field | holds | bar is outside the list |
| 26 | Captions: genre and time only | holds | `MetaLine` |
| 27 | Progress differed between screens | holds | one `AppModel.prog`, `progressRev` |
| 28 | Menu overflowed at 320 px | holds | five rows, wrapping text; iPhone SE shots |
| 29 | Reset also clears the choices | holds | `PreviewView.resetOne`, `ChatReader.again` (tests) |
| 30 | Saved path of an older story version | holds | `ChatReader` path check (tests); `DataTests` (state "stale path") |
| 31 | Story updated: progress starts over | holds | version fingerprint `PyJSON` + `Reading.prog` (tests) |
| 32 | Scroll bar in the chat | holds | `showsIndicators: false` |
| 33 | Private-use character in a text | fixed | `DataTests.testStoryTextIsClean` |
| 34 | Gamepad badge below the caption's centre | holds + device | drawn from the centred path; compared on CI shots |
| 35 | Search: Cancel jumped to the top | holds | `SearchView.backY` |
| 36 | Search: the tap that hides the keyboard opened a story | holds | `Taps.eatThisTouch` |
| 37 | First / last fear level off centre | holds | margins from the row's own width |
| 38 | Empty Favourites picture small / off centre | holds | same viewBox as the web |
| 39 | A choice cost two free taps | holds | `ChatReader` (tests) |
| 40 | Chat froze after a cancelled swipe back | holds | a swipe never stops the message being typed |
| 41 | Voice kept playing after leaving | holds | `ChatController.stopCurrent`, background observer |
| 42 | Narrow screen: ending title under the buttons | holds | the glide follows the panel (`ScrollPin.footEnd`) |
| 43 | Reel: page grew from a foreign cover | n/a | no card morph in the app |
| 44 | Reel: jerks | holds + device | `ReelGeometry` (tests), one frame loop |
| 45 | Search list did not spring / moved the field | holds | field and fear row outside the list; `alwaysBounceVertical` |
| 46 | Reel: 30 quick short pulls | holds + device | spring can be caught (`Taps.onDown["reel"]`) |
| 47 | Refresh: eyes left while a finger held the page | holds | `HomePulls.endRefresh` waits for `Taps.fingers` |
| 48 | Genre oval dragged sideways also pulled the page | fixed | the oval's drag is now a UIKit pan the page's own scrolling waits for (`HomePulls` mode `.genre`): one touch, one job |
| 49 | Refresh: chosen genre blinked | holds | see 52 |
| 50 | Oval moved a little, then down: it jumped back | fixed | same as 48: once the oval has the touch it keeps it to the lift |
| 51 | Like replayed on the tile after the story page | holds | `TileView.onChange(favs)` |
| 53 | Reset cleared the wrong part | holds | `PreviewView.resetOne` uses the selected part |
| 54 | Slider clock ran while dragged | fixed | the slider's sideways drag is now the same held UIKit pan: it is the finger's to the lift, the page never scrolls under it, and the clock stands until the card is home |
| 55 | Part switch blinked / showed the story page | holds | one `ChatScreen`, logs swapped in place |
| 56 | A tap on a part number did nothing | holds | `PartDisc` (number under the finger); ui |
| 57 | Quick part switches opened the wrong part | holds | `ChatController.goPart` cancels the pending one |
| 58 | Unknown doodle name left holes | fixed | `DataTests.testWallpaperNamesExist` |
| 59 | Story time differed on the story page | holds | one `AppModel.minutes` |
| 60 | Reel over-pulled, then down: still picked | holds | `ReelGeometry` (tests) |
| 61 | Chat jumped with every new message | holds | `ScrollPin.glideDown`, `Grow` |
| 62 | Part switch: doodles no longer fell | fixed | new `WallTests` (a switch makes the old part's doodles fall, a choice only the closed endings') |
| 63 | Part switch with progress: messages popped | holds | `SlideEngine` |
| 64 | Foot height / "Tap to continue" over the flying answer | holds | `FootLayout`; the drafts design keeps the panel's height |
| 65 | Quick taps stopped the glide | holds | only `isDragging` stops `ScrollPin` |
| 66 | End: everything overlapped | holds | `ChatController.showEnd` order |
| 67 | Conversation jerked down at a choice | holds | `ScrollPin` never moves down; `LogModel.hold` |
| 68 | Part tapped and back: eternal "typing…" | holds | typing stops only in `open(part:)` |
| 69 | Reduce Motion: jump after a choice | holds | `hold` is kept with or without motion |
| 70 | Flying answer 8 px off | n/a | the drafts design sends the answer where it stands |
| 71 | After refresh the slider flashed its first card | holds | the engine is not rebuilt by a refresh |
| 72 | A tap on the leaving chat read a message | holds | `leaving` guards; `ChatReader.leaving` |
| 73 | Picking while the panel still opened | holds | `FootAnim` starts from `FootBox.shown` |
| 74 | Picked while scrolled up | holds | `pickDraft` glides down first (0.28 s) |
| 75 | ✕ opened the card under it | holds | `Taps.closeTap` |
| 76 | Part switch: old messages over the panel | holds | ghost log clipped to its own height |
| 77 | The Doctor: speakers shifted in the source | n/a | content, waits for the owner's decision (not an app bug) |
| 78 | "typing…" flattened to a strip | holds | `TypingBubble.fixedSize` |
| 79 | Flying answer lost its last word | n/a | no flying copy; the outline is drawn inside |
| 80 | "typing…" height by measuring | holds | an invisible line of the message's own text |
| 81 | Answer re-wrapped when sent | holds | a draft is the message itself |
| 82 | Second quick part switch replayed messages | holds | `SlideEngine` goals only change |
| 83 | A finished story opened from the start | holds | `ChatReader` (tests) |
| 84 | Favourites: removing the last row jerked everything above | fixed | `FavRows.remove` glides the list's own scroll with the rows (0.34 s) when the page gets shorter; device |
| 85 | 1 → 2 → 1: messages froze for a frame | holds | springs keep speed |
| 86 | Quick taps on part numbers lost | holds | one `PartDisc` for the whole chat |
| 87 | Quick part switches twitched | holds | critically damped springs |
| 88 | Fling to the top stopped dead | holds | native bounce |
| 89 | Chat sometimes would not scroll | holds | native scrolling |
| 90 | Part switch: messages faded / came from nowhere | holds | no opacity on messages |
| 91 | Chat spring odd, description stood still | holds | description is the first row |
| 92 | Chosen answer stood too high | holds | superseded by the drafts design (IDEAS 1) |
| 93 | "What do you say?" vanished with a jerk | holds | fades with the others (0.24 s) |
| 94 | Slider: the white line stayed behind the pill | holds | the line is inside the pill |
| 95 | Strong fling stopped dead at the description | holds | native bounce |
| 96 | Leaving message vanished after a long frame | holds | `SlideEngine.tick` caps a step at two frames |
| 97 | New bubble overlapped the one above | holds | `Grow` from zero, room at the same pace |
| 98 | Reel: page rose in jumps | holds + device | a pull of ours never scrolls (`HeldPan`) |
| 99 | Story page heart drawn differently | holds | one `HeartBadge` |
| 100 | After refresh content rode up | holds | fade only (0.3 s) |
| 101 | 1 → 2 → 1: messages "vanished" | holds | waiting rows stand still off screen |
| 102 | Read messages shown, then slid in again | holds | edges in the log's own coordinates |
| 103 | Home stopped pulling both ways | holds + device | no "already handled" rule here |
| 104 | Home: native bounce on a fling | holds + device | native bounce; a touch during it is the phone's |
| 105 | A touch during the bounce cut it | holds + device | nothing changes until our pan begins |
| 106 | Search: tap on a match with the keyboard up | holds | eaten only with nothing typed |
| 107 | 320 px: name cut to "Ja…" | holds | `ChatHead(narrow:)` |
| 108 | Touch handlers piled up | holds | every `Taps.onDown` / pan is removed in `onDisappear` |
| 109 | Tap right after a swiped-away story page was lost | holds | the page moves with its hit area |
| 110 | Tap right after leaving the chat was lost | holds | `chatGone(token)` never closes a newer page |
| 111 | Rotation left the chat at the old size | n/a | portrait only (`project.yml`) |
| 112 | Double "Read again" read the first message | holds | `ChatController.early` |
| 113 | Broken saved data stopped the app | fixed | new `DataTests.testBrokenSavesAreIgnored` (garbage in every key; the store already reads defensively) |
| 114 | Home stayed pulled down after refresh | fixed | the wait for a lifted finger is now capped (8 s), should a touch's end ever be missed |
| 115 | Dots: last dot stayed lit for a frame | holds | `wormOpacity` |
| 116 | Double-tap zoom | n/a | no browser |
| 117 | Recording timer left running | holds | `stopCurrent` |
| 118 | Second finger left the screen shifted | fixed | gestures cancelled by the phone or a second finger now always put things back (see 149) |
| 119 | Long press selected text / "Save photo" | n/a | native text is not selectable |
| 120 | Page bounced as a whole / grey flash | n/a | no browser |
| 121 | Part switches counted as reads | holds | `AppModel.openStory` |
| 122 | Progress line refilled on every return | holds | `BarMemory` |
| 123 | Scrolling under the flying answer | n/a | no flight in the drafts design |
| 124 | Double "back to a choice" picked an answer | holds | 0.6 s in `pickDraft` + `SpotRule` |
| 125 | Chat could be scrolled sideways | n/a | a vertical ScrollView |
| 126 | Home worked every frame under a chat | fixed | `SliderEngine.tick` publishes only what changed: nothing is redrawn while Home is covered |
| 127 | Fonts arriving late moved the page | n/a | fonts are bundled |
| 128 | Tap during the auto turn opened the next card | holds | `downCard` |
| 129 | Water in the chosen answer 1.75 s | n/a | no water in the drafts design |
| 130 | Double "Next part" read on | holds | `early()` burst rule |
| 131 | Handlers doubled after reset | n/a | gestures are declared once |
| 132 | Part tapped, then back: chat reopened | holds | `close()` cancels `partWork` |
| 133 | Story page flashed under the leaving chat | holds | the page is dropped for good |
| 134 | Refresh, then another tab: stray handlers | holds | `showFresh` only on Home |
| 135 | Reel, then another tab: story page popped up | holds | `onHome` check |
| 136 | Double "Remove" put the story back | fixed | already guarded; now the removal also completes if the tab is left within 0.22 s, and "Remove" stands over the row instead of behind it (nothing can lie between it and the finger); ui |
| 137 | Story page after rotation | n/a | portrait only |
| 138 | Search row progress stale after reset | holds | `progressRev` |
| 139 | Part picked while water drains | holds | `redraw` never touches the selection |
| 140 | Like circle colour stopped blending | holds | `.animation(value: likeLit)` |
| 141 | Double "Next part" skipped a part | holds | `endEarly`, `SpotRule` |
| 142 | End right after a chosen answer | holds | the answer is sent in place first |
| 143 | Slider started twice after refresh | holds | one engine |
| 144 | Helper handlers piled up | n/a | none |
| 145 | Progress rules (99.6 %, read again, next part, tap given back) | holds | `Reading`, `ChatReader` (tests) |
| 146 | IDEAS cross-check numbers | holds | 0.15 s / 0.4 s fades, Favourites bounce, doodles after the fall |
| 147 | Dots misplaced when coming back early | holds | `SliderEngine.start` sets them at once |
| 148 | Double ✕ / back pressed what lay under | fixed | `SpotRule` CLOSE_TAP; the story page is now a VoiceOver modal too |
| 149 | Interruptions (background, call, system gesture) | fixed | every SwiftUI drag the phone takes away is now put back (`@GestureState` + clean-up in the story page swipe, part frame, ↺, heart, Read, part disc, menu swipe); the genre oval settles (UIKit `cancelled`); time in the background does not run the slider (`applicationState`); media paused by the phone goes back to its plain look (`VoiceClip.paint`, `VideoClip`) |
| 150 | Follow-ups of 130–149 | holds | |
| 151 | End title jerk after a video | holds | `showEnd` (`growing`) |
| 152 | Out of taps at a choice | holds | `ChatReader.foot` (tests); ui |
| 153 | Narrow screens, long languages | holds | note keeps clear of ✕, toasts wrap, 44 pt targets |
| 154 | Six gesture details | holds | pause before lift = no fling (`RowSwipe.end`, UIKit velocities) |
| 155 | Follow-ups of 151–154 | fixed | see 136; the rest holds |
| 156 | Launch clock, top-of-week ties, 3-letter search | holds | tests |
| 157 | Frame-by-frame chat check | holds | a new glide carries on from the old one |
| 158 | Spaces-only query; like "the other way round" | holds | trimmed query; `toggleFav(want:)` |
| 159 | Performance notes | device | |
| 160 | Three details (disc held, quick unlike-like, two removals) | holds | |
| 161 | Fast taps at the end; Reduce Motion | fixed | Reduce Motion now also: slider card changes at once, genre oval, tiles after a genre change, toasts, the note, likes, owl and reel settle at once (see "Reduce Motion" below) |
| 162 | build.py checks | fixed | `DataTests.testStoryShape` repeats the checks that would break the app |
| 163 | Counter stopped at 0:09; tall bubble pushed the chat | holds | `jsRound`, soft curve |
| 164 | Reply owed after coming back | holds | `ChatReader.owesReply` |
| 165 | Follow-ups | holds | |
| 166 | Double tap on a low card; open "Remove"; voice counter | holds | `openTap`, `FavRows.listen`; ui (a touch elsewhere only closes an open "Remove") |
| 167 | Double-tap guards that ate real taps | holds | guards are per touch |
| 168 | One rule for double taps | holds | `SpotRule` (tests), now also guarded if the touch watcher is missing |

## IDEAS.md → «Решения по интерфейсу — перенести в Swift как есть»

| # | Decision | Verdict | Where / why |
|---|---|---|---|
| I1 | The choice: answers are "drafts" in the chat (on trial) | holds | `Chat/ChoiceDrafts.swift`, alone in its file; ui |
| I2 | Progress: 3 messages or fewer = 0 | holds | `Reading.prog` (tests) |
| I3 | Like on a tile: 39/21 pt badge, pop, pen, ink, 0.39 s | holds | `HeartBadge` |
| I4 | Unlike: the crack, 0.32 s / 0.2 s | holds | `HeartBadge.crack` |
| I5 | Empty Favourites picture and spacing | holds | `EmptyFavourites` |
| I6 | Random story reel: turns with the finger only, stretch, sink | holds + device | `HomePulls`, `ReelGeometry` (tests); ui |
| I7 | Search: only the list moves | holds | `SearchView` |
| I8 | Story page: buttons, swipes, part frame, reset ring, note | fixed | held; now also: a finger that slides off ↺ resets nothing (the web's pointerleave) |
| I9 | Wallpaper doodles fly in, fall on a part switch | holds | `WallKeeper` (new `Stage4Tests`) |
| I10 | Interactive wallpaper: endings' doodles fall and come back | holds | `WallKeeper.setVis` (tests) |
| I11 | Reading time rule (READ_SEC = 3) | holds | `Reading` (tests, 5 languages) |
| I12 | Line breaks of an answer = of the sent message | holds | a draft is the message |
| I13 | Answers in the bottom panel, flight, water | n/a | replaced by I1 |
| I14 | New messages like WhatsApp (0.26 s) | holds | `ScrollPin`, `Grow` |
| I15 | Genres: the oval, 1:1 drag, press slides it over, one touch one job | fixed | `GenreOval`: the press on another genre now brings the oval over (0.18 s after 90 ms or the first sideways move) and the drag is a held UIKit pan (BUGS #48, #50) |
| I16 | Slider cards are not liked by a hold | holds | no long press on `HeroCard` |
| I17 | Refresh: eyes stop where they blink; wait for the finger; clock stands | holds + device | `RefreshPull`, `HomePulls` |
| I18 | Haptics: light tap on like/unlike; a growing buzz on the reset hold | holds + device | `Haptics.tap`, `Haptics.ramp` |
| I19 | Slider clock stands while held / gliding | holds | `SliderEngine.tick` |
| I20 | Slider: the "worm" | holds | `SliderDots` |
| I21 | Slider turns both ways round and round | holds | copies at both ends; ui |
| I22 | Story page like (2026-11-09) | holds | superseded by I45 |
| I23 | Story page reset: still water, the note's look | holds | `PreviewView.redraw`, `noteView` |
| I24 | Waves 1 s shorter; a picked part wakes them | holds | `WaterFill`, `select(wakeUp:)` |
| I25 | Slider white line inside the pill | holds | `SliderDots` |
| I26 | Favourites springs; removal at the end glides | fixed | BUGS #84 |
| I27 | A finished story opens at its end | holds | `ChatReader` (tests); ui |
| I28 | Story page swipes: right/down close, left/up open | holds | `PreviewView.swipe` |
| I29 | Languages (5), menu fade 0.3 + 0.3 s, tick, swipe back | holds | `MenuView`, `L10n`; ui |
| I30 | Open question: voices are English in every language | n/a | content; paid generation needs the owner's yes |
| I31 | "typing…" stretches into the message | holds | `Grow.morph` |
| I32 | "typing…" bubble = one-line message by construction | holds | `TypingBubble` |
| I33 | A new bubble grows from its pointed corner | holds | `GrowEffect` (from zero: I43) |
| I34 | Bottom panel height never jumps (0.4 s) | holds | `FootLayout` |
| I35 | "Start over" exactly where "Tap to continue" stood | holds | `EndButtons` |
| I36 | Conversation's bottom at the panel's edge | holds | as amended by I1: the chat does not move at a choice |
| I37 | Chat spring = Search's | holds | native bounce, description is a row |
| I38 | End buttons move nothing (0.125 s fades) | holds | `showEnd`, `contGhost` |
| I39 | End title rides up like a message | holds | `showEnd` |
| I40 | A tap never stops the glide | holds | `ScrollPin` |
| I41 | Part selector 40 pt, step 44 pt | holds | `PartDisc`; ui |
| I42 | Part switch: one spring per message | holds | `SlideEngine` (16/s, 12/s) |
| I43 | A new bubble grows from zero | holds | `Grow` |
| I44 | Home: native bounce + our pulls, never both | holds + device | `HeldPan` |
| I45 | Like on the story page = like on a tile | fixed | held; now the plain heart also comes back as on the web after an unlike (from 70 %, 0.18 s) |
| I46 | VoiceOver labels in all five languages | fixed | held (`L10n.a11y`); now also: a tile says how much is read and offers "Favourite" as an action, the story page is a modal, arriving messages are read out |
| I47 | Progress line fills only when new | holds | `BarMemory` |

## Reduce Motion (BUGS #69, #161, and the gaps earlier stages left)

With "Reduce Motion" on, direct manipulation still follows the finger; nothing glides, grows, rises or pulses by itself:
slider (the card changes at once, still every 4 s), genre oval and part frame (at once), tiles after a genre change
(no rise), likes and unlikes (on or off, no pop, pen or crack), progress lines (there at once), story page (water just
stands, no drain, note and buttons without motion, a swipe closes at once), toasts, Favourites rows, the empty page,
menu (words swap at once), chat (opens at once, no slides or growth, "typing…" stands at 70 %, the recording sign
stands, the hint does not breathe; pauses of typing and recording are pacing and stay), wallpaper (the plain one, closed
endings just go), owl pull (lids and page at once), reel (settles, sinks and drops at once, no pop).

## Not ported on purpose (prototype only)

TEST-UNDO button ↶ · red ✕ marks on covers to be replaced (`.fix`, build.py COVER_FIX) · the card-morph opening
(`CARD_MORPH = false` in the web too) · mouse and keyboard handlers (VoiceOver actions instead) · the web's own rubber
bands (the phone's bounce) · the web haptics work-around · font loading / boot fade · `squeal:recent` (written, never read).
