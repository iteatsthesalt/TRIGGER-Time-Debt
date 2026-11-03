## Chapter dialogue data: the dialogue check (DialogueCheck, run by Data.load_all), Chapter 2's lost fights jumping
## back to before the battle (Combat Laws 16.1) except the scripted duel, its cue ids, and the last save of the
## chapter landing after the interlude and the `go`.
extends "res://tests/suite_base.gd"

const ROUTER := preload("res://scripts/autoload/scene_router.gd")
const RETRY_FIGHTS: Array[StringName] = [&"ch2_bridge_1", &"ch2_bridge_2", &"ch2_bridge_3", &"ch2_bridge_4", &"ch2_daimyo_sequence", &"ch2_furnace_sequence"]

var _battles: int = 0
var _results: Array = []


func _refs() -> Dictionary:
	return {"flags": Data.flags, "script_flags": Data.script_flags, "items": Data.items, "encounters": Data.encounters,
		"bosses": Data.bosses, "techs": Data.techs, "characters": Data.characters, "locations": ROUTER.DEFAULT_LOCATIONS}


func _has_line(lines: PackedStringArray, needle: String) -> bool:
	for l in lines:
		if l.contains(needle):
			return true
	return false


func _index_of(cmds: Array, key: String, value: Variant = null) -> int:
	for i in cmds.size():
		var c: Dictionary = cmds[i]
		if c.has(key) and (value == null or c[key] == value):
			return i
	return -1


func _label_index(cmds: Array, label: String) -> int:
	return _index_of(cmds, "label", label)


# ---------------------------------------------------------------- the check over the shipped data

func test_shipped_dialogue_validates_clean() -> void:
	var r: Dictionary = DialogueCheck.validate(Data.dialogue, _refs())
	var errs: PackedStringArray = r["errors"]
	check(errs.is_empty(), "every dialogue command names things that exist: %s" % "; ".join(errs))
	check(not _has_line(Data.errors, "dialogue"), "Data.load_all reports no dialogue problem: %s" % "; ".join(Data.errors))
	check(_has_line(Data.dialogue_warnings, "go ossuary_arrival is scheduled"), "the Chapter 3 hand-off is a scheduled location, warned until its scene is built")
	check(_has_line(Data.dialogue_warnings, "music mus_u1_boss_daimyo"), "a Reference Bible track without its file yet is a warning")
	check_eq(String(Data.dialogue_files.get(&"ch2_duel_sequence", "")), "chapter2.json", "Data remembers which file defines each script")


func test_chapter2_cues_resolve() -> void:
	var sfx: Array[String] = []
	var music: Dictionary = {}
	for sid in Data.dialogue.keys():
		if Data.dialogue_files.get(sid, "") != "chapter2.json":
			continue
		for c in Data.dialogue[sid]:
			if (c as Dictionary).has("sfx"):
				sfx.append(String(c["sfx"]))
			if (c as Dictionary).has("music") and String(c["music"]) != "stop":
				music[String(c["music"])] = true
	check(sfx.size() >= 9, "Chapter 2 plays its sound cues (%d)" % sfx.size())
	for id in sfx:
		check(id.contains("/") and DialogueCheck.sfx_exists(id), "Chapter 2 cue %s is a <family>/<name> file AudioDirector finds" % id)
	check(DialogueCheck.music_exists("mus_sera_theme") and music.has("mus_sera_theme"), "the Furnace approach plays Sera's theme, which has stems")
	for id in ["mus_boss_goyama_daimyo", "mus_boss_weeping_shogun", "mus_u1_furnace_approach", "mus_interlude_ash_kitchen"]:
		check(not music.has(id), "the unscheduled id %s is gone" % id)
	for id in ["mus_u1_boss_daimyo", "mus_u1_boss_weeping_shogun", "mus_sera_interlude"]:
		check(music.has(id), "Chapter 2 names the Reference Bible 8.5 track %s" % id)


## Code health F8: one list of music stems (AudioDirector.MUSIC_STEMS), read by play_music and DialogueCheck (and
## lint_data.py), so every track shipped as stems is one music_exists finds: none plays only unlisted stems.
func test_every_shipped_stem_track_plays_through_the_one_stem_list() -> void:
	check(DialogueCheck.AUDIO.MUSIC_STEMS == Audio.MUSIC_STEMS, "DialogueCheck reads AudioDirector's own list")
	var tracks: Dictionary = {}
	for f in DirAccess.get_files_at(DialogueCheck.MUSIC_DIR):
		if f.ends_with(".ogg") and f.contains("__"):
			tracks[f.get_slice("__", 0)] = true
	check(tracks.size() >= 5, "the stem tracks were found (%d)" % tracks.size())
	for id in tracks.keys():
		check(DialogueCheck.music_exists(String(id)), "%s has a stem play_music loads" % id)
	check(not DialogueCheck.music_exists("mus_zz_none"), "an id with no file is not music")


