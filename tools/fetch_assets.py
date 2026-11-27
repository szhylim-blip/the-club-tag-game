#!/usr/bin/env python3
"""Fetch THE CLUB's third-party assets.

Everything here is CC0. The script is idempotent and writes assets/manifest.json,
which ASSETS.md is generated from. No API keys, no login, no browser.

    python tools/fetch_assets.py
"""

import json
import os
import sys
import urllib.error
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


def save(rel, url, licence, author, page, kind):
    path = os.path.join(ASSETS, rel.replace("/", os.sep))
    os.makedirs(os.path.dirname(path), exist_ok=True)
    try:
        data = get(url)
    except urllib.error.HTTPError as e:
        print("FAIL %s  HTTP %s  %s" % (url, e.code, rel))
        return None
    except Exception as e:  # noqa: BLE001
        print("FAIL %s  %s  %s" % (url, e, rel))
        return None
    with open(path, "wb") as f:
        f.write(data)
    print("OK   %-46s %6d KB" % (rel, len(data) // 1024))
    return {
        "path": "res://assets/" + rel,
        "url": url,
        "license": licence,
        "author": author,
        "page": page,
        "kind": kind,
    }


def gh_tree(repo):
    return api("https://api.github.com/repos/%s/git/trees/HEAD?recursive=1" % repo)["tree"]


def gh_find(tree, needle, suffix=".glb"):
    hits = [n["path"] for n in tree if needle.lower() in n["path"].lower() and n["path"].endswith(suffix)]
    hits.sort(key=len)
    return hits[0] if hits else None


def raw(repo, path):
    return "https://raw.githubusercontent.com/%s/HEAD/%s" % (repo, path)


def ph_files(slug):
    return api("https://api.polyhaven.com/files/%s" % slug)


def find_urls(node, match):
    out = []
    if isinstance(node, dict):
        for k, v in node.items():
            if k == "url" and isinstance(v, str) and match(v):
                out.append(v)
            else:
                out.extend(find_urls(v, match))
    elif isinstance(node, list):
        for v in node:
            out.extend(find_urls(v, match))
    return out


def main():
    found = []

    # --- characters: KayKit Skeleton pack (CC0, glTF with animation clips) ---
    repo = "KayKit-Game-Assets/KayKit-Character-Pack-Skeletons-1.0"
    tree = gh_tree(repo)
    for name, out in [
        ("Skeleton_Minion.glb", "characters/kaykit/skeleton_minion.glb"),
        ("Skeleton_Warrior.glb", "characters/kaykit/skeleton_warrior.glb"),
    ]:
        p = gh_find(tree, name)
        if p:
            found.append(save(out, raw(repo, p), "CC0-1.0", "Kay Lousberg (KayKit)",
                              "https://github.com/" + repo, "character"))

    # --- props: KayKit Dungeon Remastered (CC0, glTF) ---
    repo = "KayKit-Game-Assets/KayKit-Dungeon-Remastered-1.0"
    tree = gh_tree(repo)
    for name, out in [
        ("box_large", "props/box_large.glb"),
        ("barrel_large.glb", "props/barrel_large.glb"),
        ("crates_stacked", "props/crates_stacked.glb"),
        ("table_long.", "props/table_long.glb"),
    ]:
        p = gh_find(tree, name)
        if p:
            found.append(save(out, raw(repo, p), "CC0-1.0", "Kay Lousberg (KayKit)",
                              "https://github.com/" + repo, "prop"))

    # --- surface textures: Poly Haven (CC0) ---
    for slug, out_base in [
        ("concrete_floor_worn_001", "textures/floor_concrete"),
        ("damaged_plaster", "textures/wall_plaster"),
    ]:
        try:
            files = ph_files(slug)
        except Exception as e:  # noqa: BLE001
            print("FAIL polyhaven files %s: %s" % (slug, e))
            continue
        for suffix, match, out in [
            ("_diff", lambda u: "_diff_1k.jpg" in u, out_base + "_diff.jpg"),
            ("_nor", lambda u: "_nor_gl_1k.jpg" in u, out_base + "_nor.jpg"),
            ("_rough", lambda u: "_rough_1k.jpg" in u, out_base + "_rough.jpg"),
        ]:
            urls = find_urls(files, match)
            if urls:
                found.append(save(out, urls[0], "CC0-1.0", "Poly Haven",
                                  "https://polyhaven.com/a/" + slug, "texture"))

    # --- VFX sprites: Kenney Explosion Pack (CC0) ---
    try:
        listing = api("https://api.github.com/repos/shorepine/kenney/contents/2d/Explosion%20Pack/Simple%20explosion")
        names = [n["name"] for n in listing if n["name"].endswith(".png")]
        names.sort()
        for i, n in enumerate(names[:4]):
            url = ("https://raw.githubusercontent.com/shorepine/kenney/HEAD/2d/Explosion%20Pack/"
                   "Simple%20explosion/" + urllib.parse.quote(n))
            found.append(save("vfx/explosion_%02d.png" % i, url, "CC0-1.0", "Kenney",
                              "https://kenney.nl/assets/explosion-pack", "vfx"))
    except Exception as e:  # noqa: BLE001
        print("FAIL kenney vfx: %s" % e)

    # --- audio: Kenney UI audio (CC0) ---
    repo = "Calinou/kenney-ui-audio"
    tree = gh_tree(repo)
    for name, out in [("click1.wav", "audio/ui_click.wav"),
                      ("rollover1.wav", "audio/ui_hover.wav"),
                      ("mouseclick1.wav", "audio/ui_confirm.wav")]:
        p = gh_find(tree, name, ".wav")
        if p:
            found.append(save(out, raw(repo, p), "CC0-1.0", "Kenney",
                              "https://kenney.nl/assets/ui-audio", "audio"))

    ok = [f for f in found if f]
    with open(MANIFEST, "w", encoding="utf-8") as f:
        json.dump(ok, f, indent=2)
    print("\n%d files written, manifest at assets/manifest.json" % len(ok))
    return 0 if ok else 1


if __name__ == "__main__":
    import urllib.parse  # noqa: E402  (used above via urllib.parse.quote)
    sys.exit(main())
