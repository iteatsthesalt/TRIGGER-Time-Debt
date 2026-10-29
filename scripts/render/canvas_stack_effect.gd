@tool
## The canvas stack as one CompositorEffect (Reference Bible §1.7). Reads the UniverseSwitcher's
## weights and grades, copies the colour buffer to a scratch image, then grades it in place.
class_name CanvasStackEffect
extends CompositorEffect

const SHADER_PATH := "res://shaders/compositor/canvas_stack.glsl"
const CONTEXT := &"canvas_stack"
const SCRATCH := &"scratch"
const U_BASE := 16
const U_STRIDE := 16
const FLOATS := U_BASE + 10 * U_STRIDE

## Weights for U0..U9 (set by the UniverseSwitcher each frame; defaults to U0).
@export var weights := PackedFloat32Array([1, 0, 0, 0, 0, 0, 0, 0, 0, 0])
@export_range(0.0, 1.0) var strength: float = 1.0
@export_range(0.0, 1.0) var debt: float = 0.0
@export_range(0.0, 1.0) var vaelos_near: float = 0.0
@export var reduced_flicker: bool = false

var rd: RenderingDevice
var shader: RID
var pipeline: RID
var param_buffer: RID
var _params := PackedFloat32Array()
var _ready: bool = false

## Per-universe parameters (sat, paper rgb, paper amount, gold, edge, vhs, posterize, ink, edge rgb, scanline, chroma px, fps).
const GRADES := [
	[0.85, 0.96, 0.93, 0.86, 0.55, 0.15, 0.10, 0.00, 0.0, 0.00, 0.18, 0.17, 0.17, 0.0, 0.0, 60.0],   # U0 watercolour
	[0.20, 0.95, 0.93, 0.85, 0.65, 0.00, 0.75, 0.00, 0.0, 0.85, 0.10, 0.10, 0.10, 0.0, 0.0, 24.0],   # U1 sumi-e
	[0.72, 0.80, 0.72, 0.62, 0.45, 0.00, 0.25, 0.90, 0.0, 0.00, 0.17, 0.17, 0.17, 1.0, 2.0, 12.0],   # U2 clay + VHS
	[1.05, 0.98, 0.96, 0.93, 0.20, 0.00, 0.95, 0.00, 7.0, 0.00, 0.05, 0.05, 0.05, 0.0, 0.0, 30.0],   # U3 ligne claire
	[1.20, 0.85, 0.88, 0.92, 0.25, 0.10, 0.70, 0.00, 0.0, 0.00, 0.14, 0.14, 0.16, 0.0, 0.0, 60.0],   # U4 stained glass
	[0.30, 0.85, 0.79, 0.61, 0.70, 0.00, 0.55, 0.25, 5.0, 0.30, 0.08, 0.07, 0.06, 0.4, 0.0, 12.0],   # U5 rubber-hose
	[1.10, 0.75, 0.78, 0.88, 0.15, 0.00, 0.50, 0.80, 4.0, 0.00, 0.08, 0.08, 0.12, 1.0, 2.0, 15.0],   # U6 cel anime
	[0.60, 0.99, 0.98, 0.95, 0.75, 0.90, 0.35, 0.00, 0.0, 0.00, 0.23, 0.18, 0.12, 0.0, 0.0, 24.0],   # U7 gold leaf
	[0.90, 1.00, 1.00, 1.00, 0.40, 0.60, 0.30, 0.30, 0.0, 0.00, 0.20, 0.20, 0.20, 0.5, 1.0, 15.0],   # U8 porcelain null
	[0.00, 1.00, 1.00, 1.00, 0.95, 0.10, 0.00, 0.00, 0.0, 0.00, 0.20, 0.20, 0.20, 0.0, 0.0, 60.0],   # U9 white void
]


