## A battler in the world (Combat Laws Bible §18.1): a CharacterBody3D with its components as children
## and an ActorSprite. Party members and enemies both use this; factories fill the components from data.
class_name CombatActor
extends CharacterBody3D

## A scripted walk ended (arrived, or resolved where the body stands: ScriptedWalk).
signal arrived
signal hurt(amount: int)

const WALK_SPEED := 3.6
const RUN_SPEED := 5.6
const GRAVITY := 20.0
const ARRIVE_M := 0.12
## Sera's look (Story Bible §4.2 "Look", Chapter 1 beat 2): her body thins by this much opacity per point
## of Translucency Debt (55, the field cap, leaves her at ~0.73); _set_debt_visuals.
const DEBT_OPACITY_PER_POINT := 0.005
## A phased Sera (Combat Laws §10.2, untargetable) reads as a gold ghost at 18 %: apply_body_look.
const PHASED_OPACITY := 0.18
const PHASED_TINT := Color(1.0, 0.85, 0.5)

@export var actor_id: StringName = &""
@export var is_party: bool = false

var stats: CombatantStats
var statuses: StatusComponent
var shield: ShieldComponent
var time_debt: TimeDebtComponent
var solidity: SolidityComponent
var corruption: CorruptionComponent
var sprite: ActorSprite
var nav: NavigationAgent3D
var break_hull: Area3D
var def: EnemyDef
var kit: Dictionary = {}
var home_universe: int = 0
var canvas_fps: float = 60.0
var height_m: float = 1.7
var frozen: bool = false
## Killed while Broken: a gold statue until the coordinator's StatueTimers shatter it (§5.4).
var statue: bool = false
var _walk: ScriptedWalk = null
var _stepped_frame: int = -10
var _label: Label3D
var _fade: Tween
## The NavigationAgent's avoidance as a Break found it (held while Broken): on_recover() and restore_body() hand it back.
var _avoid_held: bool = false
var _avoid_before_break: bool = false


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
	break_hull.monitorable = false  # terrain only while Broken or a statue (_set_hull)
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
	if _walk != null:
		var v: Vector3 = _walk.step(global_position, delta)  # a frozen walker makes no headway and resolves
		if _walk.done():
			_end_walk()
		elif not frozen:
			step(v, delta)
	if frozen:
		velocity = Vector3.ZERO
		return
	# Nobody else moves this body: it falls on its own. A mover that stepped it this tick or the last owns
	# the fall, so gravity is applied once per tick (PlayerController, PartyFollow and EncounterZone step it).
	if _walk == null and not is_on_floor() and Engine.get_physics_frames() - _stepped_frame > 1:
		velocity.y -= GRAVITY * delta
		move_and_slide()


## Move this body for one physics tick: `horizontal` (x/z) as its walking velocity, gravity while it is off
## the floor, one move_and_slide, the sprite turned to match. Every mover goes through here.
func step(horizontal: Vector3, delta: float) -> void:
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y -= GRAVITY * delta
	move_and_slide()
	_stepped_frame = Engine.get_physics_frames()
	if sprite:
		sprite.update_from_velocity(velocity)


## Scripted walk (Story commands, cutscenes). Awaitable, and it always resolves: on arrival, or where the body
## stands once it stops making headway (a prop in the way, a frozen body) or runs out of time (ScriptedWalk).
func walk_to(target: Vector3, speed: float = WALK_SPEED) -> void:
	var walk := ScriptedWalk.new(global_position, target, speed, ARRIVE_M)
	_walk = walk
	frozen = false
	while not walk.done() and _walk == walk and is_inside_tree():
		await get_tree().physics_frame


func is_walking() -> bool:
	return _walk != null


func _end_walk() -> void:
	if _walk.result != ScriptedWalk.ARRIVED:
		push_warning("%s: walk to %s %s at %s" % [name, str(_walk.target), _walk.result, str(global_position)])
	_walk = null
	velocity = Vector3(0.0, velocity.y, 0.0)
	if sprite:
		sprite.update_from_velocity(Vector3.ZERO)
	arrived.emit()


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
		if not _avoid_held:
			_avoid_before_break = nav.avoidance_enabled
			_avoid_held = true
		nav.avoidance_enabled = false
	_set_hull(true)
	if sprite:
		sprite.play(&"break")
		sprite.set_tint(Color(1.0, 0.92, 0.6))


func on_recover() -> void:
	frozen = false
	_restore_avoidance()
	_set_hull(false)
	if sprite:
		sprite.set_tint(Color.WHITE)
		sprite.play(&"idle")


## Killed while Broken: a gold statue that keeps the inflated hull and stays terrain for 8 s of battle time
## (§5.4); the coordinator's StatueTimers counts them and calls shatter().
func become_statue() -> void:
	frozen = true
	statue = true
	_set_hull(true)
	if sprite:
		sprite.set_tint(Color(1.0, 0.85, 0.4))
		sprite.play(&"break")


