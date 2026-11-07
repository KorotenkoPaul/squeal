"""Convert the 2018 Squeal story texts (Title/Author/Description header, then
alternating "Name" / "message" lines) into JSON used by the web preview and
the new iOS app.

    python3 content/convert.py legacy/"Stories For Squeal"/Stories content/stories/en
"""
import json
import re
import sys
import unicodedata
from pathlib import Path

GENRES = {"horror": "horror", "thriller": "thriller", "romance": "romance"}


def slug(text):
    text = unicodedata.normalize("NFKD", text).encode("ascii", "ignore").decode()
    return re.sub(r"[^a-z0-9]+", "-", text.lower()).strip("-")


def parse(path):
    lines = [l.strip() for l in path.read_text(encoding="utf-8").splitlines()]
    meta = {}
    body = []
    for line in lines:
        m = re.match(r"^(Title|Author|Description)\s*:\s*(.*)$", line)
        if m and not body:
            meta[m.group(1).lower()] = m.group(2).strip()
        elif line:
            body.append(line)
    # Speaker names are short lines that repeat; find the two most frequent.
    counts = {}
    for line in body:
        if len(line) <= 24 and not re.search(r"[.?!…,]$", line):
            counts[line] = counts.get(line, 0) + 1
    names = [n for n, c in sorted(counts.items(), key=lambda kv: -kv[1]) if c >= 3][:2]
    if len(names) < 2:
        raise ValueError("cannot find two speakers in %s" % path.name)
    messages, speaker = [], None
    for line in body:
        if line in names:
            speaker = line
        elif speaker is None or re.fullmatch(r"PART \w+", line):
            continue
        else:
            messages.append({"from": speaker, "text": line})
    first = messages[0]["from"]
    left = first
    right = names[1] if names[0] == first else names[0]
    return {
        "id": slug(meta.get("title") or re.sub(r"\s*\(\d+(\.\d+)?\)$", "", path.stem)),
        "title": meta.get("title") or re.sub(r"\s*\(\d+(\.\d+)?\)$", "", path.stem),
        "author": meta.get("author", ""),
        "description": meta.get("description", ""),
        "left": left, "right": right,
        "messages": messages,
    }


def main(src, dst):
    src, dst = Path(src), Path(dst)
    dst.mkdir(parents=True, exist_ok=True)
    index = []
    for path in sorted(src.rglob("*.txt")):
        if "summary" in path.name.lower():
            continue
        genre = next((g for k, g in GENRES.items() if k in str(path.parent).lower()), "other")
        try:
            story = parse(path)
        except ValueError as exc:
            print("SKIP", exc)
            continue
        story["genre"] = genre
        (dst / (story["id"] + ".json")).write_text(json.dumps(story, ensure_ascii=False, indent=1))
        index.append({k: story[k] for k in ("id", "title", "author", "genre")} | {"messages": len(story["messages"])})
    (dst / "index.json").write_text(json.dumps(index, ensure_ascii=False, indent=1))
    for s in index:
        print("%-9s %4d  %s" % (s["genre"], s["messages"], s["title"]))


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
