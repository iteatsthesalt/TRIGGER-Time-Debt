# Enemy codex, bosses and encounters — data-entry report

## Files written (only data/enemies, data/bosses, data/encounters touched; u0 untouched; no git run)

Enemies (71 new entries, 82 total with U0):
- data/enemies/u1/u1_enemies.json — 8 (E31 ashen_ashigaru, E05 porcelain_captain, E32 ink_calligrapher, E33 gourd_bloated_heimin, E34 surrender_petition_yokai, E35 crimson_banner_samurai, E06 omen_crow, E08 imp_crackle_sumi)
- data/enemies/u2/u2_enemies.json — 9 (E36 slag_mite, E02 cassia_pattern_patrol_unit, E37 bike_bros, E38 porcelain_choir, E09 porcelain_knight_squire, E10 mercury_leaker, E39 press_golem, E11 loom_bracer_rook [elite], E40 marrow_umbilical)
- data/enemies/u3/u3_enemies.json — 10 (E41 nestling, E45 moon_egg, E15 eden_wisp, E13 bramble_rex_saurian, E42 gene_scribe, E43 synod_acolyte, E16 porcelain_raptor, E14 unfallen_pupa, E44 crown_saurian, E46 lichen_colony)
- data/enemies/u4/u4_enemies.json — 12 (E52 glass_mnemos, E47 vitrified_choir, E18 cathedral_choir_jelly, E49 jellyfish_lantern, E54 anemone_scribe, E53 zealot_chandelier, E48 lead_lector, E19 ruin_eel, E20 enlightened_zealian, E55 vaelos_siphon_tubule, E21 mammon_conduit, E50 mammon_siphon_tendril [elite])
- data/enemies/u5/u5_enemies.json — 9 (E56 ash_cotton_swirl, E61 popcorn_husk, E62 charred_juggler, E57 strongman_dummy, E63 time_smoke_stringer, E58 ticket_golem_barker, E64 laugh_track_choir, E59 heckler_harlequin, E60 jester_box [elite])
- data/enemies/u6/u6_enemies.json — 6 (E65 slag_rat_courier, E66 ram_fixer_twins, E67 pachinko_ice [miniboss], E68 white_ear_child_echo, E69 oil_fire_bike_bro, E70 hiss_larva_drone)
- data/enemies/u7/u7_enemies.json — 6 (E75 marrow_lantern, E71 washi_hollow_monk, E72 vertebray, E72_fawn vertebray_fawn [added so split_on_half has a key], E73 ink_eater, E74 kirie_keeper [miniboss])
- data/enemies/u8/u8_enemies.json — 4 (E76 atom_eater, E77 bekkler_doll_failed, E78 lavic_filament_guardian, E79 paradox_curator_choir)
- data/enemies/u9/postgame_enemies.json — 7 (E80 marrow_umbilical_twin, E81 memory_of_stirring, E82 cronos_denial, E83 seras_first_slip, E84 ledger_wisp, E85 arris_echo, E85_sleeping arris_echo_sleeping [the Sleeping-route variant the row describes])

Bosses (31 files, data/bosses/<id>.json): atrium_cradle, shard_doll_999, krona_duel, shogun_memory_flame, goyama_ashen_daimyo, weeping_shogun, porcelain_weaver, r66y, mycelia_matriarch, azar, arch_curator_echo, schala_shadow_weaver, leviathan_low_tide, glass_matriarch, ash_ringmaster (kind miniboss), cyrus, isolator, kami_ori, omega_final_dojo, vaelos, guardian_triad, empress_vaelos, vaelos_child_lullaby, chrono_ledger, cronos_reflection, bloom_matriarch, cyrus_encore, omega_final_void, cassia_forge_tendril, ash_loom_marionette, r66y_residual_sorrow.

Encounters: data/encounters/u1.json … u8.json — 8/8/8/8/8/8/8/6 groups (62 new, 71 total). Story groups included: iron_bridge_shrine_1–4 (Crimson Banner Samurai), spine_highway_bike_bros, arris_dome_porcelain_choir, mycelia_floor_nestlings, nave_jellyfish_lanterns, puppet_stage_* (strongman/barker/laugh_track/full_bill), laundry_wires_ram_fixers, root_approach_monks, navel_string_atom_eaters, plus kirie_keeper_shrine_1–3, neon_bloom_pachinko_ice, canopy_lichen_colony (×3 bodies). Music is "mus_battle_core_u<n>" as instructed (note: data/universes/universes.json lists U6 battle music as mus_u6_neo_truce_action and U8 as mus_u8_boss_vaelos — pick one convention).

