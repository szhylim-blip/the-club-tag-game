# VFX assets

Everything in `pack/` is a downloaded file from **Kenney's Particle Pack**, released
under **CC0 1.0** (public domain, no attribution required). Source page:
<https://kenney.nl/assets/particle-pack>.

The mirror used for the download is the public Kenney asset repository:
`https://raw.githubusercontent.com/shorepine/kenney/HEAD/2d/Particle%20Pack/PNG%20(Transparent)/<name>`

- 79 sprite PNGs, 512×512, transparent background.
- Originally 80 sprites; the files that 404ed on this mirror were
  `scratch_02`, `scratch_03`, `symbol_03`…`symbol_08`, so those names are absent.
- The full pack page lists the same sprites plus Unity sample scenes.

The older `explosion_*.png`, `smoke_*.png`, `star_*.png`, `streak_*.png` files at
`assets/vfx/` are earlier single-sprite pulls from the same CC0 family and remain
in use. `src/core/fx.gd` is the effects layer that consumes the pack (bursts,
shockwave rings, dust puffs, dash trails), and `src/match/match.gd` uses
`spark_06`, `smoke_04` and `trace_04` directly.
