## A battler in the world (Combat Laws Bible §18.1): a CharacterBody3D with its components as children
## and an ActorSprite. Party members and enemies both use this; factories fill the components from data.
class_name CombatActor
extends CharacterBody3D

signal arrived
signal hurt(amount: int)

const WALK_SPEED := 3.6
const RUN_SPEED := 5.6

@export var actor_id: StringName = &""
@export var is_party: bool = false

var stats: CombatantStats
var statuses: StatusComponent
var shield: ShieldComponent
var time_debt: TimeDebtComponent
var solidity: SolidityComponent
var sprite: ActorSprite
var nav: NavigationAgent3D
var break_hull: Area3D
var def: EnemyDef
var kit: Dictionary = {}
var home_universe: int = 0
var canvas_fps: float = 60.0
var height_m: float = 1.7
var frozen: bool = false
var _walk_target: Variant = null
var _walk_speed: float = WALK_SPEED
var _walk_done: bool = true
var _statue_left: float = 0.0
var _label: Label3D


func _ready() -> void:
	collision_layer = 2 if is_party else 4
	collision_mask = 1
	if get_node_or_null("CollisionShape3D") == null:
		var cs := CollisionShape3D.new()
		cs.name = "CollisionShape3D"
		var cap := CapsuleShape3D.new()
		cap.radius = 0.35
		cap.height = maxf(1.0, height_m)
		cs.shape = cap
		cs.position = Vector3(0, maxf(0.5, height_m * 0.5), 0)
		add_child(cs)
	_make_break_hull()


func _make_break_hull() -> void:
	break_hull = Area3D.new()
	break_hull.name = "BreakHull"
	break_hull.collision_layer = 16
	break_hull.collision_mask = 0
	break_hull.monitoring = false
	break_hull.monitorable = true
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = (stats.body_radius if stats else 0.5) * (1.0 + CombatConstants.BREAK_HULL_INFLATION)
	cyl.height = maxf(1.0, height_m)
	cs.shape = cyl
	cs.position = Vector3(0, cyl.height * 0.5, 0)
	break_hull.add_child(cs)
	add_child(break_hull)
	break_hull.visible = false


func _physics_process(delta: float) -> void:
	if frozen:
		velocity = Vector3.ZERO
		return
	if _walk_target != null:
		var to: Vector3 = _walk_target
		var flat := Vector3(to.x - global_position.x, 0.0, to.z - global_position.z)
		if flat.length() < 0.12:
			velocity = Vector3.ZERO
			_walk_target = null
			_walk_done = true
			if sprite:
				sprite.update_from_velocity(Vector3.ZERO)
			arrived.emit()
		else:
			velocity = flat.normalized() * _walk_speed
			if not is_on_floor():
				velocity.y -= 20.0 * delta
			move_and_slide()
			if sprite:
				sprite.update_from_velocity(velocity)
		return
	if not is_on_floor():
		velocity.y -= 20.0 * delta
		move_and_slide()
	if _statue_left > 0.0:
		_statue_left -= delta
		if _statue_left <= 0.0:
			visible = false


## Scripted walk (Story commands, battle repositioning). Awaitable.
func walk_to(target: Vector3, speed: float = WALK_SPEED) -> void:
	_walk_target = target
	_walk_speed = speed
	_walk_done = false
	frozen = false
	while not _walk_done and is_inside_tree():
		await get_tree().physics_frame


func face(dir: String) -> void:
	if sprite:
		sprite.set_facing(StringName(dir))


func face_toward(p: Vector3) -> void:
	if sprite:
		sprite.face_vector(p - global_position)


func play_anim(name: String, return_to: String = "idle") -> void:
	if sprite:
		sprite.play(StringName(name), StringName(return_to))


func emote(_kind: String) -> void:
	if _label == null:
		_label = Label3D.new()
		_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_label.font_size = 48
		_label.pixel_size = 0.01
		_label.position = Vector3(0, height_m + 0.5, 0)
		_label.outline_size = 8
		add_child(_label)
	_label.text = _kind
	_label.visible = true
	var tw := create_tween()
	tw.tween_interval(1.0)
	tw.tween_callback(func() -> void: _label.visible = false)


## Break: freeze mid-step and become terrain (§5.4–5.5).
func on_break() -> void:
	frozen = true
	velocity = Vector3.ZERO
	if nav:
		nav.avoidance_enabled = false
	if break_hull:
		break_hull.monitorable = true
		break_hull.visible = true
	if sprite:
		sprite.play(&"break")
		sprite.set_tint(Color(1.0, 0.92, 0.6))


func on_recover() -> void:
	frozen = false
	if nav:
		nav.avoidance_enabled = true
	if break_hull:
		break_hull.visible = false
	if sprite:
		sprite.set_tint(Color.WHITE)
		sprite.play(&"idle")


## Killed while Broken: stays as a gold statue for 8 s (§5.4).
func become_statue() -> void:
	frozen = true
	_statue_left = CombatConstants.BROKEN_STATUE_S
	if sprite:
		sprite.set_tint(Color(1.0, 0.85, 0.4))
		sprite.play(&"break")


func die() -> void:
	if sprite:
		sprite.play(&"death")
	frozen = true
	var tw := create_tween()
	tw.tween_interval(0.9)
	tw.tween_property(sprite, "transparency", 1.0, 0.5)
	tw.tween_callback(func() -> void: visible = false)


