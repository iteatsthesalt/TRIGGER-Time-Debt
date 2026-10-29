# Combat prototype (from the earlier Trigger repo)

A working Godot 4.7 combat core built before the TRIGGER: Time Debt bibles existed. It is here to reuse: copy, adapt or replace whatever helps.

What it has: seamless on-map encounters, an action timeline with Sync Hold, per-strike shields and BREAK, boost spending, Dual/Triple Techs as `.tres` resources, line/circle/cone/aura targeting with floor decals, a timeline HUD, shield plates, damage numbers, a victory screen, an HD-2D camera rig, party follow, placeholder sprite and Blender asset pipelines, and 237 headless checks.

Its numbers follow the older design (per-character BP, a shield-shave cap of 3, BREAK as one lost turn). `design/COMBAT_LAWS_BIBLE.md` describes the current rules (shared party BP, Sync Hold at 99, BREAK = DEF −50% + crits with 3 s / 18 per s recovery). `docs/AUDIT.md` lists the bugs that were fixed while building it.

```bash
source ../tools/setup_godot.sh                                   # once per machine
godot --headless --path . --import
godot --headless --path . --script res://tests/run_tests.gd      # "237 passed, 0 failed"
godot --headless --path . res://scenes/combat_sandbox.tscn       # auto-plays a battle to "COMBAT ENDED"
```
Open `project.godot` in the Godot editor and press F5 to play the sandbox (arrow keys to walk, 1–9 commands, Tab target, Q/E boost, H hold, Space execute).
