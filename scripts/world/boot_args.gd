## The roster arguments of a debug start (scenes/boot/boot.gd and the test arena; README "Boot arguments"):
## `--party=a,b,c`, `--level=<n>` and `--chapter=<n>`. They are applied together and in this order, whatever
## their order on the command line, so the probes read the difficulty a real party would bring:
## 1. the party: Game.set_party (a guest such as Marle gets her roster row and her kit's unlocked techs);
## 2. the level: every roster member, the party's guests included, through Game.set_level (level-gated kit
##    entries arrive);
## 3. the chapter: `--chapter=<n>`, else the current one (0, the Prologue, for a fresh boot) when the start goes
##    straight into a location: Game.set_chapter learns the kit entries of that chapter for everyone who can
##    learn. A New Game never takes this path (the Prologue's own `learn` commands teach its kit).
## A debug start also keeps its files apart (suspends_saves): it plays a made-up state, so its autosaves and
## settings go to the scratch directory (Saves.suspended) unless `--save` asks for the player's own files.
class_name BootArgs
extends RefCounted

## The boot arguments that start from a made-up state (scenes/boot/boot.gd's list, --say aside).
const STATE_ARGS: Array[String] = [
	"--scene=", "--location=", "--spawn=", "--checkpoint=", "--party=", "--level=", "--chapter=", "--integrity=", "--flag=",
]


## The run is a debug start (any STATE_ARGS other than a start on the title) and did not pass `--save`.
static func suspends_saves(args: PackedStringArray) -> bool:
	if args.has("--save"):
		return false
	for arg in args:
		if arg == "--scene=title" or arg == "--location=title":
			continue
		for prefix in STATE_ARGS:
			if arg.begins_with(prefix):
				return true
	return false


## {party: Array[StringName] (empty when not given), level: int (0 when not given), chapter: int (-1 when not given)}
static func parse(args: PackedStringArray) -> Dictionary:
	var out: Dictionary = {"party": [] as Array[StringName], "level": 0, "chapter": -1}
	for arg in args:
		if arg.begins_with("--party="):
			var ids: Array[StringName] = []
			for p in arg.trim_prefix("--party=").split(",", false):
				ids.append(StringName(p.strip_edges()))
			out["party"] = ids
		elif arg.begins_with("--level="):
			out["level"] = maxi(1, int(arg.trim_prefix("--level=")))
		elif arg.begins_with("--chapter="):
			out["chapter"] = maxi(0, int(arg.trim_prefix("--chapter=")))
	return out


## Apply the roster arguments of `args`. `into_location`: the start goes straight into a location (not the
## title), so the chapter's kit is learned even without `--chapter`.
static func apply(args: PackedStringArray, into_location: bool) -> void:
	var a: Dictionary = parse(args)
	var party: Array[StringName] = a["party"]
	if not party.is_empty():
		Game.set_party(party)
	var level: int = int(a["level"])
	if level > 0:
		for id in Game.roster.keys():
			Game.set_level(StringName(id), level)
	var chapter: int = int(a["chapter"])
	if chapter >= 0 or into_location:
		Game.set_chapter(chapter if chapter >= 0 else Game.chapter)
