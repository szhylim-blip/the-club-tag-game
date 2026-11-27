#!/usr/bin/env python3
"""Second asset pass: gameplay audio (footsteps/impacts/whooshes) + smoke sprites.

    python tools/fetch_more.py

Appends to assets/manifest.json; safe to re-run.
"""

import json
import os
import sys
import urllib.error
import urllib.parse
import urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ASSETS = os.path.join(ROOT, "assets")
MANIFEST = os.path.join(ASSETS, "manifest.json")
UA = {"User-Agent": "the-club-asset-fetch/1.0 (+local build)"}


def get(url, timeout=120):
    req = urllib.request.Request(url, headers=UA)
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return r.read()


def api(url):
    return json.loads(get(url).decode("utf-8"))


def save(rel, url, licence, author, page, kind, found):
    path = os.path.join(ASSETS, rel.replace("/", os.sep))
    os.makedirs(os.path.dirname(path), exist_ok=True)
    try:
        data = get(url)
    except urllib.error.HTTPError as e:
        print("FAIL %s  HTTP %s  %s" % (url, e.code, rel))
        return
    except Exception as e:  # noqa: BLE001
        print("FAIL %s  %s  %s" % (url, e, rel))
        return
    with open(path, "wb") as f:
        f.write(data)
    print("OK   %-40s %6d KB" % (rel, len(data) // 1024))
    found.append({
        "path": "res://assets/" + rel,
        "url": url,
        "license": licence,
        "author": author,
        "page": page,
        "kind": kind,
    })


def main():
    found = []
    repo = "ismetcabbar9-oss/kenney-audio-assets"
    tree = api("https://api.github.com/repos/%s/git/trees/HEAD?recursive=1" % repo)["tree"]
    paths = [n["path"] for n in tree if "path" in n]

    def raw(p):
        return "https://raw.githubusercontent.com/%s/HEAD/%s" % (repo, urllib.parse.quote(p))

    def pick(keywords, limit, exclude=()):
        hits = []
        for p in paths:
            low = p.lower()
            if not low.endswith((".ogg", ".wav")):
                continue
            if any(x in low for x in exclude):
                continue
            if any(k in low for k in keywords):
                hits.append(p)
        hits.sort()
        return hits[:limit]

    for i, p in enumerate(pick(["footstep"], 6)):
        save("audio/step_%02d.ogg" % i, raw(p), "CC0-1.0", "Kenney",
             "https://kenney.nl/assets/rpg-audio", "audio", found)

    for i, p in enumerate(pick(["impact", "hit", "punch", "thud", "crash"], 4, exclude=("footstep",))):
        save("audio/impact_%02d.ogg" % i, raw(p), "CC0-1.0", "Kenney",
             "https://kenney.nl/assets/rpg-audio", "audio", found)

    for i, p in enumerate(pick(["whoosh", "swish", "swoosh", "wind", "dash"], 3, exclude=("footstep",))):
        save("audio/whoosh_%02d.ogg" % i, raw(p), "CC0-1.0", "Kenney",
             "https://kenney.nl/assets/digital-audio", "audio", found)

    # Kenney Particle Pack: transparent sprites for dust / dash trail
    try:
        listing = api("https://api.github.com/repos/shorepine/kenney/contents/"
                      "2d/Particle%20Pack/PNG%20(Transparent)")
        names = sorted(n["name"] for n in listing if n["name"].lower().endswith(".png"))
        chosen = [n for n in names if any(k in n.lower() for k in ("smoke", "dust", "spark", "fire"))][:4]
        if not chosen:
            chosen = names[:4]
        for i, n in enumerate(chosen):
            url = ("https://raw.githubusercontent.com/shorepine/kenney/HEAD/2d/Particle%20Pack/"
                   "PNG%20(Transparent)/" + urllib.parse.quote(n))
            save("vfx/particle_%02d.png" % i, url, "CC0-1.0", "Kenney",
                 "https://kenney.nl/assets/particle-pack", "vfx", found)
    except Exception as e:  # noqa: BLE001
        print("FAIL particle pack: %s" % e)

    old = []
    if os.path.exists(MANIFEST):
        with open(MANIFEST, encoding="utf-8") as f:
            old = json.load(f)
    by_path = {e["path"]: e for e in old}
    for e in found:
        by_path[e["path"]] = e
    with open(MANIFEST, "w", encoding="utf-8") as f:
        json.dump(list(by_path.values()), f, indent=2)
    print("\n%d new files" % len(found))
    return 0 if found else 1


if __name__ == "__main__":
    sys.exit(main())