func set_porcelain_visuals() -> void:
	if time_debt == null or sprite == null or stats == null:
		return
	var state: int = time_debt.crack_state(float(stats.hp) / float(maxi(1, stats.base_max_hp)))
	var amount: float = 0.0
	match state:
		TimeDebtComponent.CrackState.HAIRLINE:
			amount = 0.45
		TimeDebtComponent.CrackState.GALAXY:
			amount = 0.9
		TimeDebtComponent.CrackState.FLATLINE:
			amount = 1.0
	sprite.set_porcelain(state + 1 if state > 0 else 1, amount, float(Flags.counter(&"kintsugi_repairs")) * 0.1)


# ------------------------------------------------------------------ factories

static func create_party_member(id: StringName, level: int = -1) -> CombatActor:
	var a := CombatActor.new()
	a.name = String(id)
	a.actor_id = id
	a.is_party = true
	var k: Dictionary = Data.character(id)
	a.kit = k
	a.home_universe = int(k.get("home_universe", 0))
	a.canvas_fps = float(k.get("canvas_fps", 60.0))
	a.height_m = float(k.get("height_m", 1.7))
	var lv: int = level if level > 0 else Game.level_of(id)
	a.stats = CombatantStats.new()
	a.stats.name = "CombatantStats"
	a.stats.apply_party_curve(id, lv)
	a.stats.display_name = String(k.get("name", String(id).capitalize()))
	a.stats.home_universe = a.home_universe
	a.stats.canvas_fps = a.canvas_fps
	a.stats.move_range = float(k.get("move_range", 6.0))
	var weapon: Dictionary = k.get("weapon", {})
	a.stats.weapon_tags = CombatTags.to_names(weapon.get("tags", ["SWORD"]))
	a.stats.weapon_hits = int(weapon.get("hits", 1))
	a.stats.vulnerable = CombatTags.to_names(k.get("vulnerable", []))
	a.stats.resistant = CombatTags.to_names(k.get("resistant", []))
	a.stats.xp = int(Game.roster.get(id, {}).get("xp", 0))
	a.add_child(a.stats)
	a.statuses = StatusComponent.new()
	a.statuses.name = "StatusComponent"
	a.add_child(a.statuses)
	if id == &"crono":
		a.time_debt = TimeDebtComponent.new()
		a.time_debt.name = "TimeDebtComponent"
		a.time_debt.integrity = Game.crono_integrity
		a.add_child(a.time_debt)
	if id == &"sera":
		a.solidity = SolidityComponent.new()
		a.solidity.name = "SolidityComponent"
		a.solidity.debt = Game.sera_debt
		a.solidity.permanent_baseline = Game.sera_permanent_baseline
		if Game.hold_upgraded:
			a.solidity.hold_step_seconds = CombatConstants.SERA_HOLD_BREAK_EXTENSION_UPGRADED_S
		a.add_child(a.solidity)
	a.stats.reset_vitals()
	var ratio: float = float(Game.roster.get(id, {}).get("hp_ratio", 1.0))
	a.stats.hp = maxi(1, roundi(float(a.stats.max_hp()) * ratio))
	a.sprite = ActorSprite.new()
	a.sprite.name = "Sprite"
	a.add_child(a.sprite)
	SpriteLibrary.apply(a.sprite, String(k.get("sprite", id)), a.canvas_fps)
	if id == &"sera":
		a.sprite.position.y = 4.0 / 64.0
	return a


static func create_enemy(enemy_def: EnemyDef, level_override: int = -1, suffix: String = "") -> CombatActor:
	var a := CombatActor.new()
	a.def = enemy_def
	a.name = String(enemy_def.key) + suffix
	a.actor_id = enemy_def.key
	a.is_party = false
	a.home_universe = enemy_def.universe
	a.canvas_fps = enemy_def.fps
	a.height_m = 1.6 * enemy_def.size
	var lv: int = level_override if level_override > 0 else enemy_def.level
	a.stats = CombatantStats.new()
	a.stats.name = "CombatantStats"
	a.stats.actor_id = enemy_def.key
	a.stats.display_name = enemy_def.display_name
	a.stats.apply_enemy_curve(lv, enemy_def.kind)
	if enemy_def.hp_override > 0:
		a.stats.base_max_hp = enemy_def.hp_override
	else:
		a.stats.base_max_hp = roundi(float(a.stats.base_max_hp) * enemy_def.hp_mult)
	a.stats.spd *= enemy_def.spd_mult
	a.stats.home_universe = enemy_def.universe
	a.stats.canvas_fps = enemy_def.fps
	a.stats.body_radius = enemy_def.body_radius
	a.stats.tags = enemy_def.tags.duplicate()
	a.stats.weapon_tags = enemy_def.tags.duplicate() if not enemy_def.tags.is_empty() else [&"BLUNT"]
	a.add_child(a.stats)
	a.statuses = StatusComponent.new()
	a.statuses.name = "StatusComponent"
	a.add_child(a.statuses)
	a.shield = ShieldComponent.new()
	a.shield.name = "ShieldComponent"
	a.shield.configure(enemy_def.shield_config())
	a.add_child(a.shield)
	a.stats.reset_vitals()
	if enemy_def.is_metal:
		a.set_meta("is_metal", true)
	a.sprite = ActorSprite.new()
	a.sprite.name = "Sprite"
	a.add_child(a.sprite)
	SpriteLibrary.apply_enemy(a.sprite, enemy_def)
	a.nav = NavigationAgent3D.new()
	a.nav.name = "NavigationAgent3D"
	a.nav.avoidance_enabled = false
	a.add_child(a.nav)
	return a
