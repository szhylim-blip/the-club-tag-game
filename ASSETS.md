# Assets

Everything in `assets/` is **CC0 1.0**. Nothing is a placeholder, nothing is generated, and nothing is randomly scattered in a level: every prop position in `src/world/arena.gd` is authored.

Re-fetch everything with:

```bash
python tools/fetch_assets.py
```

That script writes `assets/manifest.json` (path, source URL, licence, author, source page per file). It needs no keys and no browser.

## Characters — KayKit, CC0

| File | Source URL | Licence |
|---|---|---|
| `assets/characters/kaykit/skeleton_minion.glb` | https://raw.githubusercontent.com/KayKit-Game-Assets/KayKit-Character-Pack-Skeletons-1.0/HEAD/addons/kaykit_character_pack_skeletons/Characters/gltf/Skeleton_Minion.glb | CC0-1.0, Kay Lousberg (https://github.com/KayKit-Game-Assets/KayKit-Character-Pack-Skeletons-1.0) |
| `assets/characters/kaykit/skeleton_warrior.glb` | https://raw.githubusercontent.com/KayKit-Game-Assets/KayKit-Character-Pack-Skeletons-1.0/HEAD/addons/kaykit_character_pack_skeletons/Characters/gltf/Skeleton_Warrior.glb | CC0-1.0, Kay Lousberg |

Both are rigged skinned meshes with **95 animation clips** each, including `Idle`, `Idle_B`, `Walking_A/B/C`, `Running_A/B/C`, `Jump_Start`, `Jump_Idle`, `Jump_Land`, `Jump_Full_Short`, `Death_A/B`, `Sit_Chair_Idle`, `Unarmed_Idle`.

**Used by:** `ClubBot` (`src/ai/bot.gd`) — the bot body is the real skinned mesh, scaled to 1.42 m, with `Idle` / `Walking_A` / `Running_A` / `Jump_Idle` chosen from actual speed and grounded state, and a role-coloured emissive ring at the feet. This is the non-humanoid character set: a skeleton creature, not a little human.

## Props — KayKit Dungeon Remastered, CC0

| File | Source URL | Licence |
|---|---|---|
| `assets/props/box_large.glb` | https://raw.githubusercontent.com/KayKit-Game-Assets/KayKit-Dungeon-Remastered-1.0/HEAD/addons/kaykit_dungeon_remastered/Assets/gltf/box_large.gltf.glb | CC0-1.0, Kay Lousberg |
| `assets/props/crates_stacked.glb` | https://raw.githubusercontent.com/KayKit-Game-Assets/KayKit-Dungeon-Remastered-1.0/HEAD/addons/kaykit_dungeon_remastered/Assets/gltf/crates_stacked.gltf.glb | CC0-1.0, Kay Lousberg |

**Used by:** `Arena._props()` — six **fixed** placements (19, 22), (20.6, 20.4), (-20, -22), (6, -30), (-26, 6), (26.5, -6), each auto-fitted to a set height with a matching box collider.

## Surface textures — Poly Haven, CC0

| File | Source URL | Licence |
|---|---|---|
| `assets/textures/floor_concrete_diff.jpg` | https://dl.polyhaven.org/file/ph-assets/Textures/jpg/1k/concrete_floor_worn_001/concrete_floor_worn_001_diff_1k.jpg | CC0, Poly Haven (https://polyhaven.com/a/concrete_floor_worn_001) |
| `assets/textures/floor_concrete_nor.jpg` | https://dl.polyhaven.org/file/ph-assets/Textures/jpg/1k/concrete_floor_worn_001/concrete_floor_worn_001_nor_gl_1k.jpg | CC0, Poly Haven |
| `assets/textures/floor_concrete_rough.jpg` | https://dl.polyhaven.org/file/ph-assets/Textures/jpg/1k/concrete_floor_worn_001/concrete_floor_worn_001_rough_1k.jpg | CC0, Poly Haven |
| `assets/textures/wall_plaster_diff.jpg` | https://dl.polyhaven.org/file/ph-assets/Textures/jpg/1k/damaged_plaster/damaged_plaster_diff_1k.jpg | CC0, Poly Haven (https://polyhaven.com/a/damaged_plaster) |
| `assets/textures/wall_plaster_nor.jpg` | https://dl.polyhaven.org/file/ph-assets/Textures/jpg/1k/damaged_plaster/damaged_plaster_nor_gl_1k.jpg | CC0, Poly Haven |
| `assets/textures/wall_plaster_rough.jpg` | https://dl.polyhaven.org/file/ph-assets/Textures/jpg/1k/damaged_plaster/damaged_plaster_rough_1k.jpg | CC0, Poly Haven |

**Used by:** `Arena._tex_mat()` — floor gets diffuse + normal + roughness tiled 12×, walls 4×, both tinted to the room's palette. Exact URLs are recorded per file in `assets/manifest.json` (Poly Haven's CDN path is stable, the API resolves it each run).

## VFX — Kenney Explosion Pack, CC0

| File | Source URL | Licence |
|---|---|---|
| `assets/vfx/explosion_00.png` … `explosion_03.png` | https://raw.githubusercontent.com/shorepine/kenney/HEAD/2d/Explosion%20Pack/Simple%20explosion/simpleExplosion0{0..3}.png | CC0, Kenney (https://kenney.nl/assets/explosion-pack) |

**Used by:** `Match._burst()` — the tag impact particle quad is textured with `explosion_02.png` (tinted per role colour, additive bloom), replacing the untextured white square.

## Audio — Kenney UI Audio, CC0

| File | Source URL | Licence |
|---|---|---|
| `assets/audio/ui_click.wav` | https://raw.githubusercontent.com/Calinou/kenney-ui-audio/HEAD/addons/kenney_ui_audio/click1.wav | CC0, Kenney |
| `assets/audio/ui_hover.wav` | https://raw.githubusercontent.com/Calinou/kenney-ui-audio/HEAD/addons/kenney_ui_audio/rollover1.wav | CC0, Kenney |
| `assets/audio/ui_confirm.wav` | https://raw.githubusercontent.com/Calinou/kenney-ui-audio/HEAD/addons/kenney_ui_audio/mouseclick1.wav | CC0, Kenney |

