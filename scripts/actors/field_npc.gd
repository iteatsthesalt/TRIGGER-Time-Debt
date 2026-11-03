## A non-combatant on the field: a billboard sprite on a body with the same cutscene verbs as a
## CombatActor (walk_to, face, play_anim, emote) and an optional idle wander.
class_name FieldNPC
extends CharacterBody3D

## A walk ended (arrived, or resolved where the NPC stands: ScriptedWalk).
signal arrived

const ARRIVE_M := 0.15

var sprite: ActorSprite
var npc_id: StringName = &""
var wander_radius: float = 0.0
var wander_speed: float = 1.6
var frozen: bool = false
var home: Vector3
var _walk: ScriptedWalk = null
var _wandering: bool = false
var _wait: float = 0.0
var _rng := RandomNumberGenerator.new()
var _bubble: Label3D


static func make(id: StringName, sprite_id: String, fps: float = 0.0) -> FieldNPC:
	var n := FieldNPC.new()
	n.name = String(id)
	n.npc_id = id
	n.collision_layer = 1
	n.collision_mask = 1
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = 1.6
	cs.shape = cap
	cs.position = Vector3(0, 0.8, 0)
	n.add_child(cs)
	n.sprite = ActorSprite.new()
	n.sprite.name = "Sprite"
	n.add_child(n.sprite)
	SpriteLibrary.apply(n.sprite, sprite_id, fps)
	n._rng.seed = hash(String(id))
	return n


func _ready() -> void:
	home = global_position
	_wait = _rng.randf_range(1.0, 4.0)


func _physics_process(delta: float) -> void:
	if _walk != null:
		var v: Vector3 = _walk.step(global_position, delta)  # a frozen NPC makes no headway and resolves
		if _walk.done():
			_end_walk()
		elif not frozen:
			velocity = v
			move_and_slide()
			sprite.update_from_velocity(velocity)
		return
	if frozen:
		return
	if wander_radius > 0.0 and not Story.is_running():
		_wait -= delta
		if _wait <= 0.0:
			var ang: float = _rng.randf_range(0.0, TAU)
			var r: float = _rng.randf_range(0.3, wander_radius)
			walk_to(home + Vector3(cos(ang) * r, 0.0, sin(ang) * r), wander_speed)
			_wandering = true
			_wait = _rng.randf_range(2.0, 6.0)


## Scripted walk (Story `move`). Awaitable, and it always resolves: on arrival, or where the NPC stands once it
## stops making headway (blocked, frozen) or runs out of time (ScriptedWalk).
func walk_to(target: Vector3, speed: float = 2.5) -> void:
	_walk = ScriptedWalk.new(global_position, target, speed, ARRIVE_M)
	_wandering = false
	await arrived


func is_walking() -> bool:
	return _walk != null


func _end_walk() -> void:
	if _walk.result != ScriptedWalk.ARRIVED and not _wandering:
		push_warning("%s: walk to %s %s at %s" % [name, str(_walk.target), _walk.result, str(global_position)])
	_walk = null
	_wandering = false
	velocity = Vector3.ZERO
	sprite.update_from_velocity(Vector3.ZERO)
	arrived.emit()


func face(dir: String) -> void:
	sprite.set_facing(StringName(dir))


func face_toward(p: Vector3) -> void:
	sprite.face_vector(p - global_position)


func play_anim(name: String, return_to: String = "idle") -> void:
	sprite.play(StringName(name), StringName(return_to))


func emote(kind: String) -> void:
	if _bubble == null:
		_bubble = Label3D.new()
		_bubble.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_bubble.font_size = 48
		_bubble.pixel_size = 0.01
		_bubble.position = Vector3(0, 2.1, 0)
		_bubble.outline_size = 8
		add_child(_bubble)
	_bubble.text = kind
	_bubble.visible = true
	var tw := create_tween()
	tw.tween_interval(1.2)
	tw.tween_callback(func() -> void: if _bubble: _bubble.visible = false)
