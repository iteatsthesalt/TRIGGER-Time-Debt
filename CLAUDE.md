# TRIGGER: Time Debt — working agreement for agents

You are building the complete game described in `design/` (STORY_BIBLE, COMBAT_LAWS_BIBLE, REFERENCE_BIBLE). You
have full creative authority: build what the bibles describe, invent what they leave open, retune what plays badly,
and write every call down. `README.md` is the map of the project and the how-to for adding content; this file is
how we work. Where a bible and `docs/DECISIONS.md` disagree, the newest DECISIONS entry wins (today: "Direction").

## Session protocol

1. `cd` into the repository, `git pull --rebase`, read `PROGRESS.md` (then `README.md` if you are new), then
   `source tools/setup_godot.sh` (Godot 4.7.2 on PATH; `.tools/` is git-ignored; on Nich's PC the shims below).
   Commit as yourself (Claude Code uses the machine's git identity); the history shows who built what.
2. Take the most valuable next step from `PROGRESS.md`. Build it, run `bash tools/check.sh` (or `--no-visual` for
   data/system work), look at any capture yourself, fix what broke, commit, `git pull --rebase`, push. Then the next
   step. Never force-push; never skip hooks. **Branch rule:** on Nich's PC the build lead pushes to `main`; a cloud
   session cannot, so it works on its `ccr-…` branch, opens a draft PR against `main` and says so (branch, PR,
   contents) at the top of its `PROGRESS.md` entry; Nich merges.
3. Keep `PROGRESS.md` current (what exists and is verified, what is next in priority order, known issues) at least
   hourly and after every milestone; a restarted session has nothing else. Never stop to ask: decide, record it in
   `docs/DECISIONS.md` (what, why, which bible section), and add a line to `docs/QUESTIONS_FOR_NICH.md` for Nich.
4. Copy the best new captures to `docs/screenshots/` (update its README) and attach them to the Slack `#all-trigger`
   `[BUILD]` thread. Read that channel at the start of a work block and before every push.

## Division of labour

- **Nich** makes every art decision: he approves each concept in Slack before it goes to PixelLab, picks the anchor
  and the palette (the style gate), and accepts or rejects deliveries. Nothing he has not approved ships.
- **The asset team** (Nich's bots, coordinated by Cursor) generates every asset from `docs/ASSET_REQUESTS.md`: one
  Linear issue per asset in "Time Debt - Asset Pipeline", files in Dropbox "TRIGGER Time Debt", the contract and
  audit log in `docs/BOT_REVIEW.md`. Items prefixed `TEST` or `REJECTED` are never imported.
- **Build lead (you: the Claude Code session Nich runs)** builds everything that is not art and imports, wires,
  captures and records every delivered asset. You hold the PixelLab MCP (`tools/art/pixellab_mcp.py`; downloads
  need no token) and generate only what Nich asks for or what proves a route, each file logged in
  `source_art/MANIFEST.csv`. PixelLab's 20 job slots are shared: never fill them. **Never delete anything there.**
- **The studio assistant** (a second Claude session) writes the next chapters' dialogue (`data/dialogue/`, its
  chapter's flags, generators under `tools/build/` that only write its own data), audits deliveries in
  `docs/BOT_REVIEW.md` and keeps `docs/ASSET_REQUESTS.md` ahead of you. It never edits `scenes/`, `scripts/`, `tests/`.
- **Check for incoming art at least hourly and before any scene work:** `git pull --rebase`, then
  `python3 tools/art/import_incoming.py --dry-run` and `python3 tools/art/import_incoming.py` (it reads
  `data/art/incoming.json`, the repo-side mirror of the Linear issues, written by the build lead; the bot may append);
  wire, capture, record (`data/art/pixellab_assets.json`); the contract, commands and checks are `docs/ART_PIPELINE.md`
  §2, §4 and §5. Until an asset arrives, keep the existing placeholder.

## The hand-off is a deliverable

- Nich and other tools (Claude Code, Cursor, ChatGPT) must be able to keep building from the repository alone, so
  `README.md` stays a complete orientation (run, check, add a scene / tech / enemy / boss / dialogue / flag / sprite /
  prop / text, where each kind of data lives). Update it when you add a system or change a format.
- `docs/` stays tidy: `ART_PIPELINE.md` (canonical for getting art in), `ASSET_REQUESTS.md`, `BOT_REVIEW.md`,
  `DECISIONS.md`, `QUESTIONS_FOR_NICH.md`, `JOB_CHATGPT.md` (the text-layer brief, the record of a finished job),
  `reports/`, `screenshots/`. `PROGRESS.md` lives in the root.
- Systems are generic before they are wide: a mechanic goes into data + a reusable component, never a special case
  in one scene. Files stay small (scripts under ~600 lines, one class per file); content is `data/` JSON.

## Quality bar

- Art follows the Nov 1 recipe (DECISIONS "Direction"; `docs/ART_PIPELINE.md` §1): 64x64 sprites three heads tall
  at 32 px per metre, one locked palette (Resurrect 64 until Nich confirms another), 12–14 colours per character,
  coloured selective outlines and no pure black, flat cel shading lit from the upper left, held frames never tweened;
  textures and tiles at 32 px/m in 15-colour material families. Nothing blocky or voxel ships; primitives are blockouts.
- Originality (the breakdown's section 14): never a Square Enix character or game name in a generator prompt or
  style-reference slot (describe the design); never a ripped sprite, tile, map, font, music or line of text, even as
  a base to trace or inpaint over; every generated file logged in `source_art/MANIFEST.csv`.
- Look at every capture before calling a visual done; judge against the catalog image, the bible brief and the
  approved anchor. Combat follows `COMBAT_LAWS_BIBLE.md` (§18.7 acceptance checks); art follows `REFERENCE_BIBLE.md`
  (§1.13, §9.9) as amended by DECISIONS. Headless probes keep printing `PROBE_END ok=true`. Keep `PROGRESS.md`
  honest: verified, untested and broken are three different words.

## Environment notes

- **Nich's Windows PC (the build lead from 2026-10-29):** Git Bash. Godot 4.7.2 is the WinGet console build and
  Windows' `python3` is a Store stub, so put shims on PATH before any check:
  `mkdir -p .tools/bin; printf '#!/usr/bin/env bash\nexec "<path to Godot_v4.7.2-stable_win64_console.exe>" "$@"\n' > .tools/bin/godot; printf '#!/usr/bin/env bash\nexec python "$@"\n' > .tools/bin/python3; chmod +x .tools/bin/*; export PATH="$PWD/.tools/bin:$PATH"`.
  `bash tools/check.sh` then works as written (the smoke boot opens a real window; there is a GPU).
- **Cloud sessions** (Ubuntu, no GPU): `--headless` cannot render; `xvfb-run` captures run at ~2 fps, so keep them
  under ~600 frames. Work on the session branch and open the draft PR (protocol step 2).
- Keep `.godot/`, `.tools/`, builds and temp files out of git; every committed file under 50 MB; exports go to a
  git-ignored `exports/` and are attached to the Slack thread. Never print, log or commit secrets or tokens.
