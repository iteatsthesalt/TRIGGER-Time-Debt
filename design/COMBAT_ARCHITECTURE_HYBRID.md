# Hybrid HD-2D Combat Architecture (reference, uploaded 2026-11-02)

The architecture note `Hybrid_Chrono_Octopath_Combat_Architecture_1_1.md` that informed the Combat Laws Bible,
kept here so its ideas can be checked against the build. It is a reference, not a rule: `COMBAT_LAWS_BIBLE.md`
(as amended by `docs/DECISIONS.md`) is canonical wherever the two differ. The 2026-11-02 audit scored it against
the code (docs/reports/WORKSPACE_AUDIT_2026-11-02.md, ARCH-1..15): compound tag shaving, Break-locked cover,
AoE scale per Boost level, Sync Hold and the diorama lock are built; enemy battlefield drift, knockback
clustering and the dash-to-cover Move are not (PROGRESS known issues).

---

# Hybrid HD-2D Combat Architecture: Blending Chrono Trigger & Octopath Traveler in Godot 4

## Synchronized Timeline Combat Unifies Seamless Overworld Battles with Break and Boost Economy

Combining [*Chrono Trigger*'s Active Time Battle 2.0](https://en.wikipedia.org/wiki/Chrono_Trigger) with [*Octopath Traveler*'s Break and Boost system](https://en.wikipedia.org/wiki/Octopath_Traveler) requires resolving a fundamental pacing conflict: *Chrono Trigger* relies on real-time speed gauges and dynamic enemy movement across the overworld map, whereas *Octopath Traveler* relies on discrete round forecasting, Shield Point arithmetic, and turn-by-turn Boost Point (BP) banking.

The **Synchronized Timeline Architecture** bridges both systems in Godot 4 without sacrificing the tactical depth of either inspiration:

| System Pillar | [*Chrono Trigger*](https://en.wikipedia.org/wiki/Chrono_Trigger) Foundation | [*Octopath Traveler*](https://en.wikipedia.org/wiki/Octopath_Traveler) Foundation | Hybrid Godot 4 Synthesis |
| :--- | :--- | :--- | :--- |
| **Battle Transition** | Contact with field enemies starts combat directly on the exploration map without a loading screen. | Dramatic glass-shatter transition into a fixed diorama stage with depth-of-field bokeh. | **In-Place Diorama Lock**: Triggering an encounter [`Area3D`](https://docs.godotengine.org/en/stable/classes/class_area3d.html) freezes field exploration, narrows [`Camera3D`](https://docs.godotengine.org/en/stable/classes/class_camera3d.html) FOV from `32°` to `24°`, ramps up [`CameraAttributesPractical`](https://docs.godotengine.org/en/stable/classes/class_cameraattributespractical.html) blur, and fans characters out onto local 3D combat anchors. |
| **Turn Progression & Syncing** | Personal speed timers count down to zero; characters wait at full gauge to fire [Dual or Triple Techs](https://chrono.fandom.com/wiki/Tech_(Chrono_Trigger)). | Visible top-of-screen turn timeline ([*Octopath Traveler II*](https://octopathtraveler2.wiki.fextralife.com/Octopath_Traveler_II_Combat)); defending pushes a unit to the start of the next round. | **Action Gate Timeline with Sync Hold**: Units advance along a visible CTB/ATB timeline. Reaching the Action Gate pauses enemy drift and grants `+1 BP`. Players can act immediately or select **Sync Hold** to wait in the Ready Pool until a partner reaches the gate. |
| **Weaknesses & Shield Break** | Techs have elemental affinities (Fire, Water, Lightning, Shadow) and physical weapon properties. | Foes carry Shield Points and hidden weaknesses (`?`); hitting a weakness strips `1 Shield Point`, and hitting `0` causes a **Break** (skipping a turn and taking `2.0x` damage). | **Compound Tech Tag Shaving**: Dual and Triple Techs inherit **all** weapon and elemental tags of their participants. A Sword + Fire Dual Tech strips Shield Points for *both* Sword and Fire weaknesses simultaneously on every hit. |
| **Spatial AoE & Enemy Drift** | Enemies wander the battlefield over time; [Techs](https://chrono.fandom.com/wiki/Tech_(Chrono_Trigger)) target lines, circles, or cones based on live positions. | Enemies remain in fixed front/back rows; AoE skills hit all foes regardless of spacing. | **Break-Locked Spatial Geometry**: Enemies reposition between turns via [`NavigationAgent3D`](https://docs.godotengine.org/en/stable/classes/class_navigationagent3d.html). Triggering a **Break** freezes the target's navigation agent in place (and optionally applies knockback clustering), locking them inside follow-up Dual/Triple Tech [`ShapeCast3D`](https://docs.godotengine.org/en/stable/classes/class_shapecast3d.html) zones. |
| **Boost Point (BP) Economy** | Techs cost MP; cooperative Techs sum component damages and multiply by a synergy factor (`>1.0x`). | Units store up to `5 BP` and spend up to `3 BP` per turn for extra weapon hits or [`+90%` additive skill scaling per BP](https://octopathtraveler.fandom.com/wiki/Damage_Formula); no BP is gained on the turn after boosting. | **Pooled Co-Op Overboost**: Dual/Triple Techs draw up to `3 BP` total from the participating allies' pools. Each Boost tier increases [skill damage](https://octopathtraveler.fandom.com/wiki/Damage_Formula) (`100% / 190% / 280% / 370%`), widens the 3D AoE footprint by `+25%`, and adds bonus Shield shave at Max Boost. |

## Scene Tree Hierarchy Separates Overworld Exploration from Tactical Combat Sub-Systems

To support seamless transitions on any time-era map (`600 AD`, `1000 AD`, `2300 AD`), each character and enemy is built as a self-contained [`CharacterBody3D`](https://docs.godotengine.org/en/stable/classes/class_characterbody3d.html) with modular combat components attached as child nodes:

```text
EraMapScene (Node3D)
├── WorldEnvironment (WorldEnvironment)          # Era-specific tonemap, volumetric fog & Boost dimming
├── HD2DCameraRig (Node3D)
│   └── Camera3D (Camera3D)                      # Perspective (24°–32° FOV) + CameraAttributesPractical DOF
├── HybridBattleCoordinator (Node)               # State machine: EXPLORATION -> TACTICAL_COMBAT -> VICTORY
├── PartyManager (Node3D)
│   └── TravelerActor (CharacterBody3D)
│       ├── AnimatedSprite3D (AnimatedSprite3D)  # Y-Billboarded pixel sprite + Alpha Scissor shadows
│       ├── NavigationAgent3D (NavigationAgent3D)# Paths to combat anchors & Dual Tech choreography points
│       ├── CombatantStats (Node)                # HP, MP/SP, Speed, P.Atk, E.Atk, P.Def, E.Def
│       ├── BoostComponent (Node)                # 0–5 BP storage, 0–3 spend cap, post-boost lock flag
│       ├── BoostAuraVFX (GPUParticles3D)        # Emits HD-2D glowing embers scaled by Boost tier
│       └── TacticalPositioner3D (Node3D)        # Holds ShapeCast3D & Area3D templates for Line/Circle AoEs
└── EncounterZone_01 (Area3D)                    # Triggers seamless battle on body_entered
    ├── CollisionShape3D (CollisionShape3D)      # Defines battle arena boundary during combat
    └── EnemyGroup (Node3D)
        └── EnemyActor (CharacterBody3D)
            ├── AnimatedSprite3D (AnimatedSprite3D)
            ├── NavigationAgent3D (NavigationAgent3D) # Roams between turns unless Broken
            ├── CombatantStats (Node)
            └── ShieldComponent (Node)           # Shield Points, Weakness array, Revealed array, Break state
```

## Compound Weakness and Shield Mechanics Reward Multi-Character Tech Synergy

In [*Octopath Traveler*](https://en.wikipedia.org/wiki/Octopath_Traveler), enemies possess specific weapon and elemental vulnerabilities alongside a numeric Shield Point counter. Striking a weakness reduces Shield Points by `1` per hit and applies a `1.3x` damage modifier; reducing Shield Points to `0` inflicts **Break**, stunning the enemy, stripping its next action, and elevating all incoming damage to a `2.0x` multiplier regardless of weakness.

When merged with [*Chrono Trigger*'s cooperative Techs](https://chrono.fandom.com/wiki/Tech_(Chrono_Trigger)), Shield breaking becomes a spatial and combinatorial puzzle:

- **Compound Tag Inheritance**: A Single Tech typically carries one damage tag (e.g., Crono's *Cyclone* carries `SWORD`; Lucca's *Flame Toss* carries `FIRE`). Their Dual Tech *Fire Whirl* carries `[SWORD, FIRE]`.
- **Double Shield Shaving**: When an attack carrying multiple tags strikes an enemy, `ShieldComponent` checks every tag in the Tech against the enemy's weakness profile. If a boss is weak to **both** `SWORD` and `FIRE`, *Fire Whirl* shaves `2 Shield Points` per hit instead of `1`, and reveals both `[?]` icons on the enemy's HUD bar simultaneously.
- **Break Immobilization & Knockback Clustering**: Normally, enemies use [`NavigationAgent3D`](https://docs.godotengine.org/en/stable/classes/class_navigationagent3d.html) to reposition between timeline ticks, spreading out to avoid party AoEs. The moment an enemy's Shield reaches `0`, its [`NavigationAgent3D`](https://docs.godotengine.org/en/stable/classes/class_navigationagent3d.html) velocity is zeroed out and locked for the duration of the Break, and an optional knockback impulse pushes the staggered foe toward nearby enemies—setting up a cluster for a Boosted Triple Tech.
- **Anti-Stunlock Recovery Priority**: Following [*Octopath Traveler*'s recovery rule](https://en.wikipedia.org/wiki/Octopath_Traveler), when a Broken enemy finally reaches its recovery turn on the timeline, it restores its full Shield Points and acts with top timeline priority so the party cannot infinitely stunlock bosses.

```gdscript
# ShieldComponent.gd
class_name ShieldComponent
extends Node

signal shield_changed(current_shields: int, max_shields: int)
signal weakness_revealed(damage_type: int)
signal broken(breaker: Node3D)
signal break_recovered()

enum DamageType {
	SWORD, SPEAR, DAGGER, AXE, BOW, STAFF,
	FIRE, ICE, LIGHTNING, WIND, LIGHT, SHADOW
}

@export var max_shields: int = 4
@export var weaknesses: Array[DamageType] = [DamageType.SWORD, DamageType.FIRE]

var current_shields: int = 4
var is_broken: bool = false
var revealed_weaknesses: Dictionary = {} # DamageType -> bool

func _ready() -> void:
	current_shields = max_shields
	for w in weaknesses:
		revealed_weaknesses[w] = false

## Evaluates a hit that may carry multiple damage tags (e.g. Dual/Triple Techs).
## Returns a dictionary with damage_multiplier and shields_shaved.
func evaluate_incoming_hit(
	attack_tags: Array[DamageType],
	hit_count: int,
	bonus_shield_shave: int,
	attacker: Node3D
) -> Dictionary:
	var matching_weaknesses: int = 0
	for tag in attack_tags:
		if tag in weaknesses:
			matching_weaknesses += 1
			if not revealed_weaknesses.get(tag, false):
				revealed_weaknesses[tag] = true
				weakness_revealed.emit(tag)

	if is_broken:
		# Broken enemies take 2.0x damage from all attacks; shields do not drop further.
		return {
			"damage_multiplier": 2.0,
			"shields_shaved": 0,
			"hit_weakness": matching_weaknesses > 0
		}

	var total_shave: int = 0
	var dmg_mult: float = 1.0

	if matching_weaknesses > 0:
		dmg_mult = 1.3
		# Dual/Triple Techs matching 2+ weaknesses shave multiple shields per strike!
		total_shave = (matching_weaknesses * hit_count) + bonus_shield_shave
		current_shields = maxi(0, current_shields - total_shave)
		shield_changed.emit(current_shields, max_shields)

		if current_shields == 0:
			_trigger_break(attacker)

	return {
		"damage_multiplier": dmg_mult,
		"shields_shaved": total_shave,
		"hit_weakness": matching_weaknesses > 0
	}

func _trigger_break(breaker: Node3D) -> void:
	is_broken = true
	broken.emit(breaker)

func recover_from_break() -> void:
	if not is_broken:
		return
	is_broken = false
	current_shields = max_shields
	shield_changed.emit(current_shields, max_shields)
	break_recovered.emit()
```

## Pooled Boost Point Economy Scales Tech Potency, Hit Counts, and 3D AoE Geometry

In [*Octopath Traveler*](https://octopathtraveler.fandom.com/wiki/Damage_Formula), each traveler stores up to `5 BP` and can spend `1` to `3 BP` on their turn:
- **Standard Weapon Attacks**: Gain `+1` additional strike per BP spent (`1 / 2 / 3 / 4` hits total), making boosted basic attacks ideal for stripping Shield Points.
- **Single Skills & Techs**: Scale additively per BP using [*Octopath*'s skill Boost formula](https://octopathtraveler.fandom.com/wiki/Damage_Formula):

$$	ext{Boost Multiplier} = 1.0 + (	ext{Boost Level} 	imes 0.90) \quad \Rightarrow \quad 100\% \;/\; 190\% \;/\; 280\% \;/\; 370\%$$

- **Dual and Triple Tech Pooled Boosting**: When two or three characters execute a cooperative Tech, they do not each need `3 BP`. Instead, they contribute to a **Shared Tech Boost Pool** capped at `3 BP` total (for example, Crono spends `2 BP` and Lucca spends `1 BP` to reach **MAX Boost Level 3**). Any character who contributes `>= 1 BP` to the pool receives the standard post-boost cooldown flag and does not gain `+1 BP` at the start of their next turn.

| Boost Tier | Total BP Spent | Standard Attack Effect | Single / Dual / Triple Tech Damage Multiplier | 3D Spatial AoE Expansion ([`ShapeCast3D`](https://docs.godotengine.org/en/stable/classes/class_shapecast3d.html) / [`Area3D`](https://docs.godotengine.org/en/stable/classes/class_area3d.html)) | Extra Shield Shave Bonus |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Unboosted (Lv. 0)** | `0 BP` | `1×` Weapon Strike | `1.00×` (`100%`) | `1.00×` Base Line Width / Circle Radius | `+0` Shield Points |
| **Boost Lv. 1** | `1 BP` | `2×` Weapon Strikes | `1.90×` (`190%`) | `1.25×` Line Width / Circle Radius | `+0` Shield Points |
| **Boost Lv. 2** | `2 BP` | `3×` Weapon Strikes | `2.80×` (`280%`) | `1.50×` Line Width / Circle Radius | `+0` Shield Points |
| **MAX Boost (Lv. 3)** | `3 BP` | `4×` Weapon Strikes | `3.70×` (`370%`) | `1.75×` Line Width / Circle Radius + Camera Bloom Surge | `+1` Bonus Shield Shave (even on 1-hit Techs) |

```gdscript
# BoostComponent.gd
class_name BoostComponent
extends Node

signal bp_changed(current_bp: int, max_bp: int)
signal boost_preview_changed(preview_level: int)

const MAX_BP: int = 5
const MAX_SPEND_PER_ACTION: int = 3

var current_bp: int = 1
var spent_bp_last_turn: bool = false

func on_turn_start() -> void:
	# Octopath rule: gain 1 BP at turn start ONLY if BP was not spent on the previous action.
	if not spent_bp_last_turn:
		add_bp(1)
	spent_bp_last_turn = false

func add_bp(amount: int) -> void:
	current_bp = clampi(current_bp + amount, 0, MAX_BP)
	bp_changed.emit(current_bp, MAX_BP)

func can_spend(amount: int) -> bool:
	return amount >= 0 and amount <= MAX_SPEND_PER_ACTION and amount <= current_bp

func commit_spend(amount: int) -> void:
	if amount > 0:
		current_bp = maxi(0, current_bp - amount)
		spent_bp_last_turn = true
		bp_changed.emit(current_bp, MAX_BP)
	else:
		spent_bp_last_turn = false

## Helper for Dual/Triple Techs: splits a requested total_bp (0..3) across participating BoostComponents.
static func allocate_coop_boost(participants: Array[BoostComponent], requested_total_bp: int) -> Dictionary:
	var target_bp: int = clampi(requested_total_bp, 0, MAX_SPEND_PER_ACTION)
	var allocation: Dictionary = {}
	var remaining: int = target_bp

	for comp in participants:
		allocation[comp] = 0

	# Round-robin draw 1 BP at a time from participants with the highest available BP
	while remaining > 0:
		var best_comp: BoostComponent = null
		var highest_available: int = 0
		for comp in participants:
			var avail: int = comp.current_bp - allocation[comp]
			if avail > highest_available:
				highest_available = avail
				best_comp = comp
		if best_comp == null:
			break # Not enough combined BP across participants
		allocation[best_comp] += 1
		remaining -= 1

	return {
		"success": remaining == 0,
		"effective_boost_level": target_bp - remaining,
		"allocation": allocation
	}
```

## Resource-Driven Tech Definitions Encode Participants, Spatial Shapes, and Formulas

Using Godot's custom [`Resource`](https://docs.godotengine.org/en/stable/classes/class_resource.html) system allows designers to author Single, Dual, and Triple Techs as `.tres` files in the Inspector. Combining [*Octopath Traveler*'s physical/elemental damage formula](https://octopathtraveler.fandom.com/wiki/Damage_Formula) with [*Chrono Trigger*'s additive Dual/Triple Tech synergy](https://chrono.fandom.com/wiki/Tech_(Chrono_Trigger)) produces a clean, predictable damage curve:

$$	ext{Base Tech Damage} = 0.8 	imes \left( \sum_{i \in 	ext{Casters}} 	ext{Atk}_i - (	ext{Target Def} 	imes 0.5) 
ight) 	imes M_{	ext{tech}} 	imes M_{	ext{synergy}} 	imes \left(1.0 + 0.9 	imes L_{	ext{boost}}
ight)$$

```gdscript
# TechResource.gd
class_name TechResource
extends Resource

enum TechTier { SINGLE, DUAL, TRIPLE }
enum SpatialShape { SINGLE_TARGET, LINE_PIERCE, CIRCLE_AROUND_TARGET, SELF_AURA, CLEAVE_CONE }

@export var tech_id: StringName = &"fire_whirl"
@export var display_name: String = "Fire Whirl"
@export var tier: TechTier = TechTier.DUAL

## Character IDs required in the Ready Pool (e.g. ["crono", "lucca"])
@export var required_actor_ids: Array[StringName] = [&"crono", &"lucca"]
@export var mp_cost_per_actor: int = 4

## Combined weapon & elemental tags shaved on every hit
@export var damage_tags: Array[ShieldComponent.DamageType] = [
	ShieldComponent.DamageType.SWORD,
	ShieldComponent.DamageType.FIRE
]

@export var uses_elemental_attack: bool = true
@export var base_multiplier: float = 1.65
@export var synergy_multiplier: float = 1.25 # >1.0x Chrono Trigger co-op bonus
@export var hit_count: int = 2
@export var boost_bonus_per_level: float = 0.90 # +90% per BP (100% / 190% / 280% / 370%)

@export_group("3D Spatial AoE Settings")
@export var shape_type: SpatialShape = SpatialShape.CIRCLE_AROUND_TARGET
@export var base_radius_or_width: float = 2.5
@export var base_length: float = 6.0
@export var boost_aoe_scale_per_level: float = 0.25 # +25% AoE footprint per BP

## Computes total damage dealt to a specific target.
func calculate_damage(
	casters: Array[Node],
	target_stats: Node,
	boost_level: int,
	shield_eval_multiplier: float
) -> int:
	var combined_atk: float = 0.0
	for caster in casters:
		if uses_elemental_attack:
			combined_atk += caster.get("elemental_attack")
		else:
			combined_atk += caster.get("physical_attack")

	var target_def: float = (
		target_stats.get("elemental_defense")
		if uses_elemental_attack
		else target_stats.get("physical_defense")
	)

	# Octopath Traveler core formula: 0.8 * (Atk - Def * 0.5)
	var raw_stat_delta: float = maxf(1.0, combined_atk - (target_def * 0.5))
	var boost_mult: float = 1.0 + (boost_bonus_per_level * float(boost_level))

	var total_damage: float = (
		0.8
		* raw_stat_delta
		* base_multiplier
		* synergy_multiplier
		* boost_mult
		* shield_eval_multiplier
	)
	return maxi(1, roundi(total_damage))
```

## 3D Spatial Targeting Evaluates Line, Circle, and Cone Hits on the Live Map

In [*Chrono Trigger*](https://en.wikipedia.org/wiki/Chrono_Trigger), lining up enemies between Crono and a distant target makes *Slash* or *Lightning 2* hit every monster along the path, while *Cyclone* hits enemies clustered around the target. In Godot 4, `TacticalPositioner3D` uses [`ShapeCast3D`](https://docs.godotengine.org/en/stable/classes/class_shapecast3d.html) to query live 3D enemy colliders instantaneously (`force_shapecast_update()`) and dynamically scales the query volume based on the player's selected Boost level (`0–3 BP`):

```gdscript
# TacticalPositioner3D.gd
class_name TacticalPositioner3D
extends Node3D

@onready var shape_cast: ShapeCast3D = $ShapeCast3D
@onready var aoe_decal_mesh: MeshInstance3D = $AoEDecalPreview

## Queries all EnemyActor nodes caught inside the Tech's Boost-scaled 3D geometry.
func get_targets_in_tech_aoe(
	tech: TechResource,
	primary_caster: Node3D,
	primary_target: Node3D,
	boost_level: int
) -> Array[Node3D]:
	var scale_factor: float = 1.0 + (tech.boost_aoe_scale_per_level * float(boost_level))
	var effective_radius: float = tech.base_radius_or_width * scale_factor
	var effective_length: float = tech.base_length * scale_factor

	match tech.shape_type:
		TechResource.SpatialShape.SINGLE_TARGET:
			return [primary_target]

		TechResource.SpatialShape.CIRCLE_AROUND_TARGET:
			var sphere := SphereShape3D.new()
			sphere.radius = effective_radius
			shape_cast.shape = sphere
			shape_cast.global_position = primary_target.global_position
			shape_cast.target_position = Vector3.ZERO

		TechResource.SpatialShape.SELF_AURA:
			var sphere := SphereShape3D.new()
			sphere.radius = effective_radius
			shape_cast.shape = sphere
			shape_cast.global_position = primary_caster.global_position
			shape_cast.target_position = Vector3.ZERO

		TechResource.SpatialShape.LINE_PIERCE:
			# Sweeps a box from the primary caster through the primary target
			var box := BoxShape3D.new()
			box.size = Vector3(effective_radius, 2.0, 0.5)
			shape_cast.shape = box
			shape_cast.global_position = primary_caster.global_position
			var dir: Vector3 = (primary_target.global_position - primary_caster.global_position).normalized()
			dir.y = 0.0
			shape_cast.look_at(primary_caster.global_position + dir, Vector3.UP)
			shape_cast.target_position = Vector3(0.0, 0.0, -effective_length)

	shape_cast.force_shapecast_update()
	var hit_enemies: Array[Node3D] = []
	for i in range(shape_cast.get_collision_count()):
		var collider := shape_cast.get_collider(i) as Node3D
		if collider and collider.is_in_group("enemies") and not hit_enemies.has(collider):
			hit_enemies.append(collider)

	return hit_enemies
```

## Seamless Battle Coordinator Manages Sync Hold Queues and Co-Op Choreography

The `HybridBattleCoordinator` orchestrates the transition from exploration to combat, ticks the timeline, manages the **Sync Hold** pool for Dual/Triple Techs, and drives [`NavigationAgent3D`](https://docs.godotengine.org/en/stable/classes/class_navigationagent3d.html) movement so characters physically dash to convergence points on the map before unleashing a Boosted Dual Tech:

```gdscript
# HybridBattleCoordinator.gd
class_name HybridBattleCoordinator
extends Node

signal combat_started(arena_center: Vector3)
signal actor_ready_for_command(actor: Node3D, available_dual_techs: Array[TechResource])
signal sync_hold_updated(held_actors: Array[Node3D])
signal tech_executed(tech: TechResource, casters: Array[Node3D], boost_level: int)
signal combat_ended(victory: bool)

enum BattleState { EXPLORATION, TRANSITION_IN, TIMELINE_TICK, COMMAND_WAIT, EXECUTING_ACTION }

@export var camera_3d: Camera3D
@export var world_env: WorldEnvironment
@export var all_known_techs: Array[TechResource] = []

var state: BattleState = BattleState.EXPLORATION
var active_party: Array[Node3D] = []
var active_enemies: Array[Node3D] = []
var sync_hold_pool: Array[Node3D] = [] # Allies waiting at full gauge to combine Techs
var action_gauges: Dictionary = {}     # Node3D -> float (0.0 to 100.0)

## 1. Triggered when the player touches an EncounterZone Area3D on the overworld map.
func start_seamless_encounter(encounter_area: Area3D, enemies: Array[Node3D]) -> void:
	if state != BattleState.EXPLORATION:
		return
	state = BattleState.TRANSITION_IN
	active_enemies = enemies
	sync_hold_pool.clear()

	# Narrow Camera3D FOV for Octopath diorama framing without leaving the map
	var tween := create_tween().set_parallel(true)
	if camera_3d:
		tween.tween_property(camera_3d, "fov", 24.0, 0.45).set_trans(Tween.TRANS_CUBIC)

	# Fan party members out around the encounter center using NavigationAgent3D
	var center: Vector3 = encounter_area.global_position
	for i in range(active_party.size()):
		var ally: Node3D = active_party[i]
		action_gauges[ally] = randf_range(20.0, 50.0)
		var angle: float = PI + (float(i - 1) * 0.55)
		var anchor: Vector3 = center + Vector3(cos(angle) * 4.0, 0.0, sin(angle) * 4.0)
		var nav := ally.get_node_or_null("NavigationAgent3D") as NavigationAgent3D
		if nav:
			nav.target_position = anchor

	for enemy in active_enemies:
		action_gauges[enemy] = randf_range(0.0, 40.0)
		var shield := enemy.get_node_or_null("ShieldComponent") as ShieldComponent
		if shield and not shield.broken.is_connected(_on_enemy_broken.bind(enemy)):
			shield.broken.connect(_on_enemy_broken.bind(enemy))

	await tween.finished
	combat_started.emit(center)
	state = BattleState.TIMELINE_TICK

func _physics_process(delta: float) -> void:
	if state != BattleState.TIMELINE_TICK:
		return

	# Tick all non-broken combatants along the timeline
	var all_units: Array[Node3D] = []
	all_units.append_array(active_party)
	all_units.append_array(active_enemies)

	for unit in all_units:
		if sync_hold_pool.has(unit):
			continue
		var shield := unit.get_node_or_null("ShieldComponent") as ShieldComponent
		if shield and shield.is_broken:
			# Broken enemies slowly fill recovery gauge; when full, they unbreak and act immediately
			action_gauges[unit] += 18.0 * delta
			if action_gauges[unit] >= 100.0:
				shield.recover_from_break()
				_begin_unit_turn(unit)
				return
			continue

		var stats := unit.get_node_or_null("CombatantStats")
		var speed: float = stats.get("speed") if stats else 25.0
		action_gauges[unit] += speed * delta

		# Subtle Chrono Trigger battlefield drift for non-broken enemies
		if unit in active_enemies:
			_update_enemy_tactical_drift(unit, delta)

		if action_gauges[unit] >= 100.0:
			_begin_unit_turn(unit)
			return

func _begin_unit_turn(unit: Node3D) -> void:
	state = BattleState.COMMAND_WAIT
	var boost_comp := unit.get_node_or_null("BoostComponent") as BoostComponent
	if boost_comp:
		boost_comp.on_turn_start()

	if unit in active_party:
		if not sync_hold_pool.has(unit):
			sync_hold_pool.append(unit)
		var available_coops: Array[TechResource] = _get_available_coop_techs(unit)
		actor_ready_for_command.emit(unit, available_coops)
	else:
		_execute_enemy_turn(unit)

## Allows a ready character to wait in the Ready Pool so a partner can catch up for a Dual/Triple Tech.
func command_sync_hold(actor: Node3D) -> void:
	if not sync_hold_pool.has(actor):
		sync_hold_pool.append(actor)
	# Keep gauge at 99.0 so another ally can cross 100.0 while this ally stays ready
	action_gauges[actor] = 99.0
	sync_hold_updated.emit(sync_hold_pool)
	state = BattleState.TIMELINE_TICK

## Executes a Single, Dual, or Triple Tech with Pooled Boost and 3D AoE evaluation.
func execute_tech_command(
	tech: TechResource,
	primary_caster: Node3D,
	primary_target: Node3D,
	requested_boost_level: int
) -> void:
	state = BattleState.EXECUTING_ACTION

	var casters: Array[Node3D] = _resolve_casters_for_tech(tech)
	var boost_comps: Array[BoostComponent] = []
	for c in casters:
		var bc := c.get_node_or_null("BoostComponent") as BoostComponent
		if bc:
			boost_comps.append(bc)

	var boost_plan: Dictionary = BoostComponent.allocate_coop_boost(boost_comps, requested_boost_level)
	var effective_boost: int = boost_plan["effective_boost_level"]
	var allocation: Dictionary = boost_plan["allocation"]
	for bc in allocation.keys():
		bc.commit_spend(allocation[bc])

	# HD-2D Max Boost atmosphere darkening
	if effective_boost >= 2 and world_env and world_env.environment:
		var env_tween := create_tween()
		env_tween.tween_property(world_env.environment, "tonemap_exposure", 0.55, 0.2)

	var positioner := primary_caster.get_node("TacticalPositioner3D") as TacticalPositioner3D
	var hit_targets: Array[Node3D] = positioner.get_targets_in_tech_aoe(
		tech, primary_caster, primary_target, effective_boost
	)

	var bonus_shave: int = 1 if effective_boost == 3 else 0
	for target in hit_targets:
		var shield := target.get_node_or_null("ShieldComponent") as ShieldComponent
		var target_stats := target.get_node_or_null("CombatantStats")
		var eval_res: Dictionary = shield.evaluate_incoming_hit(
			tech.damage_tags, tech.hit_count, bonus_shave, primary_caster
		)
		var dmg: int = tech.calculate_damage(
			casters, target_stats, effective_boost, eval_res["damage_multiplier"]
		)
		if target_stats and target_stats.has_method("apply_damage"):
			target_stats.apply_damage(dmg)

	# Reset gauges and remove all participating casters from the Sync Hold pool
	for c in casters:
		action_gauges[c] = 0.0
		sync_hold_pool.erase(c)

	if world_env and world_env.environment:
		var restore_tween := create_tween()
		restore_tween.tween_property(world_env.environment, "tonemap_exposure", 1.0, 0.25)

	tech_executed.emit(tech, casters, effective_boost)
	state = BattleState.TIMELINE_TICK

func _on_enemy_broken(_breaker: Node3D, enemy: Node3D) -> void:
	# Freeze enemy NavigationAgent3D in place so they cannot drift out of Dual Tech AoEs
	var nav := enemy.get_node_or_null("NavigationAgent3D") as NavigationAgent3D
	if nav:
		nav.target_position = enemy.global_position
	# Reset enemy gauge to 0 so they lose their current round and recover next cycle
	action_gauges[enemy] = 0.0

func _get_available_coop_techs(active_actor: Node3D) -> Array[TechResource]:
	var ready_ids: Array[StringName] = []
	for ally in sync_hold_pool:
		ready_ids.append(ally.name)
	var valid_techs: Array[TechResource] = []
	for tech in all_known_techs:
		var all_present: bool = true
		for req_id in tech.required_actor_ids:
			if not ready_ids.has(req_id):
				all_present = false
				break
		if all_present:
			valid_techs.append(tech)
	return valid_techs

func _resolve_casters_for_tech(tech: TechResource) -> Array[Node3D]:
	var casters: Array[Node3D] = []
	for ally in active_party:
		if tech.required_actor_ids.has(ally.name):
			casters.append(ally)
	return casters

func _update_enemy_tactical_drift(_enemy: Node3D, _delta: float) -> void:
	pass

func _execute_enemy_turn(enemy: Node3D) -> void:
	action_gauges[enemy] = 0.0
	state = BattleState.TIMELINE_TICK
```

## Combat Loop Walkthrough Demonstrates Tactical Synergy in Action

To see how these mechanics interlock during a live encounter on a `600 AD` forest trail:

1. **Encounter Initiation (`0.0s`)**: Crono touches a scouting Goblin [`Area3D`](https://docs.godotengine.org/en/stable/classes/class_area3d.html). The map stays loaded; [`Camera3D`](https://docs.godotengine.org/en/stable/classes/class_camera3d.html) zooms smoothly from `32°` to `24°` FOV while Crono, Lucca, and Frog fan out to flanking coordinates via [`NavigationAgent3D`](https://docs.godotengine.org/en/stable/classes/class_navigationagent3d.html). The boss Ogre (`6 Shield Points`, weak to `[SWORD, FIRE, ICE]`) and two Imps (`2 Shield Points`, weak to `[SWORD, FIRE]`) begin drifting across the clearing.
2. **Turn 1 — Standard Attack Boost Shave & Sync Hold**: Crono reaches the Action Gate first with `2 BP`. Instead of spending BP immediately, the player selects **Sync Hold**, parking Crono in the Ready Pool while the Ogre steps between the two Imps.
3. **Turn 2 — Dual Tech Multi-Tag Break**: Lucca reaches the Action Gate (`+1 BP`, now holding `2 BP`). Because both Crono and Lucca are in the Ready Pool, **Fire Whirl** (`[SWORD, FIRE]`, `2 Hits`, Circle AoE) unlocks.
   - The player boosts **Fire Whirl** to **Lv. 2 (`2 BP` pooled: `1 BP` from Crono, `1 BP` from Lucca)**.
   - The Boost expands the [`ShapeCast3D`](https://docs.godotengine.org/en/stable/classes/class_shapecast3d.html) circle radius by `+50%` (`2.5m` → `3.75m`), catching the Ogre and both Imps in one ring.
   - Because the Ogre is weak to **both** `SWORD` and `FIRE`, each of the `2` hits shaves `2 Shield Points` (`4 Shield Points` shaved total, leaving the Ogre at `2/6` Shields), while both Imps shatter immediately (`0/2` Shields -> **BREAK!**) and freeze in place next to the Ogre.
4. **Turn 3 — Finisher on Broken Cluster**: Frog reaches the Action Gate holding `3 BP`. He spends `1 BP` (`2×` Sword strikes) to strip the Ogre's last `2` Shield Points, triggering a **Break** on the Ogre right beside the stunned Imps—setting up a `2.0x` Break damage window on the next cycle.
