"""Build web/squeal-preview.html from web/template.html and content/stories/en."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "content" / "stories" / "en"
PICK = [  # (id, [episode files]) shown in the preview
    ("nobodys-home", ["nobodys-home-part-1", "nobodys-home-part-2", "nobodys-home-part-3"]),
    ("first-impressions", ["first-impressions"]),
    ("the-doctor", ["the-doctor"]),
    ("skinless", ["skinless"]),
    ("last-train-out", ["last-train-out"]),
]

stories = []
for sid, files in PICK:
    eps = [json.loads((SRC / (f + ".json")).read_text()) for f in files]
    first = eps[0]
    title = first["title"].replace(" Part 1", "")
    stories.append({"id": sid, "title": title, "description": first["description"], "genre": first["genre"],
                    "episodes": [{"left": e["left"], "right": e["right"], "description": e["description"],
                                  "messages": e["messages"]} for e in eps]})
html = (ROOT / "web" / "template.html").read_text().replace("/*STORIES*/[]", json.dumps(stories, ensure_ascii=False))
(ROOT / "web" / "squeal-preview.html").write_text(html)
print(len(stories), "stories,", len(html) // 1024, "KB")
