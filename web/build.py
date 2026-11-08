"""Build web/squeal-preview.html from web/template.html and content/stories/en."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "content" / "stories" / "en"
# files named <story>-part-N.json are the parts of one story, in order
import re as _re
_groups = {}
for _f in sorted(SRC.glob("*.json"), key=lambda f: [int(x) if x.isdigit() else x for x in _re.split(r"(\d+)", f.stem)]):
    if _f.stem == "index":
        continue
    _m = _re.match(r"(.+)-part-\d+$", _f.stem)
    _groups.setdefault(_m.group(1) if _m else _f.stem, []).append(_f.stem)
PICK = sorted(_groups.items(), key=lambda kv: kv[0] != "nobodys-home")

stories = []
for sid, files in PICK:
    eps = [json.loads((SRC / (f + ".json")).read_text()) for f in files]
    first = eps[0]
    title = _re.sub(r"\s+Part 1$", "", first["title"])
    stories.append({"id": sid, "title": title, "description": first["description"], "genre": first["genre"], "author": first.get("author", ""),
                    "episodes": [{"left": e["left"], "right": e["right"], "description": e["description"],
                                  "messages": e["messages"], **({"wallpaper": e["wallpaper"]} if e.get("wallpaper") else {})} for e in eps]})
COPY = {  # store-style descriptions written for the preview (originals stay in content/)
    "nobodys-home": "Patrick is late to Sandra's party, but when he finally pulls up, the house is dark. "
                    "The front door is wide open. No music, no cars, no one answers. "
                    "His friend James keeps texting him from somewhere else — and James is starting to notice "
                    "things about that house that Patrick can't see. Three parts. Read it with the lights on.",
}
COVERS = {  # web/covers/*.jpg from the owner's "Messed images" folder
    "nobodys-home": "legs-doorway", "first-impressions": "laptop-dark", "the-doctor": "forest-path",
    "skinless": "dark-body", "last-train-out": "night-train", "clown": "clown-hush", "grave": "rising-hand",
    "haunted": "foggy-cabin", "reunion": "streetlight-man", "slice": "half-lit-face",
    "unwanted-guest": "behind-blinds", "the-crossroad": "night-couple", "love-till-death": "teal-face",
    # added 2026-11-08 from the owner's Drive (app covers of the 2018 app)
    "clinical-love": "clinical-love", "frenemy": "frenemy", "perfect-match": "perfect-match",
    "the-crushing-love": "the-crushing-love", "mystery-girlfriend": "mystery-girlfriend",
    "the-reunion-affair": "the-reunion-affair", "under-wrong-hands": "under-wrong-hands",
}
for st in stories:
    st["description"] = COPY.get(st["id"], st["description"])
    if st["id"] in COVERS:
        st["cover"] = "covers/%s.jpg" % COVERS[st["id"]]
# Guard: no story may reach the app with broken chat text (table pipes, Markdown escapes, a speaker's
# name glued to the message, unknown speakers, empty lines). The build stops and says where.
import re
problems = []
for st in stories:
    for k, ep in enumerate(st["episodes"]):
        who = {ep["left"], ep["right"]}
        for n, m in enumerate(ep["messages"]):
            t, at = m["text"], "%s part %d message %d" % (st["id"], k + 1, n + 1)
            if m["from"] not in who:
                problems.append("%s: unknown speaker %r" % (at, m["from"]))
            if not t.strip():
                problems.append("%s: empty text" % at)
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
