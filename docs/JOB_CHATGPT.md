# Job for ChatGPT: the game's text layer

You are the writer for **TRIGGER: Time Debt**, an HD-2D JRPG in the Chrono Trigger style, built in Godot
(working title; see `docs/QUESTIONS_FOR_NICH.md` on title and cast). The project is public at
https://github.com/iteatsthesalt/TRIGGER-Time-Debt. Read, in this order: `design/STORY_BIBLE.md` §10 (the
voice guide: read it twice), then the parts of `design/STORY_BIBLE.md` and `design/COMBAT_LAWS_BIBLE.md` named
below for each task. Write in the voices the guide gives; keep every line short; never explain a joke; never
use a line from an existing game.

Deliver each task as one JSON file with exactly the shape given. The game reads these files directly, so keys
must match the ids in the repository's data files, and the JSON must validate. Deliver through the Linear
project "Time Debt - Asset Pipeline" (TRI-80 was the first text delivery) or the Slack `#all-trigger` thread;
the build lead validates with `python3 tools/build/lint_data.py` and commits to `data/text/`.

**Status (2026-11-02): this job is finished and this file is its record.** Tasks 1–5 were delivered on
2026-10-29 (package SHA-256 `b8c3cc27…`, Linear TRI-80) and are in `data/text/` (`docs/DECISIONS.md`, "The
text layer is data"). Verified at import: 113 bestiary keys (82 enemies + 31 bosses), 123 techs, 15 items,
10 locations × 12 lines, 84 flags / 148 states, plain ASCII. Three item `found` fields await Nich
(`mid_tonic`, `revive`, `cobalt_wash`: Linear TRI-79, `docs/QUESTIONS_FOR_NICH.md`); a unit test pins exactly
those three.

**Future text work** is incremental: a new enemy, tech, item, location or flag gets its entry added to the same
five files. `python3 tools/build/lint_data.py` prints every game id that still has no text
(`WARN: no text for bestiary:<key>` / `techs:<id>` / `items:<id>` / `codex:<flag>[:<state>]`); that list is the
brief for the next delivery, and `Data.text_gaps` is the same list at runtime.

## Task 1: Bestiary (`data/text/bestiary.json`)

For every enemy in every JSON file under `data/enemies/` (key = the `key` field; 82 at delivery, including the
seven in `u9/postgame_enemies.json`) and every boss in `data/bosses/*.json` (key = the file name), write the
Possibility Codex entry Sera reads aloud:

```json
{"ashen_ashigaru": {"name": "Ashen Ashigaru",
  "entry": "Two or three sentences, in-world, Sera's voice: what it is, what it was before, what it wants.",
  "weak_hint": "One line that hints the weakness without naming the element outright.",
  "break_line": "One line Sera says the first time it Breaks."}}
```
Source: the enemy's `notes` field and Combat Laws §13–14 for mechanics; the Story Bible chapter for lore.

## Task 2: Tech descriptions (`data/text/techs.json`)

For every tech in `data/techs/*.json` (key = `id`; 123 at delivery):

```json
{"astral_smear_dash": {"description": "One sentence of what it does in play (plain, no numbers).",
  "flavor": "One short line in the caster's voice or the narrator's."}}
```
Source: Combat Laws §11 (the tech tables) and §10 (the kits).

## Task 3: Items and relics (`data/text/items.json`)

For every item in `data/items/items.json` and every `key_item`, `relic` and `give_item` named in
`data/dialogue/*.json` (fifteen at the time: eight items plus seven dialogue grants; the lint prints the exact
list):

```json
{"epoch_gauntlet": {"description": "One sentence: what it does.",
  "flavor": "One line of lore, Story Bible voice.",
  "found": "Where it comes from, five words."}}
```
When no vendor, chest or drop exists yet, write exactly `Acquisition source not yet recorded.` and say so in
the delivery note, as was done for the three above.

## Task 4: Ambient chatter (`data/text/ambient.json`)

For each location key below, twelve one-line things townsfolk say when bumped (Story Bible voice for that
universe; U1 townsfolk speak through paper masks and never mention the fire directly). The keys are the
engine's location ids (`scripts/autoload/scene_router.gd`): `guardia_kitchen`, `guardia_courtyard`, `atrium`,
`leene_square`, `kuro_truce`, `truce_1024`, `goyama_castle`, `jokamachi_morning`, `jokamachi_night`,
`hinterlands`.

```json
{"kuro_truce": ["Fresh paper today. The gate looks like it never happened.", "..."]}
```

**Which keys reach the game today.** `Location.add_npc` looks lines up by the scene's `location_id`
(`Data.ambient_lines(location_id)`). The delivery used `atrium_horologe`, `leene_square_fair` and
`kuro_truce_streets`; the build lead renamed those three keys to the engine ids `atrium`, `leene_square` and
`kuro_truce` on 2026-11-02 (DECISIONS "Audit fixes of 2026-11-02"), so five entries are live. The other five
(`truce_1024`, `goyama_castle`, `jokamachi_morning`, `jokamachi_night`, `hinterlands`) are written and wait for
their scenes; until a scene registers the id, `lint_data.py` warns `text/ambient: <key> matches no Router or
Location id`. `bamboo_grove` is an engine location with no lines yet. A new location needs a twelve-line entry
under its engine id.

## Task 5: Codex pages (`data/text/codex.json`)

For every flag in `data/flags/flags_u*.json` (key = `id`), a Possibility Codex page: a title and one
paragraph per state, written as the Codex Keeper (Bekkler, post-game: a clown's patter over a confession).

```json
{"Goyama": {"title": "The Town That Painted Over It",
  "pages": {"Repainted": "…", "Incinerated": "…", "Both": "…"}}}
```

## Rules

- Voices: Story Bible §10.1, exactly. Crono barely speaks. Krona drops articles. Robo is bracketed capitals.
  Vaelos has a child's syntax and a sovereign's certainty. Sera is quick and wry and calls him Papa.
- Motifs to use (§10.2): porcelain, the wrist, the spoon, the 72 BPM music box, the scarf, the bowl, "warm".
- Nothing from Chrono Trigger's or any other game's actual text. Names of our own cast only.
- Plain ASCII quotes in JSON strings; validate before handing over.

## Task 6 (withdrawn for portraits; key art still open)

Portraits are now **48x48 pixel busts in the character's palette**, made in PixelLab by the asset team
(DECISIONS "Direction"; `docs/ART_PIPELINE.md` §1b), so the painted 512 px busts this task asked for are no
longer wanted. The painted **key-art plates** remain a fit for an image model: one 1920×1080 plate per location
in `design/images/plates` style, following Reference Bible §1.11 (the canvas tails), delivered through Dropbox
"TRIGGER Time Debt / 01 Concepts for approval" and a Linear issue per `docs/BOT_REVIEW.md`; Nich approves
before anything is used.