**Used by:** `Sfx._build_bank()` — `click`, `hover` and `confirm` load these files over the synthesised fallbacks.

## Gameplay audio — Kenney RPG Audio, CC0

| File | Source URL | Licence |
|---|---|---|
| `assets/audio/step_00.ogg` … `step_05.ogg` | https://raw.githubusercontent.com/ismetcabbar9-oss/kenney-audio-assets/HEAD/Audio%20(295%20files)/RPG%20sounds%20(50%20sounds)/footstep00.ogg (…`footstep05.ogg`) | CC0-1.0, Kenney (https://kenney.nl/assets/rpg-audio) |
| `assets/audio/impact_00.ogg` … `impact_03.ogg` | same repo, RPG sounds, impact clips | CC0-1.0, Kenney |

**Used by:** `Sfx._load_variants()` — six footsteps become the `step` bank (randomised per step so running never sounds looped), four impacts become `land`, `tag` and `dash`. Synth remains for jump, heartbeat, stinger, win and beep.

## Particle sprites — Kenney Particle Pack, CC0

| File | Source URL | Licence |
|---|---|---|
| `assets/vfx/particle_00.png` … `particle_03.png` | https://raw.githubusercontent.com/shorepine/kenney/HEAD/2d/Particle%20Pack/PNG%20(Transparent)/… | CC0, Kenney (https://kenney.nl/assets/particle-pack) |

**Used by:** `Match._dust()` — footstep dust quads sample a real smoke/dust sprite instead of an untextured white square.

## Kenney Particle Pack — 79 sprites, downloaded 2026-11-27

| Files | Source | Licence |
|---|---|---|
| `assets/vfx/pack/*.png` (79) | https://raw.githubusercontent.com/shorepine/kenney/HEAD/2d/Particle%20Pack/PNG%20(Transparent)/ | CC0-1.0, Kenney (https://kenney.nl/assets/particle-pack) |

**Used by:** `Fx` autoload (`src/core/fx.gd`) — burst sprites (`spark_06`, `star_05`, `flare_01`, `magic_03`), shockwave puffs (`smoke_03/06`, `dirt_02`), dash streaks (`trace_04/06`, `slash_03`); `Match` uses `spark_06`, `smoke_04`, `trace_04` for tag bursts, dust and dash trails. The pack covers 79 of the 80 published sprites; `scratch_02`, `scratch_03`, `symbol_03`–`symbol_08` return 404 on the mirror and are listed in `assets/vfx/README.md`.

## What is still missing

Voice-over/proximity chat, animated authored character animation (the cast is still
code-built bean/blobs, which is the intended art direction), and an imported
9-slice UI skin. All gameplay VFX particles now sample downloaded CC0 sprites.

## Audio & VFX ledger

<!-- BEGIN:audio-vfx (generated by tools/fetch_sound.py) -->
Every gameplay sound and effect texture below is a downloaded CC0 file; no runtime-synthesised audio stands in for these events.

