#!/usr/bin/env python3
"""Third asset pass: a full real-audio + texture library.

    python tools/fetch_sound.py

Sources (both CC0, both mirrored on GitHub):
  * Gl1ch5/assets-for-ai-agents -> kenney/impact-sounds (footsteps per surface + impacts)
  * ismetcabbar9-oss/kenney-audio-assets (Kenney UI / RPG / Digital / Casino / Jingle)

Rewrites the AUDIO-VFX ledger block inside ASSETS.md from assets/manifest.json.
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
ASSETS_MD = os.path.join(ROOT, "ASSETS.md")
UA = {"User-Agent": "the-club-asset-fetch/1.0 (+local build)"}

IMPACT_REPO = "Gl1ch5/assets-for-ai-agents"
IMPACT_BRANCH = "main"
KENNEY_AUDIO = "ismetcabbar9-oss/kenney-audio-assets"
PARTICLES = "shorepine/kenney"

IMPACT_LICENSE = ("CC0-1.0", "Kenney", "https://kenney.nl/assets/impact-sounds")
AUDIO_LICENSE = ("CC0-1.0", "Kenney", "https://kenney.nl/assets/interface-sounds")
PARTICLE_LICENSE = ("CC0-1.0", "Kenney", "https://kenney.nl/assets/particle-pack")


def get(url, timeout=120):
    req = urllib.request.Request(url, headers=UA)
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return r.read()


def save(found, rel, url, lic):
    path = os.path.join(ASSETS, rel.replace("/", os.sep))
    os.makedirs(os.path.dirname(path), exist_ok=True)
    try:
        data = get(url)
    except urllib.error.HTTPError as e:
        print("FAIL %s  HTTP %s" % (rel, e.code))
        return
    except Exception as e:  # noqa: BLE001
        print("FAIL %s  %s" % (rel, e))
        return
    with open(path, "wb") as f:
        f.write(data)
    print("OK   %-34s %6d KB" % (rel, len(data) // 1024))
    found.append({
        "path": "res://assets/" + rel,
        "url": url,
        "license": lic[0],
        "author": lic[1],
        "page": lic[2],
        "kind": "audio" if rel.startswith("audio/") else "vfx",
    })


def impact(found, src, dest, count=5):
    for i in range(count):
        name = "%s/%s_%03d.ogg" % (src[0], src[1], i)
        url = ("https://raw.githubusercontent.com/%s/%s/kenney/impact-sounds/%s_%03d.ogg"
               % (IMPACT_REPO, IMPACT_BRANCH, src[1], i))
        save(found, "%s_%02d.ogg" % (dest, i), url, IMPACT_LICENSE)
        _ = name


def kenney(found, folder, filename, dest):
    url = ("https://raw.githubusercontent.com/%s/HEAD/%s"
           % (KENNEY_AUDIO, urllib.parse.quote(folder + "/" + filename)))
    save(found, dest, url, AUDIO_LICENSE)


def particle(found, name, dest):
    url = ("https://raw.githubusercontent.com/%s/HEAD/2d/Particle%%20Pack/"
           "PNG%%20(Transparent)/%s" % (PARTICLES, urllib.parse.quote(name)))
    save(found, dest, url, PARTICLE_LICENSE)


def main():
    found = []

    # --- footsteps: four real surfaces, five variants each -----------------
    impact(found, ("kenney", "footstep_concrete"), "audio/step_concrete")
    impact(found, ("kenney", "footstep_wood"), "audio/step_wood")
    impact(found, ("kenney", "footstep_grass"), "audio/step_grass")
    impact(found, ("kenney", "footstep_carpet"), "audio/step_carpet")

    # --- impacts ----------------------------------------------------------
    impact(found, ("kenney", "impactSoft_medium"), "audio/impact_soft")
    impact(found, ("kenney", "impactWood_medium"), "audio/impact_wood")
    impact(found, ("kenney", "impactMetal_medium"), "audio/impact_metal")
    impact(found, ("kenney", "impactPunch_medium"), "audio/impact_punch")

    # --- UI ---------------------------------------------------------------
    ui = "Audio (295 files)/UI sounds (50 sounds)"
    for i in range(1, 6):
        kenney(found, ui, "click%d.ogg" % i, "audio/ui_click_%02d.ogg" % (i - 1))
        kenney(found, ui, "rollover%d.ogg" % ((i - 1) % 6 + 1), "audio/ui_hover_%02d.ogg" % (i - 1))
    kenney(found, ui, "switch3.ogg", "audio/ui_back.ogg")
    kenney(found, ui, "mouseclick1.ogg", "audio/ui_confirm.ogg")

    # --- digital: abilities ----------------------------------------------
    dg = "Audio (295 files)/Digital sounds (60 sounds)"
    for i in range(1, 7):
        kenney(found, dg, "powerUp%d.ogg" % i, "audio/ability_power_%02d.ogg" % (i - 1))
    for i in range(1, 6):
        kenney(found, dg, "laser%d.ogg" % i, "audio/ability_laser_%02d.ogg" % (i - 1))
    for i in range(1, 5):
        kenney(found, dg, "phaseJump%d.ogg" % i, "audio/ability_blink_%02d.ogg" % (i - 1))
    kenney(found, dg, "zap1.ogg", "audio/ability_zap_00.ogg")
    kenney(found, dg, "zap2.ogg", "audio/ability_zap_01.ogg")

    # --- RPG: cloth whooshes + heavy thuds -------------------------------
    rpg = "Audio (295 files)/RPG sounds (50 sounds)"
    for i in range(1, 5):
        kenney(found, rpg, "cloth%d.ogg" % i, "audio/whoosh_%02d.ogg" % (i - 1))
    for i in range(1, 5):
        kenney(found, rpg, "doorClose_%d.ogg" % i, "audio/thud_%02d.ogg" % (i - 1))

    # --- casino / GAMBLE --------------------------------------------------
    cs = "Audio (295 files)/Casino sounds (50 sounds)"
    for i in range(1, 5):
        kenney(found, cs, "chipLay%d.ogg" % i, "audio/chip_lay_%02d.ogg" % (i - 1))
        kenney(found, cs, "chipsStack%d.ogg" % i, "audio/chip_stack_%02d.ogg" % (i - 1))
        kenney(found, cs, "chipsCollide%d.ogg" % i, "audio/chip_collide_%02d.ogg" % (i - 1))
        kenney(found, cs, "cardSlide%d.ogg" % i, "audio/card_slide_%02d.ogg" % (i - 1))
        kenney(found, cs, "diceThrow%d.ogg" % i, "audio/dice_%02d.ogg" % (i - 1))
    kenney(found, cs, "cardShuffle.ogg", "audio/card_shuffle.ogg")
    kenney(found, cs, "handleCoins.ogg", "audio/coins_handle.ogg")
    kenney(found, cs, "highUp.ogg", "audio/casino_win.ogg")
    kenney(found, cs, "highDown.ogg", "audio/casino_lose.ogg")

    # --- stingers / music cues -------------------------------------------
    jg = "Audio (295 files)/Jingle sounds (85 sounds)"
    for i in range(8):
        kenney(found, jg + "/jingles_HIT", "jingles_HIT%02d.ogg" % i, "audio/stinger_%02d.ogg" % i)
    for i in range(4):
        kenney(found, jg + "/jingles_SAX", "jingles_SAX%02d.ogg" % i, "audio/win_%02d.ogg" % i)
    kenney(found, jg + "/jingles_NES", "jingles_NES00.ogg", "audio/menu_00.ogg")
    kenney(found, jg + "/jingles_NES", "jingles_NES05.ogg", "audio/menu_01.ogg")

    # --- textures ---------------------------------------------------------
    particle(found, "smoke_01.png", "vfx/smoke_00.png")
    particle(found, "smoke_02.png", "vfx/smoke_01.png")
    particle(found, "smoke_03.png", "vfx/smoke_02.png")
    particle(found, "dirt_01.png", "vfx/dirt_00.png")
    particle(found, "dirt_02.png", "vfx/dirt_01.png")
    particle(found, "light_01.png", "vfx/light_00.png")
    particle(found, "light_02.png", "vfx/light_01.png")
    particle(found, "magic_01.png", "vfx/star_00.png")
    particle(found, "magic_02.png", "vfx/star_01.png")
    particle(found, "magic_03.png", "vfx/star_02.png")
    particle(found, "slash_01.png", "vfx/streak_00.png")
    particle(found, "slash_02.png", "vfx/streak_01.png")

    old = []
    if os.path.exists(MANIFEST):
        with open(MANIFEST, encoding="utf-8") as f:
            old = json.load(f)
    by_path = {e["path"]: e for e in old}
    for e in found:
        by_path[e["path"]] = e
    with open(MANIFEST, "w", encoding="utf-8") as f:
        json.dump(list(by_path.values()), f, indent=2)
    print("\n%d files this pass" % len(found))
    write_ledger()
    return 0


def write_ledger():
    with open(MANIFEST, encoding="utf-8") as f:
        entries = json.load(f)
    rows = [e for e in entries if e.get("kind") in ("audio", "vfx")]
    rows.sort(key=lambda e: e["path"])
    lines = [
        "<!-- BEGIN:audio-vfx (generated by tools/fetch_sound.py) -->",
        "Every gameplay sound and effect texture below is a downloaded CC0 file; "
        "no runtime-synthesised audio stands in for these events.",
        "",
        "| File | Source URL | Licence / author |",
        "|---|---|---|",
    ]
    for e in rows:
        lines.append("| `%s` | %s | %s, %s |" % (e["path"], e["url"], e["license"], e["author"]))
    lines.append("<!-- END:audio-vfx -->")
    block = "\n".join(lines)

    text = ""
    if os.path.exists(ASSETS_MD):
        with open(ASSETS_MD, encoding="utf-8") as f:
            text = f.read()
    start = text.find("<!-- BEGIN:audio-vfx")
    end = text.find("<!-- END:audio-vfx -->")
    if start >= 0 and end >= 0:
        text = text[:start] + block + text[end + len("<!-- END:audio-vfx -->"):]
    else:
        text = text.rstrip() + "\n\n## Audio & VFX ledger\n\n" + block + "\n"
    with open(ASSETS_MD, "w", encoding="utf-8") as f:
        f.write(text)
    print("ledger rows:", len(rows))


if __name__ == "__main__":
    sys.exit(main())
