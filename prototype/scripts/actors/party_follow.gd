class_name PartyFollow
extends Node
## Exploration follow, Chrono-style: party members walk the leader's recent path,
## each `spacing` metres further back along it. Pauses while the coordinator locks
## exploration (combat moves everyone to battle anchors) and re-forms from where
## everyone stands once exploration unlocks, so nobody runs back along the old path.

@export var coordinator: HybridBattleCoordinator
@export var leader_group: StringName = &"party_leader"
@export var party_group: StringName = &"party"
## Metres of the leader's path between consecutive members.
@export var spacing: float = 1.2
## The leader's path is sampled every this many metres.
@export var sample_step: float = 0.2
## A follower only gets a new move order when it is further than this from its spot.
@export var slack: float = 0.3
## When false the follow only advances when step() is called (tests, replays).
@export var auto_follow: bool = true

## Leader path, newest point first.
var trail: Array[Vector3] = []
var locked: bool = false


func _ready() -> void:
	if coordinator:
		coordinator.exploration_lock_changed.connect(_on_exploration_lock_changed)
	reform.call_deferred()


func _physics_process(_delta: float) -> void:
	if auto_follow:
		step()


func leader() -> Node3D:
	return get_tree().get_first_node_in_group(leader_group) as Node3D


## Party members other than the leader, in scene order.
func followers() -> Array[Node3D]:
	var out: Array[Node3D] = []
	var lead := leader()
	for n in get_tree().get_nodes_in_group(party_group):
		if n is Node3D and n != lead:
			out.append(n)
	return out


func step() -> void:
	var lead := leader()
	if locked or lead == null:
		return
	record(lead.global_position)
	var fs := followers()
	for i in fs.size():
		var goal := point_behind(float(i + 1) * spacing)
		var flat := goal - fs[i].global_position
		flat.y = 0.0
		if flat.length() > slack and fs[i].has_method("move_to"):
			fs[i].move_to(goal)


func record(p: Vector3) -> void:
	if trail.is_empty() or trail[0].distance_to(p) >= sample_step:
		trail.push_front(p)
	var keep: int = int(ceil(float(followers().size() + 1) * spacing / sample_step)) + 2
	if trail.size() > keep:
		trail.resize(keep)


## The point `dist` metres back along the trail; the oldest point if the trail is shorter.
func point_behind(dist: float) -> Vector3:
	if trail.is_empty():
		return Vector3.ZERO
	var left := dist
	for i in range(1, trail.size()):
		var seg := trail[i - 1].distance_to(trail[i])
		if seg >= left and seg > 0.0:
			return trail[i - 1].lerp(trail[i], left / seg)
		left -= seg
	return trail[trail.size() - 1]


## Restart the trail from the current line-up: leader first, then each follower.
func reform() -> void:
	trail.clear()
	var lead := leader()
	if lead == null:
		return
	trail.append(lead.global_position)
	for f in followers():
		trail.append(f.global_position)


func _on_exploration_lock_changed(is_locked: bool) -> void:
	locked = is_locked
	if not is_locked:
		reform()
