## Canonical combat constants (Combat Laws Bible §18.3). Every value is a starting point to tune.
class_name CombatConstants
extends RefCounted

const PLANE_SIZE := 28.0
const PLANE_SUBDIVIDE := 17  # 18 x 18 quads = 648 triangles
const TACTICAL_PITCH_DEG := 35.0
const FOV_EXPLORE := 32.0
const FOV_TRUTH := 24.0
const FOV_LERP_S := 0.45
const DOF_FAR := 12.0
const DOF_NEAR := 0.05

const GAUGE_MAX := 100.0
const SYNC_HOLD := 99.0
const ENEMY_GATE := 100.0
const SPD_TO_GAUGE := 0.25
const DRIFT_AMPLITUDE := 0.5
const PARTY_START_GAUGE := Vector2(20.0, 50.0)
const ENEMY_START_GAUGE := Vector2(0.0, 40.0)
const PREEMPT_START := Vector2(30.0, 50.0)

const BOOST_LV3_SHAVE_BONUS := 1
const STATE_NORMAL := 1.0
const STATE_LV3 := 1.3
const STATE_WEAK := 2.0
const STATE_WEAK_LV3 := 2.6
const CRIT_MULT := 1.5
const BREAK_DEF_MULT := 0.5
const BREAK_LOCK_S := 3.0
const SHIELD_REBUILD_PCT_PER_S := 18.0
const BREAK_HULL_INFLATION := 0.12
const BREAK_RESUME_BLEND_S := 0.4
const BROKEN_STATUE_S := 8.0
const RESIST_MULT := 0.5
const PERFECT_FRAME_MULT := 1.15
const AOE_FALLOFF: Array[float] = [1.0, 0.75, 0.5, 0.25]
const VARIANCE_MIN := 0.95
const VARIANCE_MAX := 1.05
const LEDGE_BONUS := 0.10
const HOME_CANVAS_BONUS := 0.10
const SERA_FLICKER_BONUS := 0.20

const START_BP := 1
const MAX_BP := 5
const MAX_BP_UPGRADED := 6
const MAX_SPEND := 3
const MAX_SPEND_UPGRADED := 4
const BOOST_POWER: Array[float] = [1.0, 1.9, 2.8, 3.7, 4.5]
const BOOST_SCALE: Array[float] = [1.0, 1.25, 1.5, 1.75, 2.0]
const BOOST_FIELD_DAMPEN := 0.90
const RESIDUAL_FIELD_S := 6.0

const SYNERGY_SOLO := 1.0
const SYNERGY_DUAL := 1.6
const SYNERGY_TRIPLE := 2.2
const SYNERGY_THREE_UNIVERSES := 1.25
const SYNERGY_CRONO_KRONA := 1.15
const SYNERGY_CRONO_SERA := 0.95
const SYNERGY_VAELOS_CHILD := 0.85
const PARTY_SYNERGY_SERA := 1.10
const PARTY_SYNERGY_PHASED := 0.85
const PARTY_SYNERGY_ABSENT := 1.00

const SERA_REWIND_COST := 5.0
const SERA_HOLD_STEP := 5.0
const SERA_HOLD_BREAK_EXTENSION_S := 2.5
const SERA_HOLD_BREAK_EXTENSION_UPGRADED_S := 3.0
const SERA_BORROWED_FUTURE_COST := 10.0
const SERA_PHASE_THRESHOLD := 40.0
const SERA_PHASE_TURNS := 2
const SERA_THRESHOLDS: Array[float] = [80.0, 60.0, 40.0, 20.0]
const SERA_DEBT_CAP := 55.0
const SERA_DEBT_PER_JUMP := 5.0
const SERA_TURN_REGEN := 2.0
const SERA_HEART_SOLIDITY := 60.0
const BORROWED_FUTURE_GAUGE_PUSH := 0.30
const VOLUNTARY_HOLD_S := 3.0

const CRONO_JUMP_COLLARBONE := 0.4
const CRONO_HAIRLINE_REWIND_HP := 0.05
const CRONO_DEFEAT_INTEGRITY := 5.0
const CRONO_CEILING_FLOOR := 0.10
const CRONO_STRAIN_INTEREST_STEP := 0.20
const REINFORCED_REDUCTION := 0.5
const REINFORCED_FAMILY := 0.8
const CRONO_HEART_ASTRAL_COST := 1.2

const RUIN_STACK := 0.15
const RUIN_STACK_CAP := 3
const RUIN_STACK_CAP_SILENCE := 10
const OIL_BLIGHT_PERIOD_S := 15.0
const MERCURY_SLOW := 0.5
const MERCURY_MAX_STACKS := 2
const CHRONO_LAG := 0.75
const HEAVY_DRIFT := 0.85
const BLIND_ACCURACY := -0.30
const GRIEF_MP := 2
const GRIEF_PERIOD_S := 10.0
const GRIEF_MAX_STACKS := 3
const DIVINITY_PERIOD_S := 5.0
const DIVINITY_CAP := 0.20
const DIVINITY_RUIN_THAW := 0.01
const DIVINITY_THAW_PERIOD_S := 8.0
const MYCELIA_SHARE := 0.15
const MYCELIA_SHARED_POOL := 12
const LIGHT_STACK_CAP := 5
const PHOTOSYNTHETIC_DR := 0.70
const PROMETHEUS_REVIVE_HP := 0.20
const PROMETHEUS_CORE_BECKONS := 150
const PROMETHEUS_CORE_BECKONS_SEED := 120
const GLENN_STEAL: Array[int] = [1, 1, 2, 3, 3]
const TELEGRAPH_PULSE_HZ := 6.0

const ENS_PARRY_FRAMES_BASE := 4
const ENS_PARRY_FRAMES_TAUGHT := 6
const ENS_PARRY_FRAMES_DOJO := 8
const ENS_RING_DEBT_NULL_S := 5.0
const GUARD_DAMAGE_MULT := 0.5
const GUARD_NEXT_GAUGE := 20.0
const SWAP_GAUGE := 50.0
const SPARE_HP_PCT := 0.25
const WITHDRAW_MAX_ENEMY_GAUGE := 80.0

# Affinity (§15.9)
const AFF_MERCY := 30
const AFF_RUTHLESS := 25
const AFF_RIFT := 15
const AFF_LEAN_CAP_PER_UNIVERSE := 5

# Progression (§15.2)
static func xp_to_next(level: int) -> int:
	return 10 * level * level + 10 * level


static func xp_for_enemy(level: int, kind: String = "regular") -> int:
	var base: float = 0.6 * float(level * level) + 10.0
	match kind:
		"elite":
			return roundi(base * 3.0)
		"miniboss":
			return roundi(base * 10.0)
		"boss":
			return roundi(base * 20.0)
	return roundi(base)