## Validation
- python3 tools/build/lint_data.py → "123 techs, 82 enemies, 11 characters, 80 flags, 71 encounters, 9 scripts", zero errors.
- godot --headless parse_all.gd → PARSE_ALL: 0 scripts failed; grep for WARNING: Data|unknown|duplicate|encounter → nothing.
- Extra headless check: Data autoload reports enemies=82 bosses=31 encounters=71 errors=0; every boss JSON loads with python json.load.
- tests/run_tests.gd → 302 passed, 0 failed.
- A script cross-checked every codex row (level, shield, tags, weak, resist/nullify/immune/absorb, lean) against my JSON by E-number: all match except the deliberate E58 case below. All sprite ids exist in REFERENCE_BIBLE §11.4/11.5/11.1; all boss flag names/states exist in data/flags; all add/summon keys resolve.
- Note: commit 8c42265 (not mine) already contains the enemies, encounters and 13 of the boss files; `git diff` shows the committed copies are identical to my working files. The other 18 boss files are untracked and need committing.

## Schema notes
- Enemies use exactly the u0 keys, plus two loader-known keys where they encode a rule precisely: `break_effect: "spawn_ash_field"` (Gourd-Bloated Heimin) and `spd_mult: 0.85` (Press Golem heavy drift). Nothing in the coordinator consumes either yet.
- Statuses used beyond the given list, because StatusComponent already defines them: `ink_dot` (Calligrapher, Weeping Shogun), `ink_blot` (Ink-Eater, BLIND 60%), `magnetized` (Press Golem, Chrono Ledger), `rubber_chicken` (Jester Box, gauge 0.6×). Effects used beyond the list: `oil_blight` (Ruin Eel, R-66Y, Glass Matriarch — already handled in TechEffects.apply_enemy_effect). `summon:<key>` targets: ashen_ashigaru, porcelain_shardling, porcelain_knight_squire, porcelain_raptor, cathedral_choir_jelly, washi_hollow_monk, atom_eater, lavic_filament_guardian, crono_porcelain_hollow, leg_mechanism (last two are inline adds).
- Boss files follow the given schema with additive keys where the bible needed them: phase `advance_on` ("break" | "branch" | "threads_cut" | "arm_broken" | "adds_defeated" | "scripted" | …) for phases not gated by HP; `requires` on secret phases and gated actions; `shield_by_branch` / `hp_from_by_branch` (R-66Y Phase 3, Vaelos Phase 2 +4 if Rejected); `stacked_shields` lists (Vaelos Final Kintsugi 45×3, Chrono Ledger 36/24 and 54/36/18, Omega Doll 35×2); `untargetable`, `true_null`, `fake_weaknesses_on_null`, `resist_all`, `plate_material`, `shaved_only_by`, `start_at`, `carry_shield`, `never_breaks`, `regen_pct_per_s`/`regen_delay_s`, `objective: "protect"`, `level_band`; `lean` on branch options with no named flag; `reads_flags`; adds carry `def` (inline definitions for adds that have no codex row), `trigger`, `respawn_s`, and `shield`/`level` overrides (Cyrus's puppets at 4 plates).
- Two-Break shields ("Break at 10 and at 0", "14 × 2", "35 × 2") are written as shield N with `refill_once: true`, which is exactly two stacked Breaks in ShieldComponent terms.
- Arch-Curator Echo's "[ASTRAL] only below 40%" is written as two phases sharing one 18-plate shield (`carry_shield: true` on the second).

## Mechanics encoded only as notes/mechanics ids (schema cannot express them)
Enemies:
- Ashen Ashigaru: repaint cancelled once a FIRE hit has landed.
- Surrender Petition Yokai: evades everything while unpainted; INK/Cobalt Wash paints it.
- Omen Crow circling out of reach; Imp-Crackle death paint (enemies half speed 10 s); Heimin Krona dialogue.
- Cassia-Pattern Patrol: Mercury Pulse only slows allies standing in an amber-shard radius.
- Bike Bros / Heckler sine drift (effect drift_fast is a placeholder); Break-lock pins mid-skid.
- Porcelain Choir mercy/ruthless outcomes (Arris_Dome flag, −4 R-66Y plates, early Syringe Heart Key).
- Squire shield-wall blocking; Press Golem "adjacent allies build no BP", conveyor reversal, Break mercury pool; Loom-Bracer Rook's pull-into-Break-locked-body reposition.
- Marrow-Umbilical / Eden Wisp / Synod Acolyte / Siphon Tubule / RAM Fixer / Marrow Twin heals are battle-time timers (2 per 8 s, 2 per 6 s, 4 per 15 s, 1 per 8 s); the heal_ally_plates actions are turn-based stand-ins. Umbilical severing cost (15% ceiling) and Twin "same Sync window" rule.
- Nestling steals 1 Shared orb per attack; feather map drop.
- Moon Egg: single hit after Break shatters it into Sunlight ×3 / hatch-later Light.
- Gene Scribe FAILED floor field + Divinity regeneration + self-Silence 15 s on Break.
- Porcelain Raptor cloak (effect cloak needs uncloak by Mercury Pulse/Tether/Static field).
- Unfallen Pupa and Marrow Lantern passivity until provoked/lit; Pupa unprovoked kill closes Golden Light.
- Crown Saurian immune while airborne until Tether snap.
- Lichen Colony 15% shared damage (shared_group written as instructed, but the bible shares damage, not plates; 6 plates per body); Fake Carrier Burn.
- Vitrified Choir hymn stuns only polishers; 2× damage under Sera's HOLD. Jellyfish Lantern air/crush effects. Lead Lector lead barriers. Enlightened Zealian talks at Light ≥ 90. Mammon Siphon Tendril: ASTRAL counts only for Crono, VITREOUS only for a Rose-focused beam; 28 Hz ring.
- Ticket-Golem Barker: "6 + 1 keyed [TICKET]→[FERRO]" written as 7 flat plates (component cannot mix flat and keyed); forced auto-spend of 1 BP; +1 BP rain on Break if Glenn dishonest.
- Strongman Dummy: Punchline once on spawn; BLUNT at full inflation deflates it. Time-Smoke Stringer sword hits count as thread cuts. Charred Juggler second weakness hidden until VITREOUS. Heckler: honest-GUILE-only weakness, 10 s steal timer, 15 s invulnerability until Rewind Reel. Jester Box springs_cut condition needs three spring sub-targets. Laugh-Track Choir silenced by MYCELIA.
- Pachinko ICE rotating RUIN/FERRO third weakness every 6 s. White-Ear Child Echo untargetable unless Static tuned SIGNAL / visible only while BLIND. Hiss Larva +1 plate/s within 6 m of a TV; circles erased only by NOISE.
- Washi-Hollow Monk flip/asanoha-mark rule. Vertebray sheds fawns once (split_on_half must fire once). Ink-Eater spread + 12 s Ink Blot. Kirie Keeper: monks' shared 10-plate shield must Break before the Keeper can be shaved (break_condition only gates the Break, so not used), summon once at start.
- Lavic Filament Guardian: anchor severed only by LINE_PIERCE; summon tied to shield rebuild while anchored; Break body as platform. Bekkler Doll Failed heartbeat cue. Paradox Choir ring at 0.5× speed.
- Sera's First Slip: first-damage 5% Crono ceiling cost once; Light ≥ 90 light puddle; 4/3/3 keyed split is my inference. Ledger Wisp Regret Tick (+5% Camp Strain per lingering turn). Arris Echo Sleeping sleeps on Break.
Bosses (highlights; each file's `mechanics` and `notes` carry the full prose):
- "A hit carrying both X and Y" weaknesses (Goyama P4, Schala P3, Cyrus P3 Duo) — weak lists cannot express conjunction.
- Conditional weaknesses: Empress P1 only during Worship Gaze; Vaelos P3 only while Sera is phased out; Dragon bout cycling FIRE/ICE/VOLT every 6 s; NULL-created fake weaknesses (Kami-Ori, Empress, Omega).
- Untargetable bars and sub-targets: Cyrus/Ash-Loom Phase 1 threads, Cyrus Strings, Weaver's amber tank (0 damage, 0 shave, costs Lucca dialogue), Forge Tendril until both Twins Break-locked, Kami-Ori arms, Empress throne arms removing actions, R-66Y Residual mask knock-offs (−3000 each) and the 10 real plates inside 999.
- Timer rules: R-66Y barrel glow 1.5 s / umbilical heal / Ringmaster whip every 10 s / Omega ERASE WEAKNESS every 8 s / Cronos Reflection heal if no plate Broken in 12 s / Porcelain Silence stand-still 12 s.
- Custom regen rates (Vaelos Final Kintsugi 22%/s after 2 s), Black Oil Armor (every shave −1), all-tags-resisted ledger, Schala Polished +25% shield, Kirie Gale stripping temporary plates, Sera Voluntary_40 detection (Sync Hold 99.0 held 3 s), Lavic Filial Field / Time Debt Well, Robo Heart protect objective, Bloom Matriarch negotiation shaving (Tether pulses, proof flags, Listen).

## Uncertainties / judgement calls to confirm
1. Shogun's Memory Flame (E07) is a boss file only, not also a u1 enemy row (it has Shield/Weak columns but is a §14 pointer). Same for E12/E17/E22/E51.
2. 999 Shard Doll Phase 1: the bible says "teaches pairing sword and fire" but names the hidden weakness [FERRO]; I kept the literal [SWORD][FERRO]. Phases 3–4 weaknesses are not restated; I carried earlier ones. Base tags inferred.
3. Vaelos Child keyed plates transcribed literally: P1 and P2 keys sum to 5 shave against a stated 6 plates (P3 sums to 6); noted in each phase.
4. Chrono Ledger P1: plate line [SWORD][FERRO][?=AURA] vs Weak [SWORD][ASTRAL] conflict; plate line kept as tags, Weak column as weaknesses.
5. Boss tags not given in the bible were inferred and marked "inferred" in notes: Atrium Cradle, 999 Doll, Goyama, Porcelain Weaver, Mycelia Matriarch, Leviathan, Glass Matriarch, Isolator, Kami-Ori, Chrono Ledger. HP windows not given were split evenly (Cradle, Krona duel, Goyama, Schala, Glass Matriarch, Kami-Ori P2–3). Levels not given for ending bosses: guardian_triad 82, vaelos_child_lullaby 80, chrono_ledger 90 (per-phase level_band kept), cronos_reflection 85, bloom_matriarch 85, cyrus_encore 85, omega_final_void 90.
6. Flag mappings that are assumptions: Azar's Archive bargain → Moon_Memory Kept/Sacrificed; Forge Tendril → Seed_of_Doan Grown; Ash-Loom Marionette's conditional third phase and Glenn_Threads/Glenn_Arm branches come from the Story Bible, not the Combat Laws.
7. Flags the bible names that do not exist in data/flags (kept as notes only): Vaelos_Returned, Atrium_Rebuilt_Gold, Sera_Teaches_Fall, Nine_In_One_Watercolor, MYCELIA_GLOBAL_POOL_OPEN, the Empress "Sera becomes Warden" choice, Marle's Queen Sacrifice. Memory Flame and Mycelia Matriarch outcomes have no flag, so their branch options carry a `lean` instead.
8. Keys: parentheticals dropped and "A — B" names keyed on B as instructed (porcelain_captain, press_golem, jester_box, memory_of_stirring, cronos_denial, seras_first_slip). ram_fixer_twins is one twin per entry (encounters list it twice). Drop item ids (ferro_capacitor, prop_hammer, batteries, conductivity_gel, red_bike_chain, charred_laurel_fragment, kirie_scales ×13, gold_bundle, gold_leaf_flake, gramophone_record_crono_lullaby, time_atom) are not yet in data/items/items.json except time_atom.
9. Post-game enemies carry universe 9 but each keeps the fps of the canvas it renders in (U0 60, U1 24, U2 12). No u9 encounters were written (not requested).
