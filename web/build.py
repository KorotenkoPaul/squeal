"""Build web/squeal-preview.html from web/template.html and content/stories/<lang> (en, de, fr, es, ru)."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "content" / "stories" / "en"
# One file per story, all in the same shape (see content/STORY_FORMAT.md):
# id, title, author, genre, fear, description (preview), [interactive, featured],
# parts: [{prologue (chat intro), left, right, wallpaper, messages | start + nodes + messages}]
import re as _re
LANGS = ["en", "de", "fr", "es", "ru"]
def load(lang):
  out = []
  for _f in sorted((ROOT / "content" / "stories" / lang).glob("*.json"), key=lambda f: (f.stem != "nobodys-home", f.stem)):
    d = json.loads(_f.read_text())
    out.append({"id": d["id"], "title": d["title"], "description": d["description"], "genre": d["genre"],
                    "author": d.get("author", ""), "fear": d["fear"], **{k: True for k in ("interactive", "featured") if d.get(k)},
                    "episodes": [{"left": p["left"], "right": p["right"], "prologue": p["prologue"], "messages": p["messages"],
                                  "wallpaper": p["wallpaper"], **({"nodes": p["nodes"], "start": p["start"]} if p.get("nodes") else {}),
                                  **({"wallpaperEndings": p["wallpaperEndings"]} if p.get("wallpaperEndings") else {})}
                                 for p in d["parts"]]})
  return out
stories = load("en")
COVERS = {  # web/covers/*.jpg from the owner's "Messed images" folder
    "nobodys-home": "legs-doorway", "first-impressions": "laptop-dark", "the-doctor": "forest-path",
    "skinless": "dark-body", "last-train-out": "night-train", "clown": "clown-hush", "grave": "rising-hand",
    "haunted": "foggy-cabin", "reunion": "streetlight-man", "slice": "half-lit-face",
    "unwanted-guest": "behind-blinds", "the-crossroad": "night-couple", "love-till-death": "teal-face",
    # added 2026-11-08 from the owner's Drive (app covers of the 2018 app)
    "clinical-love": "clinical-love", "frenemy": "frenemy", "perfect-match": "perfect-match",
    "the-crushing-love": "the-crushing-love", "mystery-girlfriend": "mystery-girlfriend",
    "the-reunion-affair": "the-reunion-affair", "under-wrong-hands": "under-wrong-hands",
    "two-knocks": "two-knocks",   # OpenAI photo, two doors (design/covers/openai-clean/two-knocks-2-two-doors-openai.png)
}
# content version: a short fingerprint of what the reader actually reads (messages, branches). When a story's
# text changes, its version changes, and saved progress for the old text is reset (see prog() in the app).
import hashlib
for st in stories:
    body = json.dumps([[e["messages"], e.get("nodes")] for e in st["episodes"]], ensure_ascii=False, sort_keys=True)
    st["v"] = hashlib.sha1(body.encode()).hexdigest()[:10]
# covers that must be replaced before release (checked 2026-11-09): shown in the prototype as a red cross
# on the story's tile, so the owner sees what to make new pictures for. Remove an entry once replaced.
COVER_FIX = {
    "clinical-love": "a recognisable real person in a professional (magazine/film-style) photo, not free stock: likeness and copyright",
    "perfect-match": "same photo as First Impressions",
    "under-wrong-hands": "same photo as Unwanted Guest",
}
for st in stories:
    if st["id"] in COVERS:
        st["cover"] = "covers/%s.jpg" % COVERS[st["id"]]
    if st["id"] in COVER_FIX:
        st["coverFix"] = COVER_FIX[st["id"]]
# the other languages: same stories one for one (content/check_translations.py checks that); progress belongs
# to the story, not the language, so the version, cover and cover note come from the English original
import subprocess, sys
ALL = {"en": stories}
for lang in LANGS[1:]:
    if not (ROOT / "content" / "stories" / lang).exists(): continue
    r = subprocess.run([sys.executable, str(ROOT / "content" / "check_translations.py"), lang], capture_output=True, text=True)
    bad = [l for l in r.stdout.splitlines() if r.returncode and not l.endswith(": missing")]   # not translated yet: English is shown
    if bad: raise SystemExit("Translation %s does not match the English stories:\n%s" % (lang, "\n".join(bad)))
    en_by = {s["id"]: s for s in stories}
    ALL[lang] = [dict(s, **{k: en_by[s["id"]][k] for k in ("v", "cover", "coverFix") if k in en_by[s["id"]]}) for s in load(lang)]
# Guard: no story may reach the app with broken chat text (table pipes, Markdown escapes, a speaker's
# name glued to the message, unknown speakers, empty lines). The build stops and says where.
import re
problems = []
# doodle names must exist in the app's library (DOODLE in template.html)
_doodles = set(_re.findall(r"^  ([a-z]+): '", (ROOT / "web" / "template.html").read_text().split("const DOODLE")[1].split("};")[0], _re.M))
for st in stories:
    for k, ep in enumerate(st["episodes"]):
        we = ep.get("wallpaperEndings")
        for n in ep["wallpaper"] + [n for v in (we or {}).values() for n in v]:
            if n not in _doodles: problems.append("%s part %d: unknown doodle %r" % (st["id"], k + 1, n))
        if we:   # interactive: every ending has its own doodles (at least one), and only endings are listed
            ends = {i for i, n in (ep.get("nodes") or {}).items() if n.get("ending")}
            for i in ends - set(we): problems.append("%s part %d: ending %r has no doodles in wallpaperEndings" % (st["id"], k + 1, i))
            for i in set(we) - ends: problems.append("%s part %d: wallpaperEndings names %r, which is not an ending" % (st["id"], k + 1, i))
            for i, v in we.items():
                if not v: problems.append("%s part %d: ending %r has an empty doodle list" % (st["id"], k + 1, i))
for st in [s for l in ALL.values() for s in l]:
    for k, ep in enumerate(st["episodes"]):
        who = {ep["left"], ep["right"]}
        every = ep["messages"] + [m for node in (ep.get("nodes") or {}).values() for m in node["messages"]]   # all branches too
        for n, m in enumerate(every):
            t, at = m["text"], "%s part %d message %d" % (st["id"], k + 1, n + 1)
            if m["from"] not in who:
                problems.append("%s: unknown speaker %r" % (at, m["from"]))
            if not t.strip():
                problems.append("%s: empty text" % at)
            if m.get("video") and not (0 < m.get("dur", 0) <= 10):
                problems.append("%s: video message must be 1-10 s long (dur=%r)" % (at, m.get("dur")))
            if m.get("video") and not (ROOT / "web" / m["video"]).exists():
                problems.append("%s: video file missing %s" % (at, m["video"]))
            if m.get("voice") and not (0 < m.get("dur", 0) <= 10):
                problems.append("%s: voice message must be 1-10 s long (dur=%r)" % (at, m.get("dur")))
            if m.get("voice") and not (ROOT / "web" / m["voice"]).exists():
                problems.append("%s: voice file missing %s" % (at, m["voice"]))
            if re.search(r"[\ue000-\uf8ff]", t):
                problems.append("%s: hidden Word symbol in text %r" % (at, t[:60]))
            if "|" in t or ":-:" in t or re.search(r"\\[!.()\[\]*_#+-]", t):
                problems.append("%s: markup in text %r" % (at, t[:60]))
            if re.match(r"^(%s)\s*:" % "|".join(map(re.escape, who)), t):
                problems.append("%s: speaker name inside text %r" % (at, t[:60]))
        for field in ("left", "right"):
            if not ep[field] or "|" in ep[field] or ":" in ep[field]:
                problems.append("%s part %d: bad %s speaker %r" % (st["id"], k + 1, field, ep[field]))
    if "\\" in st["description"] or "|" in st["description"]:
        problems.append("%s: markup in description" % st["id"])
# Guard (2026-11-13): the story's shape — anything here would crash or silently misbehave in the app
_ids = [st["id"] for st in stories]
for i in set(x for x in _ids if _ids.count(x) > 1): problems.append("duplicate story id %r" % i)
for _f in (ROOT / "content" / "stories" / "en").glob("*.json"):
    if json.loads(_f.read_text())["id"] != _f.stem: problems.append("%s: id does not match the file name" % _f.name)
for st in stories:
    if st["genre"] not in ("horror", "thriller", "romance"): problems.append("%s: unknown genre %r" % (st["id"], st["genre"]))
    if not (isinstance(st["fear"], int) and 1 <= st["fear"] <= 5): problems.append("%s: fear must be a whole number 1-5 (%r)" % (st["id"], st["fear"]))
    if st["id"] not in COVERS: problems.append("%s: no cover in COVERS" % st["id"])
    elif not (ROOT / "web" / "covers" / ("%s.jpg" % COVERS[st["id"]])).exists(): problems.append("%s: cover file missing" % st["id"])
    if not st["episodes"]: problems.append("%s: no parts" % st["id"])
    for k, ep in enumerate(st["episodes"]):
        at = "%s part %d" % (st["id"], k + 1)
        if ep["left"] == ep["right"]: problems.append("%s: left and right are the same speaker" % at)
        if not ep["messages"]: problems.append("%s: no messages" % at)
        for m in ep["messages"] + [m for nd in (ep.get("nodes") or {}).values() for m in nd["messages"]]:
            if "dur" in m and not isinstance(m["dur"], int): problems.append("%s: dur must be whole seconds (%r)" % (at, m["dur"]))
            if m.get("voice") and m.get("video"): problems.append("%s: a message is both voice and video" % at)
        N = ep.get("nodes")
        if not N: continue
        if ep.get("start") not in N: problems.append("%s: start %r is not a node" % (at, ep.get("start"))); continue
        seen, todo, longest = set(), [(ep["start"], 0)], 0
        while todo:
            n, depth = todo.pop()
            node = N.get(n)
            if node is None: problems.append("%s: a choice leads to a missing node %r" % (at, n)); continue
            depth += len(node["messages"]) + (1 if n != ep["start"] else 0)   # + the answer sent to get here
            ch = node.get("choices") or []
            if node.get("ending") and ch: problems.append("%s: node %r is an ending and has choices" % (at, n))
            if not node.get("ending") and not ch: problems.append("%s: node %r is a dead end (no choices, not an ending)" % (at, n))
            if node.get("ending"): longest = max(longest, depth)
            if n in seen: continue
            seen.add(n); todo += [(c.get("next"), depth) for c in ch]
        for n in set(N) - seen: problems.append("%s: node %r can never be reached" % (at, n))
        if longest and len(ep["messages"]) != longest: problems.append("%s: messages must be the longest path (%d), not %d" % (at, longest, len(ep["messages"])))
if problems:
    raise SystemExit("Broken story text, fix content/ first:\n  " + "\n  ".join(problems[:40]))

html = (ROOT / "web" / "template.html").read_text().replace("/*STORIES*/{}", json.dumps(ALL, ensure_ascii=False))
(ROOT / "web" / "squeal-preview.html").write_text(html)
print(len(stories), "stories in", len(ALL), "languages (" + ", ".join(ALL) + "),", len(html) // 1024, "KB")
