# TRIGGER: Time Debt — working agreement for agents

You are building the complete game described in `design/` (STORY_BIBLE, COMBAT_LAWS_BIBLE, REFERENCE_BIBLE).
You have full creative authority: build what the bibles describe, invent what they leave open, retune what
plays badly, and write every call down. `README.md` is the map of the project and the how-to for adding
content; this file is how we work.

## Session protocol

1. `cd` into the repository, `git pull --rebase`, read `PROGRESS.md` (then `README.md` if you are new).
   Set `git config user.name "Fable (TRIGGER build agent)"` / `user.email fable-agent@users.noreply.github.com`
   if no user is set.
2. `source tools/setup_godot.sh` (Godot 4.7.2 on PATH; `.tools/` is git-ignored).
3. Take the most valuable next step from `PROGRESS.md`. Build it, run `bash tools/check.sh` (or
   `--no-visual` for data/system work), look at any capture yourself, fix what broke, commit, `git pull --rebase`,
   push to `main`. Then the next step. Never force-push; never skip hooks.
4. Keep `PROGRESS.md` current (what exists and is verified, what is next in priority order, known issues)
   at least hourly and after every milestone. A restarted session has nothing else.
5. Never stop to ask. Decide, record it in `docs/DECISIONS.md` (what, why, which bible section), and if Nich
   should weigh in later add a line to `docs/QUESTIONS_FOR_NICH.md`.
6. Copy the best new captures to `docs/screenshots/` (update its README) and to `/mnt/session/outputs/`.

## Division of labour (do not cross these lines)

- **Build agent (you):** every scene, system, script, test, dialogue, data file and sound; all character
  sprites and animations (playable cast, NPCs, enemies, bosses) through `docs/ART_PIPELINE.md`; everything
  under `scenes/ scripts/ data/ audio/ tests/ tools/ assets/characters assets/npcs assets/enemies assets/bosses`.
- **Studio assistant (another agent, same PixelLab account, REST API):** commits straight to `main` in
  `assets/portraits/`, `assets/ui/generated/`, `assets/textures/generated/`, `assets/vfx/generated/`, each with a
  `manifest.json`. Do not generate those families. Check the folders first and wire in what is there
  (`PortraitCache`, `SceneKit.named`, the UI loaders already look there); write what is missing in
  `docs/REQUESTS_FOR_STUDIO.md` and carry on with a placeholder.
- **Nich:** reviews and picks looks in PixelLab's Character Creator. Name PixelLab characters
  `TRIGGER <Name> vN` and record every id in `data/art/pixellab_characters.json` so picks can be matched.
- PixelLab's 20 concurrent job slots are shared by all three: queue a clip or two, `wait_for_jobs`, continue.

## The hand-off is a deliverable

Nich and other tools (Claude Code, Cursor) must be able to keep building from the repository alone, so:

- `README.md` stays a complete orientation (run, check, add a scene / tech / enemy / boss / dialogue / flag /
  sprite, where each kind of data lives). Update it when you add a system or change a format.
- `docs/` stays tidy: `ART_PIPELINE.md`, `DECISIONS.md`, `QUESTIONS_FOR_NICH.md`, `REQUESTS_FOR_STUDIO.md`,
  `reports/`, `screenshots/`. `PROGRESS.md` lives in the root.
- Systems are generic before they are wide: a mechanic goes into data + a reusable component, not a special
  case in one scene. Make the second instance free.
- Files stay small and well named (scripts under ~600 lines, one class per file, snake_case ids matching the
  manifest), content stays in `data/` JSON, generators and sources stay in `tools/` and `source_art/`.

## Quality bar

- Art: Chrono Trigger hand-pixelled characters (3.5-head proportions, expressive faces, strong silhouettes)
  in Octopath-grade HD-2D dioramas. Nothing blocky, boxy or voxel ships. Primitive rooms and procedural tiles
  are blockouts to be replaced, never polished.
- Look at every capture before calling a visual done. Judge against the catalog image and the bible brief.
- Combat follows `COMBAT_LAWS_BIBLE.md` (§18.7 acceptance checks); art follows `REFERENCE_BIBLE.md`
  (§1.13 and §9.9). Headless probes must keep printing `PROBE_END ok=true`.
- Keep `PROGRESS.md` honest: verified, untested and broken are three different words.

## Environment notes

- Ubuntu 24.04 x86_64, no GPU, up to 8 GB RAM and 10 GB disk. `--headless` cannot render; captures use
  `xvfb-run` with software Vulkan (~2 fps), so keep them under ~600 frames.
- Keep `.godot/`, `.tools/`, builds and `/tmp` out of git; every committed file under 50 MB; builds go to
  `/mnt/session/outputs/`. Never print, log or commit secrets or tokens.
