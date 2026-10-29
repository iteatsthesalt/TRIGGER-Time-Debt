## Overworld trigger for a seamless battle.
## Fix vs. doc: the Area3D also overlapped its own EnemyActor bodies, so
## body_entered fired for enemies. We filter to the party leader and fire once.
##
## Optional Marker3D layout, all children of the zone:
##   CameraPoint        the battle's focus (camera framing, arena centre)
##   PartyAnchors/*     battle spots for the leader, then each follower, in order
##   WanderNodes/*      where enemies may drift while gauges fill
## Without them the zone's own position is the focus and the party fans out around it.
class_name EncounterZone
extends Area3D

@export var coordinator: HybridBattleCoordinator
@export var party_group: StringName = &"party"
@export var leader_group: StringName = &"party_leader"
@export var one_shot: bool = true

var _triggered: bool = false

@onready var enemy_group: Node3D = $EnemyGroup


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func camera_point() -> Vector3:
	var marker := get_node_or_null("CameraPoint") as Node3D
	return marker.global_position if marker else global_position


func party_points() -> Array[Vector3]:
	return _marker_positions("PartyAnchors")


func wander_points() -> Array[Vector3]:
	return _marker_positions("WanderNodes")


func _marker_positions(group_name: String) -> Array[Vector3]:
	var out: Array[Vector3] = []
	var holder := get_node_or_null(group_name)
	if holder:
		for child in holder.get_children():
			if child is Node3D:
				out.append(child.global_position)
	return out


## Leader first, then the rest of the party in scene order, so anchor 0 is the leader's.
func _party() -> Array[Node3D]:
	var party: Array[Node3D] = []
	var lead := get_tree().get_first_node_in_group(leader_group) as Node3D
	if lead and lead.is_in_group(party_group):
		party.append(lead)
	for n in get_tree().get_nodes_in_group(party_group):
		if n is Node3D and n != lead:
			party.append(n)
	return party


func _on_body_entered(body: Node3D) -> void:
	if _triggered or coordinator == null or not body.is_in_group(leader_group):
		return
	_triggered = true
	set_deferred("monitoring", not one_shot)

	var enemies: Array[Node3D] = []
	for child in enemy_group.get_children():
		if child is Node3D and CombatantStats.of(child) != null:
			enemies.append(child)
	coordinator.start_encounter(_party(), enemies, camera_point(), party_points(), wander_points())
