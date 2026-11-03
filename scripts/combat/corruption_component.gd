## Krona's Corruption (Combat Laws Bible §10.3): persistent, 0-100, the crack climbing her neck. +5 per gourd sip
## (the automatic one and the command), +10 per Crimson Seppuku. Like Crono's integrity and Sera's Debt it is
## Game's between battles: CombatActor.create_party_member seeds it from Game.krona_corruption, Game follows it
## during a battle and BattleAftermath.write_back writes it back (§18.5: Corruption is save data). The thresholds
## (50: +10% RUIN damage and -10% healing received; 100: only the gourd heals her) and the Goyama clear wait for
## Krona's Chapter 2 fights (data/effects/effects.json `handler_unbuilt`).
class_name CorruptionComponent
extends Node

signal corruption_changed(value: float)

const MAX := 100.0
const GOURD_SIP := 5.0
const SEPPUKU := 10.0

@export var value: float = 0.0


func add(n: float) -> void:
	var before: float = value
	value = clampf(value + n, 0.0, MAX)
	if value != before:
		corruption_changed.emit(value)


static func of(actor: Node) -> CorruptionComponent:
	if actor == null:
		return null
	return actor.get_node_or_null("CorruptionComponent") as CorruptionComponent


## Add `n` to `actor`'s Corruption; a body without the component (not Krona) is left alone.
static func add_to(actor: Node, n: float) -> void:
	var cc := of(actor)
	if cc != null:
		cc.add(n)
