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


MD_ESCAPE = re.compile(r"\\([\\`*_{}\[\]()#+\-.!|>~])")   # "\!" -> "!" (texts came out of Word as Markdown)


def clean(text):
    return re.sub(r"\s+", " ", MD_ESCAPE.sub(r"\1", text)).strip()


SCENE = re.compile(r"^([A-Z][\w'’]*)\s+[–—-]\s+([A-Z][\w'’]*)$")   # "Mia – Dan": a new chat starts


def parse_table(body):
    """Stories saved as a two-column table: | Name: | message |. A line like "Jones – Sandy" between
    tables starts a new chat; rows are returned with the index of the chat they belong to."""
    out, scene = [], 0
    for line in body:
        if SCENE.match(line):
            if out:
                scene += 1
            continue
        if not line.startswith("|"):
            continue
        cells = [c.strip() for c in line.strip().strip("|").split("|")]
        if len(cells) < 2 or all(re.fullmatch(r":?-*:?", c) for c in cells) or not any(cells):
            continue                                   # header / separator / empty row
        name, text = cells[0].rstrip(":").strip(), clean(" | ".join(cells[1:]))
        if name and text:
            out.append((name, text, scene))
    return out


def parse(path):
    lines = [l.strip() for l in path.read_text(encoding="utf-8").splitlines()]
    meta = {}
    body = []
    for line in lines:
        m = re.match(r"^(Title|Author|Description)\s*:\s*(.*)$", line)
        if m and not body:
            meta[m.group(1).lower()] = clean(m.group(2))
        elif line:
            body.append(line)
    rows = parse_table(body)
    if len(rows) >= 3:                                 # table layout; each chat becomes a part
        parts = []
        for sc in sorted({r[2] for r in rows}):
            sub = [r for r in rows if r[2] == sc]
            names = []
            for n, *_ in sub:
                if n not in names:
                    names.append(n)
            if len(names) < 2:
                raise ValueError("cannot find two speakers in %s" % path.name)
            two = names[:2]
            # a third name inside the same chat is the same person on the other end showing their
            # real name (e.g. "Anna" signs off as "Meg"): it stays on that side
            messages = [{"from": n if n in two else two[0], "text": t} for n, t, _ in sub]
            parts.append(finish(path, meta, messages, two))
        return parts if len(parts) > 1 else parts[0]
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
            messages.append({"from": speaker, "text": clean(line)})
    return finish(path, meta, messages, names)


def finish(path, meta, messages, names):
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
        for k, part in enumerate(story if isinstance(story, list) else [story]):
            part["genre"] = genre
            if isinstance(story, list):                 # several chats: one file per part
                part["id"] += "-part-%d" % (k + 1)
                part["title"] += " Part %d" % (k + 1)
            (dst / (part["id"] + ".json")).write_text(json.dumps(part, ensure_ascii=False, indent=1))
            index.append({k2: part[k2] for k2 in ("id", "title", "author", "genre")} | {"messages": len(part["messages"])})
    (dst / "index.json").write_text(json.dumps(index, ensure_ascii=False, indent=1))
    for s in index:
        print("%-9s %4d  %s" % (s["genre"], s["messages"], s["title"]))


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
