## The Atrium's ring of eight universe gates (Story Bible §9.7, Reference Bible §3.2, plate-00): Nich's brass arch
## for each universe (a billboard, walked through to its interactable) with the universe's colour panel standing in
## its opening, bright once its Gate_U<n>_Open flag is set. Using an open gate jumps to its location when that is
## built and says so when it is not; a closed gate says it is closed.
class_name AtriumGateRing
extends RefCounted

const UNIVERSES := [1, 2, 3, 4, 5, 6, 7, 8]
const RADIUS := 11.2
const COLOURS := {
	1: Color(0.75, 0.33, 0.26), 2: Color(0.77, 0.54, 0.25), 3: Color(0.43, 0.62, 0.64), 4: Color(0.17, 0.3, 0.61),
	5: Color(0.78, 0.23, 0.2), 6: Color(0.0, 0.94, 1.0), 7: Color(0.83, 0.69, 0.22), 8: Color(0.55, 0.49, 1.0),
}
const LOCATIONS := {1: &"bamboo_grove", 2: &"proto_dome", 3: &"eden_canopy", 4: &"cathedral_nave", 5: &"carnival_midway", 6: &"neo_truce", 7: &"bone_tree_root", 8: &"vaelos_heart"}


## Build the ring on `loc`; returns universe -> its colour panel.
static func build(loc: Location) -> Dictionary:
	var panels: Dictionary = {}
	for u in UNIVERSES:
		var a: float = (float(UNIVERSES.find(u)) + 0.5) / 8.0 * TAU + PI * 0.5
		panels[u] = _build_gate(loc, u, Vector3(cos(a) * RADIUS, 0.0, sin(a) * RADIUS), a)
	return panels


static func is_open(u: int) -> bool:
	return Flags.has(StringName("Gate_U%d_Open" % u))


static func use(u: int) -> void:
	if not is_open(u):
		Story.run(&"atrium_gate_locked")
		return
	var to: StringName = LOCATIONS.get(u, &"")
	if Router.has_location(to):
		Audio.play_sfx("time/gate_open_u%d" % u)
		Router.go(to, &"start")
	else:
		Story.run(&"atrium_gate_unbuilt")


static func _build_gate(loc: Location, u: int, pos: Vector3, angle: float) -> MeshInstance3D:
	var holder := Node3D.new()
	holder.name = "Gate%d" % u
	holder.position = pos
	holder.rotation.y = -angle + PI * 0.5
	loc.add_child(holder)
	loc.add_prop(&"prp_u0_brass_gate_arch", pos)  # solid posts only (props.json footprint): the opening is walked through
	var unlocked: bool = is_open(u)
	var col: Color = COLOURS.get(u, Color.WHITE)
	var fill := SceneKit.flat_color(col * (0.9 if unlocked else 0.12), col, 2.0 if unlocked else 0.15, 0.3)
	fill.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	var panel := MeshInstance3D.new()
	panel.name = "Panel%d" % u
	var quad := QuadMesh.new()
	quad.size = Vector2(1.5, 2.9)
	panel.mesh = quad
	panel.material_override = fill
	panel.position = pos + Vector3(0.0, 1.5, -0.08)
	loc.add_child(panel)
	var it := Interactable.make(holder, "GateUse", Vector3(0, 0.8, 1.0), &"", "Gate: " + Universe.name_of(u), 1.1)
	it.callback = func(_by: Node) -> void: use(u)
	if unlocked:
		SceneKit.omni(holder, Vector3(0, 2.0, 1.0), col, 1.5, 6.0, false)
	return panel