func test_router_registers_the_chapter3_arrival() -> void:
	check(Router.locations.has(&"ossuary_arrival"), "the Router registers ossuary_arrival (scheduled)")
	check(not Router.has_location(&"ossuary_arrival"), "and refuses it until the scene is built")
	for id in ROUTER.DEFAULT_LOCATIONS.keys():
		check_eq(Router.locations.get(id, ""), ROUTER.DEFAULT_LOCATIONS[id], "the Router starts from DEFAULT_LOCATIONS (%s)" % id)


func test_script_local_flags_are_declared_not_defined() -> void:
	for id in [&"Ch1_Arrived", &"Ch1_Fair_Left", &"Dummy_Wrist", &"Crono_First_Lie", &"Prologue_Courtyard_Done"]:
		check(Data.script_flags.has(id), "%s is a declared script-local marker" % id)
		check(not Data.flags.has(id), "%s is not a codex flag" % id)
	check((Data.script_flags[&"Dummy_Wrist"] as Array).has("Seen"), "a marker lists its states")


# ---------------------------------------------------------------- the check catches each mistake

func test_check_reports_each_mistake() -> void:
	var bad: Dictionary = {
		&"t_bad": [
			{"set_flag": "Prologue_Fal:Teach_Her_To_Land"},
			{"set_flag": "Dummy_Wrist:Peeked"},
			{"set": {"flag": "Prologue_Fall", "state": "Nope"}},
			{"if": {"flag": "Not_A_Flag"}, "then": "won", "else": "won"},
			{"choice": [{"text": "x", "goto": "nowhere_label", "set": {"flag": "Prologue_Fall", "state": "Nope2"}}]},
			{"sfx": "sfx_time_rewind"},
			{"music": "mus_typo_track"},
			{"give_item": "no_such_item"},
			{"relic": "no_such_relic"},
			{"go": "no_such_place"},
			{"sera_state": "floating"},
			{"run": "no_such_script"},
			{"recruit": "nobody"},
			{"party": ["crono", "ghost"]},
			{"learn": "no_such_tech"},
			{"battle": "no_such_encounter"},
			{"battle": "", "boss_id": "no_such_boss", "on_win": "won", "on_lose": "lost_typo"},
			{"label": "won"},
		],
	}
	var r: Dictionary = DialogueCheck.validate(bad, _refs())
	var errs: PackedStringArray = r["errors"]
	var expect: Array[String] = [
		"flag Prologue_Fal is neither", "script-local flag Dummy_Wrist has no state Peeked", "Prologue_Fall has no state Nope",
		"flag Not_A_Flag is neither", "missing label nowhere_label", "Nope2", "sfx sfx_time_rewind has no file",
		"give_item no_such_item", "relic no_such_relic", "go no_such_place is not a Router location", "sera_state floating",
		"run no_such_script", "nobody is not a character", "ghost is not a character", "learn no_such_tech",
		"battle no_such_encounter", "boss_id no_such_boss", "on_lose jumps to a missing label lost_typo",
	]
	for e in expect:
		check(_has_line(errs, e), "the check reports: %s (got %s)" % [e, "; ".join(errs)])
	check(_has_line(r["warnings"], "music mus_typo_track"), "a music id without a track is a warning at run time (lint tells scheduled from typo)")
	check(not _has_line(errs, "crono is not"), "a real character passes")


func test_check_accepts_good_commands() -> void:
	var good: Dictionary = {
		&"t_good": [
			{"set_flag": "Prologue_Fall:Teach_Her_To_Land"},
			{"set": {"flag": "Dummy_Wrist", "state": "Seen"}},
			{"if": {"flag": "Prologue_Fall", "state": "Teach_Her_To_Land"}, "then": "a", "else": "a"},
			{"label": "a"},
			{"if": {"not_flag": "Ch1_Arrived"}, "then": "b"},
			{"label": "b"},
			{"sfx": "time/rewind"},
			{"sfx": "footsteps/u1_woodblock"},
			{"music": "stop"},
			{"sera_state": "hover_support"},
			{"go": "atrium", "spawn": "start"},
			{"end": true},
		],
	}
	var r: Dictionary = DialogueCheck.validate(good, _refs())
	check((r["errors"] as PackedStringArray).is_empty(), "well-formed commands pass: %s" % "; ".join(r["errors"]))
	var sched: Dictionary = DialogueCheck.validate({&"t_sched": [{"go": "leene_square"}]}, _refs())
	check((sched["errors"] as PackedStringArray).is_empty(), "a registered location is no error")
	check(_has_line(sched["warnings"], "go leene_square is scheduled"), "but an unbuilt one is warned")


