import json, base64, subprocess, concurrent.futures, os
SRC = '/home/user/squeal/design/covers/minimal'
OUT = '/home/user/squeal/design/covers/openai-clean'
STYLE = (' Turn this sketch into a high-end, photorealistic photograph with the same composition. '
 'An ordinary, clean, well-kept modern American apartment building: fresh paint, smooth walls, neat finishes, nothing broken, '
 'no dirt, no stains, no peeling, no clutter, nothing run-down or creepy-old. Night, 3 a.m., low warm light, deep calm shadows, '
 'cinematic and elegant, shot on a full-frame camera, 35mm lens, shallow depth of field, subtle film grain. '
 'Minimal, uncluttered composition. No people visible. No text except what is described.')
P = {
 '1-peephole': 'Close-up of a closed apartment front door, painted deep charcoal, with raised panels, a small brass number plate "4B", a brass peephole glowing faintly with warm light from the other side, a brass deadbolt and knob on the right.',
 '2-two-doors': 'Quiet upper-floor hallway with two apartment doors side by side, charcoal panel doors with brass hardware and small brass plates "4B" and "4A", a warm wall sconce between them, a clean patterned runner. Under door 4B a thin strip of warm light and a tidy doormat. Door 4A stands half open onto complete darkness, a neat stack of unopened envelopes on the floor in front of it.',
 '3-phone': 'Inside a tidy, modern apartment entryway in the dark: the front door with a brass chain and deadbolt, a coat on a wall hook, a light switch, a pair of sneakers placed neatly to the side. A strip of warm hallway light under the door, broken by the two dark shadows of someone\'s feet standing right outside. In the foreground, a smartphone lying face up on the clean wooden floor, its screen glowing with a simple chat (generic design, no logos).',
 '4-fisheye': 'View through a door peephole: a round fisheye image framed by a brass ring, surrounded by the dark painted door. Inside the circle, a clean, well-lit modern apartment hallway at night, doors on both sides, ceiling lights, a runner carpet. At the far end, the door opposite stands slightly ajar onto pure darkness. Empty.',
 '5-two-dots': 'Inside a tidy modern apartment entryway at night: the charcoal panel front door with brass hardware and a chain, a small brass key hook with two keys on the wall, a light switch, a slim console table with a lamp switched off. On the door at knocking height, two small soft spots of warm light. Under the door, a strip of warm hallway light broken by two shadows of feet.',
}
def gen(k):
    out = f'{OUT}/two-knocks-{k}-openai.png'
    r = subprocess.run(['curl','-sS','https://api.openai.com/v1/images/edits',
        '-F','model=gpt-image-2','-F',f'image[]=@{SRC}/two-knocks-{k}.jpg;type=image/jpeg',
        '--form-string','prompt='+P[k]+STYLE,'-F','size=1536x1024','-F','quality=high','-F','stream=true','-F','partial_images=1'],
        capture_output=True, text=True, timeout=600)
    try:
        ev = [json.loads(l[5:]) for l in r.stdout.splitlines() if l.startswith('data:')]
        d = [e for e in ev if e.get('type','').endswith('completed')][-1]
        open(out,'wb').write(base64.b64decode(d['b64_json']))
        return k, 'ok', d.get('usage')
    except Exception as e:
        return k, 'FAIL', r.stdout[:400], r.stderr[:200]
with concurrent.futures.ThreadPoolExecutor(3) as ex:
    for res in ex.map(gen, P): print(*res, flush=True)