## The statue's 8 s are up: it shatters in gold and the body is gone from the field (§5.4).
func shatter() -> void:
	statue = false
	_set_hull(false)
	var parent := get_parent() as Node3D
	if visible and parent != null:
		BattleFx.gold_shatter(parent, global_position + Vector3(0.0, height_m * 0.5, 0.0))
	visible = false


func die() -> void:
	if sprite:
		sprite.play(&"death")
	frozen = true
	_fade = create_tween()
	_fade.tween_interval(0.9)
	_fade.tween_property(sprite, "transparency", 1.0, 0.5)
	_fade.tween_callback(func() -> void: visible = false)


## Undo die(), become_statue() and on_break() on the body once a battle is over (BattleAftermath) or when a
## fallen ally is revived mid-battle (die()'s fade is stopped): standing, visible, in its standing look
## (apply_body_look: a Sera revived while still phased stays phased), the Break hull down and free to walk.
## HP and shields are the caller's.
func restore_body() -> void:
	if _fade != null and _fade.is_valid():
		_fade.kill()
	_fade = null
	statue = false
	visible = true
	frozen = false
	velocity = Vector3.ZERO
	_restore_avoidance()
	_set_hull(false)
	if sprite:
		sprite.transparency = 0.0
		apply_body_look()
		sprite.play(&"idle")


## The Break hull (§5.4's inflated terrain) up or down: shown and detectable on layer 5 together.
func _set_hull(up: bool) -> void:
	if break_hull:
		break_hull.visible = up
		break_hull.monitorable = up


func _restore_avoidance() -> void:
	if nav and _avoid_held:
		nav.avoidance_enabled = _avoid_before_break
	_avoid_held = false


## The porcelain a body shows: Crono's crack states from his integrity and HP (Combat Laws §10.1), Sera's
## from her Translucency Debt (_set_debt_visuals). Other bodies show none.
func set_porcelain_visuals() -> void:
	if sprite != null and solidity != null:
		_set_debt_visuals()
		return
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


## Sera pays with herself (Story Bible §4.2 "Look", Chapter 1 beat 2): pristine at 0 Debt; from the first
## point the crack shows as the hairline state and spreads with the Debt (0.2 + Debt/100), and her body thins
## by DEBT_OPACITY_PER_POINT per point. The shader has no mask that keeps the veins under her left eye yet,
## so they run where the crack noise peaks (QUESTIONS_FOR_NICH).
func _set_debt_visuals() -> void:
	var debt: float = solidity.debt
	if debt <= 0.0:
		sprite.set_porcelain(1, 0.0)
	else:
		sprite.set_porcelain(2, clampf(0.2 + debt / 100.0, 0.2, 1.0))
	apply_body_look(false)


## How solid the body stands when nothing else fades it: 1.0, and for Sera 1.0 - Debt * DEBT_OPACITY_PER_POINT
## (never below 0.5). Un-phasing and a revive return her here, not to fully solid.
func body_opacity() -> float:
	if solidity == null:
		return 1.0
	return clampf(1.0 - solidity.debt * DEBT_OPACITY_PER_POINT, 0.5, 1.0)


## The one owner of the body's standing opacity and tint (a Break, a statue, die()'s fade and a scene's own
## tint aside): while Sera is phased (SolidityComponent.is_phased) she is a PHASED_OPACITY ghost in PHASED_TINT
## whatever redraws her (a hit, a DoT tick, a revive), otherwise the body stands at body_opacity(). `untint`
## also clears the tint of a body that is not phased (un-phase, restore_body, a battle's end); a Debt redraw
## (set_porcelain_visuals) passes false, so a cutscene's grey tint survives it.
func apply_body_look(untint: bool = true) -> void:
	if sprite == null:
		return
	if solidity != null and solidity.is_phased():
		sprite.set_opacity(PHASED_OPACITY)
		sprite.set_tint(PHASED_TINT)
		return
	sprite.set_opacity(body_opacity())
	if untint:
		sprite.set_tint(Color.WHITE)


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
	if id == &"krona":
		a.corruption = CorruptionComponent.new()
		a.corruption.name = "CorruptionComponent"
		a.corruption.value = Game.krona_corruption
		a.add_child(a.corruption)
	a.stats.reset_vitals()
	var ratio: float = float(Game.roster.get(id, {}).get("hp_ratio", 1.0))
	a.stats.hp = maxi(1, roundi(float(a.stats.max_hp()) * ratio))
	a.sprite = ActorSprite.new()
	a.sprite.name = "Sprite"
	a.add_child(a.sprite)
	SpriteLibrary.apply(a.sprite, String(k.get("sprite", id)), a.canvas_fps)
	a.sprite.position.y = float(k.get("y_offset", 0.0))  # metres the sprite floats (Sera: 0.0625)
	a.set_porcelain_visuals()  # every spawn (field, cast, a battle reserve) wears its Debt and cracks from the start
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
	if enemy_def.xp_override > 0:
		a.stats.xp_reward = enemy_def.xp_override
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
