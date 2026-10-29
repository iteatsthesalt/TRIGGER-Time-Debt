# TRIGGER: Time Debt

A 2.5D HD-2D sequel to Chrono Trigger, built in Godot 4.

It is 1024 A.D., twenty-four years after the Millennial Fair. Crono is 41, and he is not the boy who died at the Ocean Palace: he is a porcelain Bekkler copy with a Time Egg where his heart should be. His daughter Sera, 17, slips between seven aborted universes that the Golden Timeline was built on. Vaelos, a humanoid Lavos grown from the original Crono's atoms, wants her as the keystone of a timeline with no death and no free will. The game has nine playable characters, nine elements and nine art styles in one rendering pipeline. Combat uses Break and Boost on a live timeline, and there are eight endings decided by what you do.

## Start here

This repository is the whole project. The design lives in three bibles:

| Bible | What it covers |
|---|---|
| [`design/STORY_BIBLE.md`](design/STORY_BIBLE.md) | Premise, timeline, cast, the universes, every chapter from the Prologue to the eight endings, flags and affinity, side quests, writing guide |
| [`design/COMBAT_LAWS_BIBLE.md`](design/COMBAT_LAWS_BIBLE.md) | Battle space, timeline, shields and BREAK, damage, Boost, techs, elements, statuses, every enemy and boss, progression, constants |
| [`design/REFERENCE_BIBLE.md`](design/REFERENCE_BIBLE.md) | Art pipeline and the nine canvases, character visual specs, the 112-item visual catalog with images, UI, audio, and creation briefs, generation prompts and the full asset manifest for making every asset |

[`design/AUDIT.md`](design/AUDIT.md) records how the eight source documents were combined and which conflicts were settled.

## How to build it

The goal is the complete, finished game. You have full creative authority over it:

- Build every system, chapter and ending in the bibles.
- Create and generate every asset the game needs, including sprites, environments, VFX, UI, music, sound and voice. The Reference Bible has a brief, specs and a prompt for each asset.
- Invent anything the bibles leave open, in their spirit.
- Change or retune anything that makes the game play better. Every number in the bibles is a starting value.

## Sessions and saving work

Each session starts on a blank computer, so only work pushed to this repository carries over.

1. Start a session with `git pull`, then read [`PROGRESS.md`](PROGRESS.md) to see where the last session stopped.
2. Run `source tools/setup_godot.sh` to download Godot 4.7.2 into `.tools/`. It takes about a minute and puts `godot` on the PATH.
3. Commit and push often. Pushing after every working step is ideal; at the very least push before the session ends. Unpushed work is lost.
4. Before you stop, update `PROGRESS.md` with what now exists, what is next and any known problems. Then commit and push.

## Repository map

```
design/            the three bibles, AUDIT.md, images/ (59 catalog images + 12 plates)
prototype/         earlier working combat core (Godot 4.7, 237 headless checks) to reuse
tools/             setup_godot.sh
PROGRESS.md        running log between sessions
```

The game project itself (`project.godot`, `scenes/`, `scripts/`, `assets/` and so on) goes in the repository root as it is built. Copy from `prototype/` anything useful.

## Useful commands

```bash
source tools/setup_godot.sh                          # get Godot 4.7.2 on a fresh machine
godot --headless --path . --import                   # import assets
godot --headless --path . --script res://tests/run_tests.gd   # run tests (once the game has them)
godot --headless --path prototype --script res://tests/run_tests.gd   # prototype tests
```