| File | Source URL | Licence / author |
|---|---|---|
| `res://assets/audio/ability_blink_00.ogg` | https://raw.githubusercontent.com/ismetcabbar9-oss/kenney-audio-assets/HEAD/Audio%20%28295%20files%29/Digital%20sounds%20%2860%20sounds%29/phaseJump1.ogg | CC0-1.0, Kenney |
| `res://assets/audio/ability_blink_01.ogg` | https://raw.githubusercontent.com/ismetcabbar9-oss/kenney-audio-assets/HEAD/Audio%20%28295%20files%29/Digital%20sounds%20%2860%20sounds%29/phaseJump2.ogg | CC0-1.0, Kenney |
| `res://assets/audio/ability_blink_02.ogg` | https://raw.githubusercontent.com/ismetcabbar9-oss/kenney-audio-assets/HEAD/Audio%20%28295%20files%29/Digital%20sounds%20%2860%20sounds%29/phaseJump3.ogg | CC0-1.0, Kenney |
| `res://assets/audio/ability_blink_03.ogg` | https://raw.githubusercontent.com/ismetcabbar9-oss/kenney-audio-assets/HEAD/Audio%20%28295%20files%29/Digital%20sounds%20%2860%20sounds%29/phaseJump4.ogg | CC0-1.0, Kenney |
| `res://assets/audio/ability_laser_00.ogg` | https://raw.githubusercontent.com/ismetcabbar9-oss/kenney-audio-assets/HEAD/Audio%20%28295%20files%29/Digital%20sounds%20%2860%20sounds%29/laser1.ogg | CC0-1.0, Kenney |
| `res://assets/audio/ability_laser_01.ogg` | https://raw.githubusercontent.com/ismetcabbar9-oss/kenney-audio-assets/HEAD/Audio%20%28295%20files%29/Digital%20sounds%20%2860%20sounds%29/laser2.ogg | CC0-1.0, Kenney |
| `res://assets/audio/ability_laser_02.ogg` | https://raw.githubusercontent.com/ismetcabbar9-oss/kenney-audio-assets/HEAD/Audio%20%28295%20files%29/Digital%20sounds%20%2860%20sounds%29/laser3.ogg | CC0-1.0, Kenney |
| `res://assets/audio/ability_laser_03.ogg` | https://raw.githubusercontent.com/ismetcabbar9-oss/kenney-audio-assets/HEAD/Audio%20%28295%20files%29/Digital%20sounds%20%2860%20sounds%29/laser4.ogg | CC0-1.0, Kenney |
| `res://assets/audio/ability_laser_04.ogg` | https://raw.githubusercontent.com/ismetcabbar9-oss/kenney-audio-assets/HEAD/Audio%20%28295%20files%29/Digital%20sounds%20%2860%20sounds%29/laser5.ogg | CC0-1.0, Kenney |
| `res://assets/audio/ability_power_00.ogg` | https://raw.githubusercontent.com/ismetcabbar9-oss/kenney-audio-assets/HEAD/Audio%20%28295%20files%29/Digital%20sounds%20%2860%20sounds%29/powerUp1.ogg | CC0-1.0, Kenney |
| `res://assets/audio/ability_power_01.ogg` | https://raw.githubusercontent.com/ismetcabbar9-oss/kenney-audio-assets/HEAD/Audio%20%28295%20files%29/Digital%20sounds%20%2860%20sounds%29/powerUp2.ogg | CC0-1.0, Kenney |
| `res://assets/audio/ability_power_02.ogg` | https://raw.githubusercontent.com/ismetcabbar9-oss/kenney-audio-assets/HEAD/Audio%20%28295%20files%29/Digital%20sounds%20%2860%20sounds%29/powerUp3.ogg | CC0-1.0, Kenney |
| `res://assets/audio/ability_power_03.ogg` | https://raw.githubusercontent.com/ismetcabbar9-oss/kenney-audio-assets/HEAD/Audio%20%28295%20files%29/Digital%20sounds%20%2860%20sounds%29/powerUp4.ogg | CC0-1.0, Kenney |
| `res://assets/audio/ability_power_04.ogg` | https://raw.githubusercontent.com/ismetcabbar9-oss/kenney-audio-assets/HEAD/Audio%20%28295%20files%29/Digital%20sounds%20%2860%20sounds%29/powerUp5.ogg | CC0-1.0, Kenney |
| `res://assets/audio/ability_power_05.ogg` | https://raw.githubusercontent.com/ismetcabbar9-oss/kenney-audio-assets/HEAD/Audio%20%28295%20files%29/Digital%20sounds%20%2860%20sounds%29/powerUp6.ogg | CC0-1.0, Kenney |
| `res://assets/audio/ability_zap_00.ogg` | https://raw.githubusercontent.com/ismetcabbar9-oss/kenney-audio-assets/HEAD/Audio%20%28295%20files%29/Digital%20sounds%20%2860%20sounds%29/zap1.ogg | CC0-1.0, Kenney |
| `res://assets/audio/ability_zap_01.ogg` | https://raw.githubusercontent.com/ismetcabbar9-oss/kenney-audio-assets/HEAD/Audio%20%28295%20files%29/Digital%20sounds%20%2860%20sounds%29/zap2.ogg | CC0-1.0, Kenney |
| `res://assets/audio/card_shuffle.ogg` | https://raw.githubusercontent.com/ismetcabbar9-oss/kenney-audio-assets/HEAD/Audio%20%28295%20files%29/Casino%20sounds%20%2850%20sounds%29/cardShuffle.ogg | CC0-1.0, Kenney |
| `res://assets/audio/card_slide_00.ogg` | https://raw.githubusercontent.com/ismetcabbar9-oss/kenney-audio-assets/HEAD/Audio%20%28295%20files%29/Casino%20sounds%20%2850%20sounds%29/cardSlide1.ogg | CC0-1.0, Kenney |
| `res://assets/audio/card_slide_01.ogg` | https://raw.githubusercontent.com/ismetcabbar9-oss/kenney-audio-assets/HEAD/Audio%20%28295%20files%29/Casino%20sounds%20%2850%20sounds%29/cardSlide2.ogg | CC0-1.0, Kenney |
| `res://assets/audio/card_slide_02.ogg` | https://raw.githubusercontent.com/ismetcabbar9-oss/kenney-audio-assets/HEAD/Audio%20%28295%20files%29/Casino%20sounds%20%2850%20sounds%29/cardSlide3.ogg | CC0-1.0, Kenney |
| `res://assets/audio/card_slide_03.ogg` | https://raw.githubusercontent.com/ismetcabbar9-oss/kenney-audio-assets/HEAD/Audio%20%28295%20files%29/Casino%20sounds%20%2850%20sounds%29/cardSlide4.ogg | CC0-1.0, Kenney |
| `res://assets/audio/chip_collide_00.ogg` | https://raw.githubusercontent.com/ismetcabbar9-oss/kenney-audio-assets/HEAD/Audio%20%28295%20files%29/Casino%20sounds%20%2850%20sounds%29/chipsCollide1.ogg | CC0-1.0, Kenney |
| `res://assets/audio/chip_collide_01.ogg` | https://raw.githubusercontent.com/ismetcabbar9-oss/kenney-audio-assets/HEAD/Audio%20%28295%20files%29/Casino%20sounds%20%2850%20sounds%29/chipsCollide2.ogg | CC0-1.0, Kenney |
| `res://assets/audio/chip_collide_02.ogg` | https://raw.githubusercontent.com/ismetcabbar9-oss/kenney-audio-assets/HEAD/Audio%20%28295%20files%29/Casino%20sounds%20%2850%20sounds%29/chipsCollide3.ogg | CC0-1.0, Kenney |
| `res://assets/audio/chip_collide_03.ogg` | https://raw.githubusercontent.com/ismetcabbar9-oss/kenney-audio-assets/HEAD/Audio%20%28295%20files%29/Casino%20sounds%20%2850%20sounds%29/chipsCollide4.ogg | CC0-1.0, Kenney |
| `res://assets/audio/chip_lay_00.ogg` | https://raw.githubusercontent.com/ismetcabbar9-oss/kenney-audio-assets/HEAD/Audio%20%28295%20files%29/Casino%20sounds%20%2850%20sounds%29/chipLay1.ogg | CC0-1.0, Kenney |
| `res://assets/audio/chip_lay_01.ogg` | https://raw.githubusercontent.com/ismetcabbar9-oss/kenney-audio-assets/HEAD/Audio%20%28295%20files%29/Casino%20sounds%20%2850%20sounds%29/chipLay2.ogg | CC0-1.0, Kenney |
| `res://assets/audio/chip_lay_02.ogg` | https://raw.githubusercontent.com/ismetcabbar9-oss/kenney-audio-assets/HEAD/Audio%20%28295%20files%29/Casino%20sounds%20%2850%20sounds%29/chipLay3.ogg | CC0-1.0, Kenney |
| `res://assets/audio/chip_stack_00.ogg` | https://raw.githubusercontent.com/ismetcabbar9-oss/kenney-audio-assets/HEAD/Audio%20%28295%20files%29/Casino%20sounds%20%2850%20sounds%29/chipsStack1.ogg | CC0-1.0, Kenney |
| `res://assets/audio/chip_stack_01.ogg` | https://raw.githubusercontent.com/ismetcabbar9-oss/kenney-audio-assets/HEAD/Audio%20%28295%20files%29/Casino%20sounds%20%2850%20sounds%29/chipsStack2.ogg | CC0-1.0, Kenney |
| `res://assets/audio/chip_stack_02.ogg` | https://raw.githubusercontent.com/ismetcabbar9-oss/kenney-audio-assets/HEAD/Audio%20%28295%20files%29/Casino%20sounds%20%2850%20sounds%29/chipsStack3.ogg | CC0-1.0, Kenney |
| `res://assets/audio/chip_stack_03.ogg` | https://raw.githubusercontent.com/ismetcabbar9-oss/kenney-audio-assets/HEAD/Audio%20%28295%20files%29/Casino%20sounds%20%2850%20sounds%29/chipsStack4.ogg | CC0-1.0, Kenney |
| `res://assets/audio/dice_00.ogg` | https://raw.githubusercontent.com/ismetcabbar9-oss/kenney-audio-assets/HEAD/Audio%20%28295%20files%29/Casino%20sounds%20%2850%20sounds%29/diceThrow1.ogg | CC0-1.0, Kenney |
| `res://assets/audio/dice_01.ogg` | https://raw.githubusercontent.com/ismetcabbar9-oss/kenney-audio-assets/HEAD/Audio%20%28295%20files%29/Casino%20sounds%20%2850%20sounds%29/diceThrow2.ogg | CC0-1.0, Kenney |
| `res://assets/audio/dice_02.ogg` | https://raw.githubusercontent.com/ismetcabbar9-oss/kenney-audio-assets/HEAD/Audio%20%28295%20files%29/Casino%20sounds%20%2850%20sounds%29/diceThrow3.ogg | CC0-1.0, Kenney |
| `res://assets/audio/dice_03.ogg` | https://raw.githubusercontent.com/ismetcabbar9-oss/kenney-audio-assets/HEAD/Audio%20%28295%20files%29/Casino%20sounds%20%2850%20sounds%29/diceThrow4.ogg | CC0-1.0, Kenney |
| `res://assets/audio/impact_00.ogg` | https://raw.githubusercontent.com/ismetcabbar9-oss/kenney-audio-assets/HEAD/Audio%20%28295%20files%29/Jingle%20sounds%20%2885%20sounds%29/jingles_HIT/jingles_HIT00.ogg | CC0-1.0, Kenney |
| `res://assets/audio/impact_01.ogg` | https://raw.githubusercontent.com/ismetcabbar9-oss/kenney-audio-assets/HEAD/Audio%20%28295%20files%29/Jingle%20sounds%20%2885%20sounds%29/jingles_HIT/jingles_HIT01.ogg | CC0-1.0, Kenney |
| `res://assets/audio/impact_02.ogg` | https://raw.githubusercontent.com/ismetcabbar9-oss/kenney-audio-assets/HEAD/Audio%20%28295%20files%29/Jingle%20sounds%20%2885%20sounds%29/jingles_HIT/jingles_HIT02.ogg | CC0-1.0, Kenney |
| `res://assets/audio/impact_03.ogg` | https://raw.githubusercontent.com/ismetcabbar9-oss/kenney-audio-assets/HEAD/Audio%20%28295%20files%29/Jingle%20sounds%20%2885%20sounds%29/jingles_HIT/jingles_HIT03.ogg | CC0-1.0, Kenney |
| `res://assets/audio/impact_metal_00.ogg` | https://raw.githubusercontent.com/Gl1ch5/assets-for-ai-agents/main/kenney/impact-sounds/impactMetal_medium_000.ogg | CC0-1.0, Kenney |
| `res://assets/audio/impact_metal_01.ogg` | https://raw.githubusercontent.com/Gl1ch5/assets-for-ai-agents/main/kenney/impact-sounds/impactMetal_medium_001.ogg | CC0-1.0, Kenney |
| `res://assets/audio/impact_metal_02.ogg` | https://raw.githubusercontent.com/Gl1ch5/assets-for-ai-agents/main/kenney/impact-sounds/impactMetal_medium_002.ogg | CC0-1.0, Kenney |
| `res://assets/audio/impact_metal_03.ogg` | https://raw.githubusercontent.com/Gl1ch5/assets-for-ai-agents/main/kenney/impact-sounds/impactMetal_medium_003.ogg | CC0-1.0, Kenney |
| `res://assets/audio/impact_metal_04.ogg` | https://raw.githubusercontent.com/Gl1ch5/assets-for-ai-agents/main/kenney/impact-sounds/impactMetal_medium_004.ogg | CC0-1.0, Kenney |
| `res://assets/audio/impact_punch_00.ogg` | https://raw.githubusercontent.com/Gl1ch5/assets-for-ai-agents/main/kenney/impact-sounds/impactPunch_medium_000.ogg | CC0-1.0, Kenney |
| `res://assets/audio/impact_punch_01.ogg` | https://raw.githubusercontent.com/Gl1ch5/assets-for-ai-agents/main/kenney/impact-sounds/impactPunch_medium_001.ogg | CC0-1.0, Kenney |
| `res://assets/audio/impact_punch_02.ogg` | https://raw.githubusercontent.com/Gl1ch5/assets-for-ai-agents/main/kenney/impact-sounds/impactPunch_medium_002.ogg | CC0-1.0, Kenney |
| `res://assets/audio/impact_punch_03.ogg` | https://raw.githubusercontent.com/Gl1ch5/assets-for-ai-agents/main/kenney/impact-sounds/impactPunch_medium_003.ogg | CC0-1.0, Kenney |
| `res://assets/audio/impact_punch_04.ogg` | https://raw.githubusercontent.com/Gl1ch5/assets-for-ai-agents/main/kenney/impact-sounds/impactPunch_medium_004.ogg | CC0-1.0, Kenney |
| `res://assets/audio/impact_soft_00.ogg` | https://raw.githubusercontent.com/Gl1ch5/assets-for-ai-agents/main/kenney/impact-sounds/impactSoft_medium_000.ogg | CC0-1.0, Kenney |
| `res://assets/audio/impact_soft_01.ogg` | https://raw.githubusercontent.com/Gl1ch5/assets-for-ai-agents/main/kenney/impact-sounds/impactSoft_medium_001.ogg | CC0-1.0, Kenney |
| `res://assets/audio/impact_soft_02.ogg` | https://raw.githubusercontent.com/Gl1ch5/assets-for-ai-agents/main/kenney/impact-sounds/impactSoft_medium_002.ogg | CC0-1.0, Kenney |
| `res://assets/audio/impact_soft_03.ogg` | https://raw.githubusercontent.com/Gl1ch5/assets-for-ai-agents/main/kenney/impact-sounds/impactSoft_medium_003.ogg | CC0-1.0, Kenney |
| `res://assets/audio/impact_soft_04.ogg` | https://raw.githubusercontent.com/Gl1ch5/assets-for-ai-agents/main/kenney/impact-sounds/impactSoft_medium_004.ogg | CC0-1.0, Kenney |
| `res://assets/audio/impact_wood_00.ogg` | https://raw.githubusercontent.com/Gl1ch5/assets-for-ai-agents/main/kenney/impact-sounds/impactWood_medium_000.ogg | CC0-1.0, Kenney |
| `res://assets/audio/impact_wood_01.ogg` | https://raw.githubusercontent.com/Gl1ch5/assets-for-ai-agents/main/kenney/impact-sounds/impactWood_medium_001.ogg | CC0-1.0, Kenney |
| `res://assets/audio/impact_wood_02.ogg` | https://raw.githubusercontent.com/Gl1ch5/assets-for-ai-agents/main/kenney/impact-sounds/impactWood_medium_002.ogg | CC0-1.0, Kenney |
| `res://assets/audio/impact_wood_03.ogg` | https://raw.githubusercontent.com/Gl1ch5/assets-for-ai-agents/main/kenney/impact-sounds/impactWood_medium_003.ogg | CC0-1.0, Kenney |
| `res://assets/audio/impact_wood_04.ogg` | https://raw.githubusercontent.com/Gl1ch5/assets-for-ai-agents/main/kenney/impact-sounds/impactWood_medium_004.ogg | CC0-1.0, Kenney |
| `res://assets/audio/menu_00.ogg` | https://raw.githubusercontent.com/ismetcabbar9-oss/kenney-audio-assets/HEAD/Audio%20%28295%20files%29/Jingle%20sounds%20%2885%20sounds%29/jingles_NES/jingles_NES00.ogg | CC0-1.0, Kenney |
| `res://assets/audio/menu_01.ogg` | https://raw.githubusercontent.com/ismetcabbar9-oss/kenney-audio-assets/HEAD/Audio%20%28295%20files%29/Jingle%20sounds%20%2885%20sounds%29/jingles_NES/jingles_NES05.ogg | CC0-1.0, Kenney |
| `res://assets/audio/step_00.ogg` | https://raw.githubusercontent.com/ismetcabbar9-oss/kenney-audio-assets/HEAD/Audio%20%28295%20files%29/RPG%20sounds%20%2850%20sounds%29/footstep00.ogg | CC0-1.0, Kenney |
| `res://assets/audio/step_01.ogg` | https://raw.githubusercontent.com/ismetcabbar9-oss/kenney-audio-assets/HEAD/Audio%20%28295%20files%29/RPG%20sounds%20%2850%20sounds%29/footstep01.ogg | CC0-1.0, Kenney |
| `res://assets/audio/step_02.ogg` | https://raw.githubusercontent.com/ismetcabbar9-oss/kenney-audio-assets/HEAD/Audio%20%28295%20files%29/RPG%20sounds%20%2850%20sounds%29/footstep02.ogg | CC0-1.0, Kenney |
| `res://assets/audio/step_03.ogg` | https://raw.githubusercontent.com/ismetcabbar9-oss/kenney-audio-assets/HEAD/Audio%20%28295%20files%29/RPG%20sounds%20%2850%20sounds%29/footstep03.ogg | CC0-1.0, Kenney |
| `res://assets/audio/step_04.ogg` | https://raw.githubusercontent.com/ismetcabbar9-oss/kenney-audio-assets/HEAD/Audio%20%28295%20files%29/RPG%20sounds%20%2850%20sounds%29/footstep04.ogg | CC0-1.0, Kenney |
| `res://assets/audio/step_05.ogg` | https://raw.githubusercontent.com/ismetcabbar9-oss/kenney-audio-assets/HEAD/Audio%20%28295%20files%29/RPG%20sounds%20%2850%20sounds%29/footstep05.ogg | CC0-1.0, Kenney |
| `res://assets/audio/step_carpet_00.ogg` | https://raw.githubusercontent.com/Gl1ch5/assets-for-ai-agents/main/kenney/impact-sounds/footstep_carpet_000.ogg | CC0-1.0, Kenney |
| `res://assets/audio/step_carpet_01.ogg` | https://raw.githubusercontent.com/Gl1ch5/assets-for-ai-agents/main/kenney/impact-sounds/footstep_carpet_001.ogg | CC0-1.0, Kenney |
| `res://assets/audio/step_carpet_02.ogg` | https://raw.githubusercontent.com/Gl1ch5/assets-for-ai-agents/main/kenney/impact-sounds/footstep_carpet_002.ogg | CC0-1.0, Kenney |
| `res://assets/audio/step_carpet_03.ogg` | https://raw.githubusercontent.com/Gl1ch5/assets-for-ai-agents/main/kenney/impact-sounds/footstep_carpet_003.ogg | CC0-1.0, Kenney |
| `res://assets/audio/step_carpet_04.ogg` | https://raw.githubusercontent.com/Gl1ch5/assets-for-ai-agents/main/kenney/impact-sounds/footstep_carpet_004.ogg | CC0-1.0, Kenney |
| `res://assets/audio/step_concrete_00.ogg` | https://raw.githubusercontent.com/Gl1ch5/assets-for-ai-agents/main/kenney/impact-sounds/footstep_concrete_000.ogg | CC0-1.0, Kenney |
| `res://assets/audio/step_concrete_01.ogg` | https://raw.githubusercontent.com/Gl1ch5/assets-for-ai-agents/main/kenney/impact-sounds/footstep_concrete_001.ogg | CC0-1.0, Kenney |
| `res://assets/audio/step_concrete_02.ogg` | https://raw.githubusercontent.com/Gl1ch5/assets-for-ai-agents/main/kenney/impact-sounds/footstep_concrete_002.ogg | CC0-1.0, Kenney |
| `res://assets/audio/step_concrete_03.ogg` | https://raw.githubusercontent.com/Gl1ch5/assets-for-ai-agents/main/kenney/impact-sounds/footstep_concrete_003.ogg | CC0-1.0, Kenney |
| `res://assets/audio/step_concrete_04.ogg` | https://raw.githubusercontent.com/Gl1ch5/assets-for-ai-agents/main/kenney/impact-sounds/footstep_concrete_004.ogg | CC0-1.0, Kenney |
| `res://assets/audio/step_grass_00.ogg` | https://raw.githubusercontent.com/Gl1ch5/assets-for-ai-agents/main/kenney/impact-sounds/footstep_grass_000.ogg | CC0-1.0, Kenney |
| `res://assets/audio/step_grass_01.ogg` | https://raw.githubusercontent.com/Gl1ch5/assets-for-ai-agents/main/kenney/impact-sounds/footstep_grass_001.ogg | CC0-1.0, Kenney |
| `res://assets/audio/step_grass_02.ogg` | https://raw.githubusercontent.com/Gl1ch5/assets-for-ai-agents/main/kenney/impact-sounds/footstep_grass_002.ogg | CC0-1.0, Kenney |
| `res://assets/audio/step_grass_03.ogg` | https://raw.githubusercontent.com/Gl1ch5/assets-for-ai-agents/main/kenney/impact-sounds/footstep_grass_003.ogg | CC0-1.0, Kenney |
| `res://assets/audio/step_grass_04.ogg` | https://raw.githubusercontent.com/Gl1ch5/assets-for-ai-agents/main/kenney/impact-sounds/footstep_grass_004.ogg | CC0-1.0, Kenney |
| `res://assets/audio/step_wood_00.ogg` | https://raw.githubusercontent.com/Gl1ch5/assets-for-ai-agents/main/kenney/impact-sounds/footstep_wood_000.ogg | CC0-1.0, Kenney |
| `res://assets/audio/step_wood_01.ogg` | https://raw.githubusercontent.com/Gl1ch5/assets-for-ai-agents/main/kenney/impact-sounds/footstep_wood_001.ogg | CC0-1.0, Kenney |
| `res://assets/audio/step_wood_02.ogg` | https://raw.githubusercontent.com/Gl1ch5/assets-for-ai-agents/main/kenney/impact-sounds/footstep_wood_002.ogg | CC0-1.0, Kenney |
| `res://assets/audio/step_wood_03.ogg` | https://raw.githubusercontent.com/Gl1ch5/assets-for-ai-agents/main/kenney/impact-sounds/footstep_wood_003.ogg | CC0-1.0, Kenney |
| `res://assets/audio/step_wood_04.ogg` | https://raw.githubusercontent.com/Gl1ch5/assets-for-ai-agents/main/kenney/impact-sounds/footstep_wood_004.ogg | CC0-1.0, Kenney |
| `res://assets/audio/stinger_00.ogg` | https://raw.githubusercontent.com/ismetcabbar9-oss/kenney-audio-assets/HEAD/Audio%20%28295%20files%29/Jingle%20sounds%20%2885%20sounds%29/jingles_HIT/jingles_HIT00.ogg | CC0-1.0, Kenney |
| `res://assets/audio/stinger_01.ogg` | https://raw.githubusercontent.com/ismetcabbar9-oss/kenney-audio-assets/HEAD/Audio%20%28295%20files%29/Jingle%20sounds%20%2885%20sounds%29/jingles_HIT/jingles_HIT01.ogg | CC0-1.0, Kenney |
| `res://assets/audio/stinger_02.ogg` | https://raw.githubusercontent.com/ismetcabbar9-oss/kenney-audio-assets/HEAD/Audio%20%28295%20files%29/Jingle%20sounds%20%2885%20sounds%29/jingles_HIT/jingles_HIT02.ogg | CC0-1.0, Kenney |
| `res://assets/audio/stinger_03.ogg` | https://raw.githubusercontent.com/ismetcabbar9-oss/kenney-audio-assets/HEAD/Audio%20%28295%20files%29/Jingle%20sounds%20%2885%20sounds%29/jingles_HIT/jingles_HIT03.ogg | CC0-1.0, Kenney |
| `res://assets/audio/stinger_04.ogg` | https://raw.githubusercontent.com/ismetcabbar9-oss/kenney-audio-assets/HEAD/Audio%20%28295%20files%29/Jingle%20sounds%20%2885%20sounds%29/jingles_HIT/jingles_HIT04.ogg | CC0-1.0, Kenney |
| `res://assets/audio/stinger_05.ogg` | https://raw.githubusercontent.com/ismetcabbar9-oss/kenney-audio-assets/HEAD/Audio%20%28295%20files%29/Jingle%20sounds%20%2885%20sounds%29/jingles_HIT/jingles_HIT05.ogg | CC0-1.0, Kenney |
| `res://assets/audio/stinger_06.ogg` | https://raw.githubusercontent.com/ismetcabbar9-oss/kenney-audio-assets/HEAD/Audio%20%28295%20files%29/Jingle%20sounds%20%2885%20sounds%29/jingles_HIT/jingles_HIT06.ogg | CC0-1.0, Kenney |
| `res://assets/audio/stinger_07.ogg` | https://raw.githubusercontent.com/ismetcabbar9-oss/kenney-audio-assets/HEAD/Audio%20%28295%20files%29/Jingle%20sounds%20%2885%20sounds%29/jingles_HIT/jingles_HIT07.ogg | CC0-1.0, Kenney |
| `res://assets/audio/thud_00.ogg` | https://raw.githubusercontent.com/ismetcabbar9-oss/kenney-audio-assets/HEAD/Audio%20%28295%20files%29/RPG%20sounds%20%2850%20sounds%29/doorClose_1.ogg | CC0-1.0, Kenney |
| `res://assets/audio/thud_01.ogg` | https://raw.githubusercontent.com/ismetcabbar9-oss/kenney-audio-assets/HEAD/Audio%20%28295%20files%29/RPG%20sounds%20%2850%20sounds%29/doorClose_2.ogg | CC0-1.0, Kenney |
| `res://assets/audio/thud_02.ogg` | https://raw.githubusercontent.com/ismetcabbar9-oss/kenney-audio-assets/HEAD/Audio%20%28295%20files%29/RPG%20sounds%20%2850%20sounds%29/doorClose_3.ogg | CC0-1.0, Kenney |
| `res://assets/audio/thud_03.ogg` | https://raw.githubusercontent.com/ismetcabbar9-oss/kenney-audio-assets/HEAD/Audio%20%28295%20files%29/RPG%20sounds%20%2850%20sounds%29/doorClose_4.ogg | CC0-1.0, Kenney |
| `res://assets/audio/ui_back.ogg` | https://raw.githubusercontent.com/ismetcabbar9-oss/kenney-audio-assets/HEAD/Audio%20%28295%20files%29/UI%20sounds%20%2850%20sounds%29/switch3.ogg | CC0-1.0, Kenney |
| `res://assets/audio/ui_click.wav` | https://raw.githubusercontent.com/Calinou/kenney-ui-audio/HEAD/addons/kenney_ui_audio/click1.wav | CC0-1.0, Kenney |
| `res://assets/audio/ui_click_00.ogg` | https://raw.githubusercontent.com/ismetcabbar9-oss/kenney-audio-assets/HEAD/Audio%20%28295%20files%29/UI%20sounds%20%2850%20sounds%29/click1.ogg | CC0-1.0, Kenney |
| `res://assets/audio/ui_click_01.ogg` | https://raw.githubusercontent.com/ismetcabbar9-oss/kenney-audio-assets/HEAD/Audio%20%28295%20files%29/UI%20sounds%20%2850%20sounds%29/click2.ogg | CC0-1.0, Kenney |
| `res://assets/audio/ui_click_02.ogg` | https://raw.githubusercontent.com/ismetcabbar9-oss/kenney-audio-assets/HEAD/Audio%20%28295%20files%29/UI%20sounds%20%2850%20sounds%29/click3.ogg | CC0-1.0, Kenney |
| `res://assets/audio/ui_click_03.ogg` | https://raw.githubusercontent.com/ismetcabbar9-oss/kenney-audio-assets/HEAD/Audio%20%28295%20files%29/UI%20sounds%20%2850%20sounds%29/click4.ogg | CC0-1.0, Kenney |
| `res://assets/audio/ui_click_04.ogg` | https://raw.githubusercontent.com/ismetcabbar9-oss/kenney-audio-assets/HEAD/Audio%20%28295%20files%29/UI%20sounds%20%2850%20sounds%29/click5.ogg | CC0-1.0, Kenney |
| `res://assets/audio/ui_confirm.ogg` | https://raw.githubusercontent.com/ismetcabbar9-oss/kenney-audio-assets/HEAD/Audio%20%28295%20files%29/UI%20sounds%20%2850%20sounds%29/mouseclick1.ogg | CC0-1.0, Kenney |
| `res://assets/audio/ui_confirm.wav` | https://raw.githubusercontent.com/Calinou/kenney-ui-audio/HEAD/addons/kenney_ui_audio/mouseclick1.wav | CC0-1.0, Kenney |
| `res://assets/audio/ui_hover.wav` | https://raw.githubusercontent.com/Calinou/kenney-ui-audio/HEAD/addons/kenney_ui_audio/rollover1.wav | CC0-1.0, Kenney |
| `res://assets/audio/ui_hover_00.ogg` | https://raw.githubusercontent.com/ismetcabbar9-oss/kenney-audio-assets/HEAD/Audio%20%28295%20files%29/UI%20sounds%20%2850%20sounds%29/rollover1.ogg | CC0-1.0, Kenney |
| `res://assets/audio/ui_hover_01.ogg` | https://raw.githubusercontent.com/ismetcabbar9-oss/kenney-audio-assets/HEAD/Audio%20%28295%20files%29/UI%20sounds%20%2850%20sounds%29/rollover2.ogg | CC0-1.0, Kenney |
| `res://assets/audio/ui_hover_02.ogg` | https://raw.githubusercontent.com/ismetcabbar9-oss/kenney-audio-assets/HEAD/Audio%20%28295%20files%29/UI%20sounds%20%2850%20sounds%29/rollover3.ogg | CC0-1.0, Kenney |
| `res://assets/audio/ui_hover_03.ogg` | https://raw.githubusercontent.com/ismetcabbar9-oss/kenney-audio-assets/HEAD/Audio%20%28295%20files%29/UI%20sounds%20%2850%20sounds%29/rollover4.ogg | CC0-1.0, Kenney |
| `res://assets/audio/ui_hover_04.ogg` | https://raw.githubusercontent.com/ismetcabbar9-oss/kenney-audio-assets/HEAD/Audio%20%28295%20files%29/UI%20sounds%20%2850%20sounds%29/rollover5.ogg | CC0-1.0, Kenney |
| `res://assets/audio/whoosh_00.ogg` | https://raw.githubusercontent.com/ismetcabbar9-oss/kenney-audio-assets/HEAD/Audio%20%28295%20files%29/RPG%20sounds%20%2850%20sounds%29/cloth1.ogg | CC0-1.0, Kenney |
| `res://assets/audio/whoosh_01.ogg` | https://raw.githubusercontent.com/ismetcabbar9-oss/kenney-audio-assets/HEAD/Audio%20%28295%20files%29/RPG%20sounds%20%2850%20sounds%29/cloth2.ogg | CC0-1.0, Kenney |
| `res://assets/audio/whoosh_02.ogg` | https://raw.githubusercontent.com/ismetcabbar9-oss/kenney-audio-assets/HEAD/Audio%20%28295%20files%29/RPG%20sounds%20%2850%20sounds%29/cloth3.ogg | CC0-1.0, Kenney |
| `res://assets/audio/whoosh_03.ogg` | https://raw.githubusercontent.com/ismetcabbar9-oss/kenney-audio-assets/HEAD/Audio%20%28295%20files%29/RPG%20sounds%20%2850%20sounds%29/cloth4.ogg | CC0-1.0, Kenney |
| `res://assets/audio/win_00.ogg` | https://raw.githubusercontent.com/ismetcabbar9-oss/kenney-audio-assets/HEAD/Audio%20%28295%20files%29/Jingle%20sounds%20%2885%20sounds%29/jingles_SAX/jingles_SAX00.ogg | CC0-1.0, Kenney |
| `res://assets/audio/win_01.ogg` | https://raw.githubusercontent.com/ismetcabbar9-oss/kenney-audio-assets/HEAD/Audio%20%28295%20files%29/Jingle%20sounds%20%2885%20sounds%29/jingles_SAX/jingles_SAX01.ogg | CC0-1.0, Kenney |
| `res://assets/audio/win_02.ogg` | https://raw.githubusercontent.com/ismetcabbar9-oss/kenney-audio-assets/HEAD/Audio%20%28295%20files%29/Jingle%20sounds%20%2885%20sounds%29/jingles_SAX/jingles_SAX02.ogg | CC0-1.0, Kenney |
| `res://assets/audio/win_03.ogg` | https://raw.githubusercontent.com/ismetcabbar9-oss/kenney-audio-assets/HEAD/Audio%20%28295%20files%29/Jingle%20sounds%20%2885%20sounds%29/jingles_SAX/jingles_SAX03.ogg | CC0-1.0, Kenney |
| `res://assets/vfx/dirt_00.png` | https://raw.githubusercontent.com/shorepine/kenney/HEAD/2d/Particle%20Pack/PNG%20(Transparent)/dirt_01.png | CC0-1.0, Kenney |
| `res://assets/vfx/dirt_01.png` | https://raw.githubusercontent.com/shorepine/kenney/HEAD/2d/Particle%20Pack/PNG%20(Transparent)/dirt_02.png | CC0-1.0, Kenney |
| `res://assets/vfx/explosion_00.png` | https://raw.githubusercontent.com/shorepine/kenney/HEAD/2d/Explosion%20Pack/Simple%20explosion/simpleExplosion00.png | CC0-1.0, Kenney |
| `res://assets/vfx/explosion_01.png` | https://raw.githubusercontent.com/shorepine/kenney/HEAD/2d/Explosion%20Pack/Simple%20explosion/simpleExplosion01.png | CC0-1.0, Kenney |
| `res://assets/vfx/explosion_02.png` | https://raw.githubusercontent.com/shorepine/kenney/HEAD/2d/Explosion%20Pack/Simple%20explosion/simpleExplosion02.png | CC0-1.0, Kenney |
| `res://assets/vfx/explosion_03.png` | https://raw.githubusercontent.com/shorepine/kenney/HEAD/2d/Explosion%20Pack/Simple%20explosion/simpleExplosion03.png | CC0-1.0, Kenney |
| `res://assets/vfx/light_00.png` | https://raw.githubusercontent.com/shorepine/kenney/HEAD/2d/Particle%20Pack/PNG%20(Transparent)/light_01.png | CC0-1.0, Kenney |
| `res://assets/vfx/light_01.png` | https://raw.githubusercontent.com/shorepine/kenney/HEAD/2d/Particle%20Pack/PNG%20(Transparent)/light_02.png | CC0-1.0, Kenney |
| `res://assets/vfx/particle_00.png` | https://raw.githubusercontent.com/shorepine/kenney/HEAD/2d/Particle%20Pack/PNG%20(Transparent)/fire_01.png | CC0-1.0, Kenney |
| `res://assets/vfx/particle_01.png` | https://raw.githubusercontent.com/shorepine/kenney/HEAD/2d/Particle%20Pack/PNG%20(Transparent)/fire_02.png | CC0-1.0, Kenney |
| `res://assets/vfx/particle_02.png` | https://raw.githubusercontent.com/shorepine/kenney/HEAD/2d/Particle%20Pack/PNG%20(Transparent)/smoke_01.png | CC0-1.0, Kenney |
| `res://assets/vfx/particle_03.png` | https://raw.githubusercontent.com/shorepine/kenney/HEAD/2d/Particle%20Pack/PNG%20(Transparent)/smoke_02.png | CC0-1.0, Kenney |
| `res://assets/vfx/smoke_00.png` | https://raw.githubusercontent.com/shorepine/kenney/HEAD/2d/Particle%20Pack/PNG%20(Transparent)/smoke_01.png | CC0-1.0, Kenney |
| `res://assets/vfx/smoke_01.png` | https://raw.githubusercontent.com/shorepine/kenney/HEAD/2d/Particle%20Pack/PNG%20(Transparent)/smoke_02.png | CC0-1.0, Kenney |
| `res://assets/vfx/smoke_02.png` | https://raw.githubusercontent.com/shorepine/kenney/HEAD/2d/Particle%20Pack/PNG%20(Transparent)/smoke_03.png | CC0-1.0, Kenney |
| `res://assets/vfx/star_00.png` | https://raw.githubusercontent.com/shorepine/kenney/HEAD/2d/Particle%20Pack/PNG%20(Transparent)/magic_01.png | CC0-1.0, Kenney |
| `res://assets/vfx/star_01.png` | https://raw.githubusercontent.com/shorepine/kenney/HEAD/2d/Particle%20Pack/PNG%20(Transparent)/magic_02.png | CC0-1.0, Kenney |
| `res://assets/vfx/star_02.png` | https://raw.githubusercontent.com/shorepine/kenney/HEAD/2d/Particle%20Pack/PNG%20(Transparent)/magic_03.png | CC0-1.0, Kenney |
| `res://assets/vfx/streak_00.png` | https://raw.githubusercontent.com/shorepine/kenney/HEAD/2d/Particle%20Pack/PNG%20(Transparent)/slash_01.png | CC0-1.0, Kenney |
| `res://assets/vfx/streak_01.png` | https://raw.githubusercontent.com/shorepine/kenney/HEAD/2d/Particle%20Pack/PNG%20(Transparent)/slash_02.png | CC0-1.0, Kenney |
<!-- END:audio-vfx -->
