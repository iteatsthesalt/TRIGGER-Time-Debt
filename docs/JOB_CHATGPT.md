# Job for ChatGPT: the game's text layer

You are the writer for **TRIGGER: Time Debt**, a 2.5D HD-2D sequel to Chrono Trigger built in Godot. The
project is public at https://github.com/iteatsthesalt/TRIGGER-Time-Debt. Read, in this order:
`design/STORY_BIBLE.md` §10 (the voice guide: read it twice), then the parts of `design/STORY_BIBLE.md` and
`design/COMBAT_LAWS_BIBLE.md` named below for each task. Write in the voices the guide gives; keep every line
short; never explain a joke; never use a line from an existing game.

Deliver each task as one JSON file with exactly the shape given. The game reads these files directly, so keys
must match the ids in the repository's data files, and the JSON must validate. Hand the file to Nich; he
commits it to `data/text/`.

## Task 1: Bestiary (`data/text/bestiary.json`)

For every enemy in `data/enemies/u*/u*_enemies.json` (key = the `key` field, 82 of them) and every boss in
`data/bosses/*.json` (key = the file name), write the Possibility Codex entry Sera reads aloud:

```json
{"ashen_ashigaru": {"name": "Ashen Ashigaru",
  "entry": "Two or three sentences, in-world, Sera's voice: what it is, what it was before, what it wants.",
  "weak_hint": "One line that hints the weakness without naming the element outright.",
  "break_line": "One line Sera says the first time it Breaks."}}
```
Source: the enemy's `notes` field and Combat Laws §13–14 for mechanics; the Story Bible chapter for lore.

## Task 2: Tech descriptions (`data/text/techs.json`)

For every tech in `data/techs/*.json` (key = `id`, 123 of them):

```json
{"astral_smear_dash": {"description": "One sentence of what it does in play (plain, no numbers).",
  "flavor": "One short line in the caster's voice or the narrator's."}}
```
Source: Combat Laws §11 (the tech tables) and §10 (the kits).

## Task 3: Items and relics (`data/text/items.json`)

For every item in `data/items/items.json` and every `key_item`, `relic` and `give_item` named in
`data/dialogue/*.json` (grep those keys; there are about thirty):

```json
{"epoch_gauntlet": {"description": "One sentence: what it does.",
  "flavor": "One line of lore, Story Bible voice.",
  "found": "Where it comes from, five words."}}
```

## Task 4: Ambient chatter (`data/text/ambient.json`)

For each location below, twelve one-line things townsfolk say when bumped (Story Bible voice for that
universe; U1 townsfolk speak through paper masks and never mention the fire directly):
`guardia_kitchen`, `guardia_courtyard`, `atrium_horologe`, `truce_1024`, `leene_square_fair`,
`kuro_truce_streets`, `goyama_castle`, `jokamachi_morning`, `jokamachi_night`, `hinterlands`.

```json
{"kuro_truce_streets": ["Fresh paper today. The gate looks like it never happened.", "..."]}
```

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

## Optional Task 6 (if you have image generation): painted art

Portraits and key art are painted, not pixel, so they are a fit for an image model. Follow Reference Bible
§5.2–§5.4 (the identity prompts) and §1.11 (the canvas tails). Deliver 512×512 transparent PNG busts, eight
expressions per character (neutral, sad, angry, surprised, smile, hurt, special_a, special_b), named
`<id>_portrait_<expr>.png`, plus one 1920×1080 key-art plate per location in `design/`'s plate style. Hand
them to Nich; they go under `assets/incoming/<id>_portrait/` per `docs/BOT_REVIEW.md`.
