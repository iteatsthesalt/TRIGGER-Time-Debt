## Helpers to build textured primitives at the game's 64 px/m density (Reference Bible §1.2), used by
## the diorama and by the location builders until the Blender kits arrive.
class_name SceneKit
extends RefCounted

const TILE_M := 16.0  # a 1024 px texture covers 16 m at 64 px/m
## Where imported textures land (docs/ART_PIPELINE.md §6): <material>_albedo.png + _normal.png.
const GENERATED_DIR := "res://assets/textures/generated"
## Placeholder materials by name until the generated ones exist.
const PLACEHOLDER_BY_NAME := {
	"castle_flagstone": "stone_mossy", "castle_wall_block": "castle_wall", "oak_plank": "wood", "oak_beam": "wood",
	"stone_steps": "stone_mossy", "cobble_wet": "stone_mossy", "plaster_cream": "castle_wall",
}

static var _mat_cache: Dictionary = {}


## A material by material name: the generated texture pair when it exists, else the named placeholder in
## assets/textures/. Triplanar by default so kits and primitives share one 64 px/m density.
static func named(material_name: String, roughness: float = 0.95, tint: Color = Color.WHITE, triplanar: bool = true) -> StandardMaterial3D:
	var albedo: String = "%s/%s_albedo.png" % [GENERATED_DIR, material_name]
	var normal: String = "%s/%s_normal.png" % [GENERATED_DIR, material_name]
	if not ResourceLoader.exists(albedo):
		var fallback: String = String(PLACEHOLDER_BY_NAME.get(material_name, material_name))
		albedo = "res://assets/textures/%s_albedo.png" % fallback
		normal = "res://assets/textures/%s_normal.png" % fallback
		if not ResourceLoader.exists(normal):
			normal = "res://assets/textures/stone_normal.png"
	return material(albedo, normal, roughness, tint, triplanar)


static func material(albedo_path: String, normal_path: String = "", roughness: float = 0.95, tint: Color = Color.WHITE, triplanar: bool = false) -> StandardMaterial3D:
	var key: String = "%s|%s|%.2f|%s|%s" % [albedo_path, normal_path, roughness, tint.to_html(), str(triplanar)]
	if _mat_cache.has(key):
		return _mat_cache[key]
	var m := StandardMaterial3D.new()
	if albedo_path != "" and ResourceLoader.exists(albedo_path):
		m.albedo_texture = load(albedo_path)
	m.albedo_color = tint
	if normal_path != "" and ResourceLoader.exists(normal_path):
		m.normal_enabled = true
		m.normal_texture = load(normal_path)
		m.normal_scale = 0.8
	m.roughness = roughness
	m.metallic = 0.0
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	m.uv1_triplanar = triplanar
	m.uv1_world_triplanar = triplanar
	if triplanar:
		m.uv1_scale = Vector3.ONE * (1.0 / TILE_M)
	_mat_cache[key] = m
	return m


static func box(parent: Node, size: Vector3, pos: Vector3, mat: Material, name: String = "Box", collide: bool = true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = name
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	if mat is StandardMaterial3D and not (mat as StandardMaterial3D).uv1_triplanar:
		(bm as BoxMesh).material = null
		# scale UVs by the largest face so texels stay 64 px/m
		var sm := (mat as StandardMaterial3D).duplicate() as StandardMaterial3D
		sm.uv1_scale = Vector3(maxf(size.x, size.z) / TILE_M, size.y / TILE_M, 1.0)
		mi.material_override = sm
	if collide:
		var sb := StaticBody3D.new()
		sb.collision_layer = 1
		var cs := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		cs.shape = shape
		sb.add_child(cs)
		mi.add_child(sb)
	return mi


static func floor_plane(parent: Node, size: Vector2, pos: Vector3, mat: Material, name: String = "Floor") -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = name
	var pm := PlaneMesh.new()
	pm.size = size
	pm.subdivide_width = 7
	pm.subdivide_depth = 7
	mi.mesh = pm
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	var sb := StaticBody3D.new()
	sb.collision_layer = 1
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(size.x, 0.2, size.y)
	cs.shape = shape
	cs.position = Vector3(0, -0.1, 0)
	sb.add_child(cs)
	mi.add_child(sb)
	return mi


static func cylinder(parent: Node, radius: float, height: float, pos: Vector3, mat: Material, name: String = "Cyl", collide: bool = true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = name
	var cm := CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = height
	cm.radial_segments = 16
	mi.mesh = cm
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	if collide:
		var sb := StaticBody3D.new()
		sb.collision_layer = 1
		var cs := CollisionShape3D.new()
		var shape := CylinderShape3D.new()
		shape.radius = radius
		shape.height = height
		cs.shape = shape
		sb.add_child(cs)
		mi.add_child(sb)
	return mi


static func flat_color(color: Color, emission: Color = Color.BLACK, emission_energy: float = 0.0, roughness: float = 0.8, metallic: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	m.metallic = metallic
	if emission_energy > 0.0:
		m.emission_enabled = true
		m.emission = emission
		m.emission_energy_multiplier = emission_energy
	return m


static func omni(parent: Node, pos: Vector3, color: Color, energy: float, range_m: float, shadows: bool = false) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.position = pos
	l.light_color = color
	l.light_energy = energy
	l.omni_range = range_m
	l.omni_attenuation = 1.4
	l.shadow_enabled = shadows
	parent.add_child(l)
	return l


static func marker(parent: Node, name: String, pos: Vector3) -> Marker3D:
	var m := Marker3D.new()
	m.name = name
	m.position = pos
	parent.add_child(m)
	return m
