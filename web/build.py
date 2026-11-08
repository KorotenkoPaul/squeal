"""Build web/squeal-preview.html from web/template.html and content/stories/en."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "content" / "stories" / "en"
# One file per story, all in the same shape (see content/STORY_FORMAT.md):
# id, title, author, genre, fear, description (preview), [interactive, featured],
# parts: [{prologue (chat intro), left, right, wallpaper, messages | start + nodes + messages}]
import re as _re
stories = []
for _f in sorted(SRC.glob("*.json"), key=lambda f: (f.stem != "nobodys-home", f.stem)):
    d = json.loads(_f.read_text())
    stories.append({"id": d["id"], "title": d["title"], "description": d["description"], "genre": d["genre"],
                    "author": d.get("author", ""), "fear": d["fear"], **{k: True for k in ("interactive", "featured") if d.get(k)},
                    "episodes": [{"left": p["left"], "right": p["right"], "prologue": p["prologue"], "messages": p["messages"],
                                  "wallpaper": p["wallpaper"], **({"nodes": p["nodes"], "start": p["start"]} if p.get("nodes") else {})}
                                 for p in d["parts"]]})
COVERS = {  # web/covers/*.jpg from the owner's "Messed images" folder
    "nobodys-home": "legs-doorway", "first-impressions": "laptop-dark", "the-doctor": "forest-path",
    "skinless": "dark-body", "last-train-out": "night-train", "clown": "clown-hush", "grave": "rising-hand",
    "haunted": "foggy-cabin", "reunion": "streetlight-man", "slice": "half-lit-face",
    "unwanted-guest": "behind-blinds", "the-crossroad": "night-couple", "love-till-death": "teal-face",
    # added 2026-11-08 from the owner's Drive (app covers of the 2018 app)
    "clinical-love": "clinical-love", "frenemy": "frenemy", "perfect-match": "perfect-match",
    "the-crushing-love": "the-crushing-love", "mystery-girlfriend": "mystery-girlfriend",
    "the-reunion-affair": "the-reunion-affair", "under-wrong-hands": "under-wrong-hands",
    "two-knocks": "two-knocks",   # drawn for the story (design/covers/two-knocks.html)
}
# content version: a short fingerprint of what the reader actually reads (messages, branches). When a story's
# text changes, its version changes, and saved progress for the old text is reset (see prog() in the app).
import hashlib
for st in stories:
    body = json.dumps([[e["messages"], e.get("nodes")] for e in st["episodes"]], ensure_ascii=False, sort_keys=True)
    st["v"] = hashlib.sha1(body.encode()).hexdigest()[:10]
for st in stories:
    if st["id"] in COVERS:
        st["cover"] = "covers/%s.jpg" % COVERS[st["id"]]
# Guard: no story may reach the app with broken chat text (table pipes, Markdown escapes, a speaker's
# name glued to the message, unknown speakers, empty lines). The build stops and says where.
import re
problems = []
for st in stories:
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
if problems:
    raise SystemExit("Broken story text, fix content/ first:\n  " + "\n  ".join(problems[:40]))

html = (ROOT / "web" / "template.html").read_text().replace("/*STORIES*/[]", json.dumps(stories, ensure_ascii=False))
(ROOT / "web" / "squeal-preview.html").write_text(html)
print(len(stories), "stories,", len(html) // 1024, "KB")