func _init() -> void:
	effect_callback_type = EFFECT_CALLBACK_TYPE_POST_TRANSPARENT
	access_resolved_color = true
	rd = RenderingServer.get_rendering_device()
	_params.resize(FLOATS)
	for u in 10:
		for i in U_STRIDE:
			_params[U_BASE + u * U_STRIDE + i] = float(GRADES[u][i])


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and rd != null:
		if shader.is_valid():
			rd.free_rid(shader)
		if param_buffer.is_valid():
			rd.free_rid(param_buffer)


func _ensure_pipeline() -> bool:
	if _ready:
		return pipeline.is_valid()
	_ready = true
	var file: RDShaderFile = load(SHADER_PATH) as RDShaderFile
	if file == null:
		push_error("CanvasStackEffect: cannot load %s" % SHADER_PATH)
		return false
	var spirv: RDShaderSPIRV = file.get_spirv()
	if spirv == null or spirv.compile_error_compute != "":
		push_error("CanvasStackEffect: %s" % (spirv.compile_error_compute if spirv else "no SPIR-V"))
		return false
	shader = rd.shader_create_from_spirv(spirv)
	if not shader.is_valid():
		return false
	pipeline = rd.compute_pipeline_create(shader)
	param_buffer = rd.storage_buffer_create(FLOATS * 4, _params.to_byte_array())
	return pipeline.is_valid()


func _render_callback(_type: int, render_data: RenderData) -> void:
	if rd == null or not _ensure_pipeline():
		return
	var buffers := render_data.get_render_scene_buffers() as RenderSceneBuffersRD
	if buffers == null:
		return
	var size: Vector2i = buffers.get_internal_size()
	if size.x <= 0 or size.y <= 0:
		return
	_params[0] = 1.0 if reduced_flicker else 0.0
	_params[1] = debt
	_params[2] = vaelos_near
	_params[3] = strength
	var total: float = 0.0
	for i in 10:
		total += weights[i] if i < weights.size() else 0.0
	for i in 10:
		var w: float = weights[i] if i < weights.size() else 0.0
		_params[4 + i] = (w / total) if total > 0.0 else (1.0 if i == 0 else 0.0)
	rd.buffer_update(param_buffer, 0, FLOATS * 4, _params.to_byte_array())

	if not buffers.has_texture(CONTEXT, SCRATCH):
		buffers.create_texture(CONTEXT, SCRATCH, RenderingDevice.DATA_FORMAT_R16G16B16A16_SFLOAT,
			RenderingDevice.TEXTURE_USAGE_STORAGE_BIT | RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT,
			RenderingDevice.TEXTURE_SAMPLES_1, size, buffers.get_view_count(), 1, true, false)
	var groups_x: int = int(ceil(float(size.x) / 8.0))
	var groups_y: int = int(ceil(float(size.y) / 8.0))
	var time_s: float = float(Time.get_ticks_msec()) / 1000.0
	for view in buffers.get_view_count():
		var color: RID = buffers.get_color_layer(view)
		var scratch: RID = buffers.get_texture_slice(CONTEXT, SCRATCH, view, 0, 1, 1)
		_dispatch(scratch, color, size, time_s, 0.0, groups_x, groups_y)
		_dispatch(color, scratch, size, time_s, 1.0, groups_x, groups_y)


func _dispatch(dst: RID, src: RID, size: Vector2i, time_s: float, mode: float, gx: int, gy: int) -> void:
	var u0 := RDUniform.new()
	u0.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	u0.binding = 0
	u0.add_id(dst)
	var u1 := RDUniform.new()
	u1.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	u1.binding = 1
	u1.add_id(src)
	var u2 := RDUniform.new()
	u2.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	u2.binding = 2
	u2.add_id(param_buffer)
	var uniform_set: RID = UniformSetCacheRD.get_cache(shader, 0, [u0, u1, u2])
	var push := PackedFloat32Array([float(size.x), float(size.y), time_s, mode])
	var list: int = rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(list, pipeline)
	rd.compute_list_bind_uniform_set(list, uniform_set, 0)
	rd.compute_list_set_push_constant(list, push.to_byte_array(), push.size() * 4)
	rd.compute_list_dispatch(list, gx, gy, 1)
	rd.compute_list_end()
