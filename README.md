# THE CLUB — Multiplayer Tag

A 3D social tag game built with **Godot 4.7**. The current build contains the
Club hub, the Floor and House arenas, Tag / Hush / Infection / Hot Potato modes,
role abilities, first-person and third-person cameras, and the authored FBX
character animation set.

## Run

1. Open the folder in Godot 4.7, or run:
   ```sh
   godot --path .
   ```
2. Run the headless verification:
   ```sh
   godot --headless --path . --import
   godot --headless --path . --quit-after 22000 -- --selftest
   godot --headless --path . --quit-after 600 -- --flow-test
   ```

## Controls

- **WASD** move
- **Shift** sprint
- **Space** jump (bhop timing matters)
- **Ctrl / C** crouch or crouch-slide
- **Q** loadout ability
- **E / F** role abilities
- **Left mouse** punch
- **C** customise when not in a match
- **Esc** pause / back

## Animation source

The animation controller plays the clips in
`Animated Characters 1/Animations`. It loads the authored clip data and removes
only the `HipsCtrl` root-control track, which contains baked root motion; the
player motor owns world position. No replacement locomotion animation is
authored by the game.

## GitHub collaboration

Repository: **https://github.com/szhylim-blip/the-club-tag-game** (private)

Editors need to be invited by the owner under **Settings → Collaborators and
Teams**. Once invited, clone the project with:

```sh
git clone https://github.com/szhylim-blip/the-club-tag-game.git
cd the-club-tag-game
```

Keep `*.uid`, `*.import`, `project.godot` and the authored FBX files next to
the resources they belong to. Do not commit `.godot/`, local captures, logs, or
the `.env` family of files.

## Continuous GitHub sync

Run the project-local watcher from Git Bash to mirror edits here to GitHub and
bring collaborators' GitHub edits back into this folder:

```sh
bash tools/git-autosync.sh
```

It commits workspace edits, rebases them onto remote changes, pushes `main`, and
pulls remote changes when the local tree is clean. Its activity log is
`.git/autosync.log` (never committed). Stop it with **Ctrl+C**. The watcher only
runs while it is started; Git itself remains the source of truth.

## Asset sourcing

Environment and VFX recommendations with license links are documented in
`ASSET_SOURCES.md`. Always keep the source URL and license for third-party
assets when adding them to the project.