func test_merge_reports_a_script_defined_twice() -> void:
	var into: Dictionary = {}
	var origin: Dictionary = {}
	check(DialogueCheck.merge(into, origin, "a.json", {"s1": [{"end": true}], "s2": []}).is_empty(), "first definitions merge")
	var errs: PackedStringArray = DialogueCheck.merge(into, origin, "b.json", {"s2": [{"end": true}]})
	check(_has_line(errs, "script s2 is defined in a.json and again in b.json"), "a second file defining s2 is an error: %s" % "; ".join(errs))
	check_eq(origin.get(&"s2", ""), "b.json", "the later definition is the one kept (and reported)")


# ---------------------------------------------------------------- Chapter 2's lost fights

## From the battle's on_lose label, follow the script: the jump back must land on a label before the battle, and
## the victory label must never be reached on the way.
func test_chapter2_losses_jump_back_to_the_fight() -> void:
	for sid in RETRY_FIGHTS:
		var cmds: Array = Data.dialogue_script(sid)
		var b: int = _index_of(cmds, "battle")
		check(b >= 0, "%s has its battle" % sid)
		if b < 0:
			continue
		var battle: Dictionary = cmds[b]
		var lost: int = _label_index(cmds, String(battle.get("on_lose", "")))
		check(lost > b, "%s has its lost label after the battle" % sid)
		var back: int = -1
		var debt: float = 0.0
		for i in range(lost + 1, cmds.size()):
			var c: Dictionary = cmds[i]
			debt += float(c.get("debt", 0.0))
			check(not c.has("run"), "%s: a loss plays no victory script (%s)" % [sid, c])
			if c.has("label"):
				check(String(c["label"]) != String(battle.get("on_win", "")), "%s: a loss never falls into the win label" % sid)
			if c.has("goto"):
				back = _label_index(cmds, String(c["goto"]))
				break
		check(back >= 0 and back < b, "%s: the loss jumps back to before the battle (label at %d, battle at %d)" % [sid, back, b])
		check_eq(debt, 5.0, "%s: Sera's jump back costs her 5 Debt" % sid)
	# the duel is the scripted exception (Story Bible 2.1): Sera rewinds the killing stroke and the duel ends
	var duel: Array = Data.dialogue_script(&"ch2_duel_sequence")
	var lost_d: int = _label_index(duel, "lost")
	check(lost_d > 0 and _index_of(duel, "goto", "won") > lost_d, "the lost duel still goes on to ch2_duel_end")


func _on_battle(_id: StringName, _cmd: Dictionary) -> void:
	_battles += 1
	var victory: bool = _results.pop_front() if not _results.is_empty() else true
	Story.report_battle_result.call_deferred({"victory": victory})


## Played: the first bridge lost once, then won. The battle is asked for twice, the loss costs 5 Debt, and the
## bridge ends with its save.
func test_bridge_loss_retries_the_battle() -> void:
	Game.new_game()
	Story.auto_advance_s = 0.01
	Story.auto_choice = 0
	Story.skip_waits = true
	_battles = 0
	_results = [false, true]
	Story.battle_requested.connect(_on_battle)
	var debt0: float = Game.sera_debt
	await Story.run(&"ch2_bridge_1")
	Story.battle_requested.disconnect(_on_battle)
	check_eq(_battles, 2, "a lost bridge fight is fought again")
	check_near(Game.sera_debt - debt0, 5.0, 0.01, "the jump back cost Sera 5 Debt")
	check_eq(Game.checkpoint, &"ch2_bridge_1", "the bridge's checkpoint stands")
	check(not Story.is_running(), "the script ends after the win")
	Story.auto_advance_s = -1.0
	Story.auto_choice = -1
	Story.skip_waits = false
	Game.new_game()


# ---------------------------------------------------------------- the end of Chapter 2

func test_furnace_won_saves_after_the_interlude_and_the_go() -> void:
	var cmds: Array = Data.dialogue_script(&"ch2_furnace_won")
	var interlude: int = _index_of(cmds, "run", "ch2_interlude_day1")
	var go: int = _index_of(cmds, "go")
	var save: int = _index_of(cmds, "save")
	var cp: int = _index_of(cmds, "checkpoint")
	check(interlude >= 0 and save > interlude, "the save comes after the interlude, so its Debt and spoon lessons persist")
	check(go >= 0 and save > go, "the save follows the go, so it records the location the party arrived in")
	check(go >= 0 and (cmds[go] as Dictionary).get("end_after", true) == false, "the go leaves the script running for the save")
	check(cp >= 0 and cp < save, "the checkpoint is set before the save")
	check(_index_of(cmds, "chapter") < save, "Chapter 3 is recorded before the save")
