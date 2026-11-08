"""Build web/squeal-preview.html from web/template.html and content/stories/en."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "content" / "stories" / "en"
PICK = [("nobodys-home", ["nobodys-home-part-1", "nobodys-home-part-2", "nobodys-home-part-3"])]
_grouped = {f for _, fs in PICK for f in fs}
for _f in sorted(SRC.glob("*.json")):
    if _f.stem != "index" and _f.stem not in _grouped:
        PICK.append((_f.stem, [_f.stem]))

stories = []
for sid, files in PICK:
    eps = [json.loads((SRC / (f + ".json")).read_text()) for f in files]
    first = eps[0]
    title = first["title"].replace(" Part 1", "")
    stories.append({"id": sid, "title": title, "description": first["description"], "genre": first["genre"], "author": first.get("author", ""),
                    "episodes": [{"left": e["left"], "right": e["right"], "description": e["description"],
                                  "messages": e["messages"]} for e in eps]})
html = (ROOT / "web" / "template.html").read_text().replace("/*STORIES*/[]", json.dumps(stories, ensure_ascii=False))
(ROOT / "web" / "squeal-preview.html").write_text(html)
print(len(stories), "stories,", len(html) // 1024, "KB")
