## The Atrium Siege (Combat Laws §16.3 and acceptance check 25; Story Bible §9.3 `Atrium_Siege` and "Failure
## without Game Over"): when Crono's integrity reaches 0 the Atrium locks and Vaelos lays siege, a playable
## fail-state and never an ending. This first cut is the frame around the three waves (DECISIONS "The Atrium
## Siege, first cut"): once the field is idle (no battle, no script, no transition) the music box tape-stops
## (porcelain_stress already reads 100: Audio follows integrity), the `atrium_siege` dialogue plays when the text
## layer has written it, the cycle records Atrium_Siege +1 (Ending 5 needs one), Sera reglazes Crono to 20 and
## jumps the party to the last Atrium checkpoint (the spawn of the last save made there). Before the Atrium is
## home (the Prologue) there is no such checkpoint and the party stays where the defeat rewind put it. The waves
## (Lavos-spawn, Bekkler failures, Vaelos's 22-plate projection) and the vendor families a lost wave costs wait for
## their encounter data.
class_name AtriumSiege
extends RefCounted

const COUNTER := &"Atrium_Siege"
const HUB := &"atrium"
const SCRIPT_ID := &"atrium_siege"
const REGLAZE_TO := 20.0
const JUMP_FADE_S := 0.8

static var _running: bool = false


## A save made in the Atrium is an Atrium checkpoint (Saves.save calls this before writing).
static func note_checkpoint() -> void:
	if Game.location == HUB:
		Game.atrium_spawn = Game.spawn_point


## Integrity is at the flatline and no siege is under way.
static func owed() -> bool:
	return Game.crono_integrity <= 0.0 and not _running


static func running() -> bool:
	return _running


## Where the siege leaves the party: [location, spawn], or [] to stay (no Atrium checkpoint yet).
static func destination() -> Array:
	if Game.atrium_spawn == &"" or not Router.has_location(HUB):
		return []
	return [HUB, Game.atrium_spawn]


## Run the siege once the field is idle, if it is owed. A Location calls this whenever Game's integrity changes
## outside a battle (a defeat's write-back, a gate toll, a story cost) and as it arrives (a save made while the
## siege was owed holds integrity 0, so its Continue lands at the flatline); one siege runs at a time.
static func begin_if_owed(tree: SceneTree) -> void:
	if not owed():
		return
	_running = true
	await tree.process_frame
	while Story.is_running() or Router.transitioning:
		await tree.process_frame
	Audio.tape_stop()
	if Data.dialogue.has(SCRIPT_ID):
		await Story.run(SCRIPT_ID)
	Flags.add_counter(COUNTER)
	Game.set_integrity(REGLAZE_TO)
	var to: Array = destination()
	if not to.is_empty():
		await Router.go(to[0], to[1], JUMP_FADE_S)
	_running = false
