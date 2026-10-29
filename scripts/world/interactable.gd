## Something the party can talk to or use: a save point, a door, a person, a pot. Runs a story script
## or emits a signal. The prompt frame appears when the leader faces it.
class_name Interactable
extends Area3D

signal used(by: Node)

@export var script_id: StringName = &""
@export var prompt: String = "Talk"
@export var one_shot: bool = false
@export var requires_flag: StringName = &""
@export var requires_state: StringName = &""
@export var blocked_by_flag: StringName = &""
var used_once: bool = false
var callback: Callable = Callable()


func _ready() -> void:
	collision_layer = 8
	collision_mask = 0
	monitoring = false
	set_meta("interactable", self)
	if get_child_count() == 0:
		var cs := CollisionShape3D.new()
		var sphere := SphereShape3D.new()
		sphere.radius = 0.8
		cs.shape = sphere
		add_child(cs)


func can_use() -> bool:
	if one_shot and used_once:
		return false
	if requires_flag != &"":
		if requires_state != &"":
			if not Flags.is_state(requires_flag, requires_state):
				return false
		elif not Flags.has(requires_flag):
			return false
	if blocked_by_flag != &"" and Flags.has(blocked_by_flag):
		return false
	return true


func use(by: Node) -> void:
	if not can_use():
		return
	used_once = true
	used.emit(by)
	if callback.is_valid():
		callback.call(by)
	elif script_id != &"":
		Story.run(script_id)


static func make(parent: Node, name: String, pos: Vector3, script: StringName, prompt_text: String = "Talk", radius: float = 0.8) -> Interactable:
	var i := Interactable.new()
	i.name = name
	i.script_id = script
	i.prompt = prompt_text
	i.position = pos
	var cs := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = radius
	cs.shape = sphere
	i.add_child(cs)
	parent.add_child(i)
	return i
