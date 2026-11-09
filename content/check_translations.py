"""Check every translated story against the English original (content/stories/en).

A translation may change only text: title, description, prologue, speaker names (left/right, and the
matching "from"), message text, choice text, ending names. Everything else must match exactly, message
for message, so that a reader's progress, branches and timings carry over when the language changes.

    python3 content/check_translations.py            # all languages
    python3 content/check_translations.py de         # one language
"""
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent / "stories"
LANGS = ["de", "fr", "es", "ru"]


def check(lang):
    out = []
    en_files = sorted((ROOT / "en").glob("*.json"))
    for f in en_files:
        g = ROOT / lang / f.name
        if not g.exists():
            out.append(f"{lang}/{f.name}: missing"); continue
        try:
            a, b = json.loads(f.read_text()), json.loads(g.read_text())
        except Exception as e:
            out.append(f"{lang}/{f.name}: not valid JSON ({e})"); continue
        at = f"{lang}/{f.stem}"
        for k in a:
            if k not in b: out.append(f"{at}: field {k!r} missing")
        for k in ("id", "genre", "fear", "interactive", "featured", "author"):
            if a.get(k) != b.get(k): out.append(f"{at}: {k} must stay {a.get(k)!r}, is {b.get(k)!r}")
        for k in ("title", "description"):
            if not str(b.get(k, "")).strip(): out.append(f"{at}: empty {k}")
        if len(a["parts"]) != len(b.get("parts", [])):
            out.append(f"{at}: {len(b.get('parts', []))} parts, English has {len(a['parts'])}"); continue
        for n, (pa, pb) in enumerate(zip(a["parts"], b["parts"]), 1):
            pat = f"{at} part {n}"
            for k in ("wallpaper", "wallpaperEndings", "start"):
                if pa.get(k) != pb.get(k): out.append(f"{pat}: {k} must stay as in English")
            if not str(pb.get("prologue", "")).strip(): out.append(f"{pat}: empty prologue")
            role_a = {pa["left"]: "L", pa["right"]: "R"}
            role_b = {pb.get("left"): "L", pb.get("right"): "R"}
            if not pb.get("left") or not pb.get("right") or pb.get("left") == pb.get("right"):
                out.append(f"{pat}: bad speaker names"); continue

            def msgs(pa_msgs, pb_msgs, where):
                if len(pa_msgs) != len(pb_msgs):
                    out.append(f"{where}: {len(pb_msgs)} messages, English has {len(pa_msgs)}"); return
                for i, (ma, mb) in enumerate(zip(pa_msgs, pb_msgs), 1):
                    w = f"{where} message {i}"
                    if role_a.get(ma["from"]) != role_b.get(mb.get("from")):
                        out.append(f"{w}: written by the wrong person ({mb.get('from')!r})")
                    for k in ("voice", "video", "dur"):
                        if ma.get(k) != mb.get(k): out.append(f"{w}: {k} must stay {ma.get(k)!r}")
                    t = str(mb.get("text", ""))
                    if not t.strip(): out.append(f"{w}: empty text")
                    if "|" in t or re.search(r"\\[!.()\[\]*_#+-]", t): out.append(f"{w}: markup in text")
                    if set(mb) - {"from", "text", "voice", "video", "dur"}: out.append(f"{w}: unknown fields {set(mb) - set(ma)}")

            msgs(pa["messages"], pb.get("messages", []), pat)
            na, nb = pa.get("nodes") or {}, pb.get("nodes") or {}
            if set(na) != set(nb):
                out.append(f"{pat}: branch names must stay {sorted(na)}"); continue
            for key in na:
                xa, xb = na[key], nb[key]
                msgs(xa["messages"], xb.get("messages", []), f"{pat} branch {key}")
                if bool(xa.get("ending")) != bool(xb.get("ending")) or (xa.get("ending") and not str(xb.get("ending")).strip()):
                    out.append(f"{pat} branch {key}: ending name must be translated, not dropped")
                ca, cb = xa.get("choices") or [], xb.get("choices") or []
                if [c["next"] for c in ca] != [c.get("next") for c in cb]:
                    out.append(f"{pat} branch {key}: choices must lead to the same branches")
                for c in cb:
                    if not str(c.get("text", "")).strip(): out.append(f"{pat} branch {key}: empty choice text")
    extra = {p.name for p in (ROOT / lang).glob("*.json")} - {p.name for p in en_files}
    for x in sorted(extra): out.append(f"{lang}/{x}: no English original")
    return out


if __name__ == "__main__":
    langs = sys.argv[1:] or LANGS
    bad = []
    for l in langs:
        if not (ROOT / l).exists(): bad.append(f"{l}: folder missing"); continue
        bad += check(l)
    print("\n".join(bad[:80]) if bad else "all translations match the English structure: " + ", ".join(langs))
    sys.exit(1 if bad else 0)
