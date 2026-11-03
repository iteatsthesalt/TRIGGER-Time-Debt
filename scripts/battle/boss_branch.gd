## The Possibility Branch (Combat Laws Bible §14.1): a phase gated `advance_on: "branch"` freezes the timeline and
## asks the boss file's branch question, the `branches` entry whose `after_phase` is the phase before it. Each
## option {id, label, flag?, state?, lean?} writes its flag the moment it is chosen; the entry's optional
## `prompt` is the line the box shows (its `notes` are design notes and never shown). The bible wants the choice
## made in-world, by an action; a director that stages it so returns {"handled": true} from on_branch and calls
## BossController.answer_branch(option_id) itself. Without one the question is asked through the dialogue box.
class_name BossBranch
extends RefCounted


## The branch entry phase i asks, or {}.
static func entry_for(boss: BossDef, i: int) -> Dictionary:
	var before: String = String(boss.phase(i - 1).get("id", ""))
	var here: String = String(boss.phase(i).get("id", ""))
	for b in boss.branches:
		if b is Dictionary and (String(b.get("after_phase", "")) == before or String(b.get("after_phase", "")) == here):
			return b
	return {}


## The dialogue-box form of the question: one choice whose options carry their flag.
static func script_for(entry: Dictionary, prompt: String) -> Array:
	var options: Array = []
	for o in entry.get("options", []):
		var opt: Dictionary = {"text": String(o.get("label", o.get("id", "..."))), "branch_option": String(o.get("id", ""))}
		options.append(opt)
	return [{"choice": options, "prompt": prompt}, {"end": true}]


## Write what option `id` of `entry` sets: its flag (option_ref) and, with no flag, its lean.
static func apply(entry: Dictionary, id: String, universe: int) -> Dictionary:
	for o in entry.get("options", []):
		if String(o.get("id", "")) != id:
			continue
		var flag: String = String(o.get("flag", ""))
		var ref: String = option_ref(o)
		if ref != "":
			Flags.set_ref(ref)
		var lean: String = String(o.get("lean", ""))
		if flag == "" and lean != "":
			Flags.add_lean(universe, lean.left(1).to_upper())
		return o
	return {}


## The flag reference an option writes: its `flag` with its `state` ("set" when it names none, FlagRef.written);
## "" for an option with no flag (a lean, or nothing). Data.load_all and lint_data.py validate it.
static func option_ref(o: Dictionary) -> String:
	var flag: String = String(o.get("flag", ""))
	if flag.strip_edges() == "":
		return ""
	var p: PackedStringArray = FlagRef.with_state(flag, String(o.get("state", "")))
	return FlagRef.written("%s:%s" % [p[0], p[1]] if p[1] != "" else p[0])


## Ask the question with the clock frozen (the coordinator in State.BRANCH when it was ticking) and return the
## chosen option's id ("" when the entry has no options).
static func ask(ctrl: BossController, entry: Dictionary) -> String:
	var options: Array = entry.get("options", [])
	if options.is_empty():
		return ""
	var c: BattleCoordinator = ctrl.coordinator
	var frozen: bool = c.state == BattleCoordinator.State.TICK
	if frozen:
		c.open_branch(StringName(String(entry.get("id", ""))), options, Callable())
	var picked: Dictionary = {"id": String(options[0].get("id", ""))}
	var grab := func(_i: int, option: Dictionary) -> void:
		if option.has("branch_option"):
			picked["id"] = String(option["branch_option"])
	Story.choice_made.connect(grab)
	await Story.run(StringName("branch_%s" % String(entry.get("id", ""))), script_for(entry, String(entry.get("prompt", "The timeline freezes. Every gauge waits."))))
	Story.choice_made.disconnect(grab)
	if frozen:
		c.choose_branch(StringName(String(picked["id"])))
	return String(picked["id"])
