// Billboard sprite material for every character (Reference Bible §1.7): nearest sampling, hard alpha,
// lit by the scene, quantised canvas drift, optional normal/mask sheets and the shared porcelain states
// (crack veins, galaxy interior, kintsugi gold). A character keeps this material in every universe.
shader_type spatial;
render_mode cull_disabled, depth_draw_opaque, specular_disabled;

uniform sampler2D sheet : source_color, filter_nearest, repeat_disable;
uniform sampler2D sheet_normal : hint_normal, filter_nearest, repeat_disable;
uniform sampler2D sheet_mask : hint_default_black, filter_nearest, repeat_disable;
uniform samplerCube galaxy : hint_default_black;
uniform sampler2D crack_noise : hint_default_black, filter_linear, repeat_enable;
uniform bool use_normal = false;
uniform bool use_mask = false;
uniform vec4 frame_rect = vec4(0.0, 0.0, 1.0, 1.0);
uniform float canvas_fps = 60.0;
uniform float wobble_px = 0.0;
uniform vec2 sheet_px = vec2(1024.0, 512.0);
uniform bool billboard_y = true;
uniform bool flip_h = false;
uniform vec4 tint : source_color = vec4(1.0);
uniform float emission_strength = 0.0;
uniform float opacity = 1.0;
// Porcelain (0 none, 1 pristine, 2 hairline, 3 galaxy, 4 flatline). crack_amount 0..1 drives veins.
uniform int porcelain_state = 0;
uniform float crack_amount = 0.0;
uniform float kintsugi = 0.0;
uniform vec4 crack_gold : source_color = vec4(0.83, 0.69, 0.22, 1.0);
uniform vec4 moss_fill : source_color = vec4(0.45, 0.51, 0.29, 1.0);
uniform float moss_amount = 0.0;
uniform float seed = 0.0;
uniform float rim_strength = 0.25;
uniform vec4 rim_color : source_color = vec4(1.0, 0.96, 0.9, 1.0);

varying vec3 world_n;
varying vec2 cell_uv;

void vertex() {
	if (billboard_y) {
		vec3 right = normalize(cross(vec3(0.0, 1.0, 0.0), INV_VIEW_MATRIX[2].xyz));
		vec3 fwd = normalize(cross(right, vec3(0.0, 1.0, 0.0)));
		MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
			vec4(right * length(MODEL_MATRIX[0].xyz), 0.0),
			vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0),
			vec4(fwd * length(MODEL_MATRIX[2].xyz), 0.0),
			MODEL_MATRIX[3]);
		MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
	}
	cell_uv = UV;
}

float hash1(float n) { return fract(sin(n) * 43758.5453); }

void fragment() {
	float qt = floor(TIME * canvas_fps) / canvas_fps;
	vec2 j = vec2(hash1(qt * 91.7 + seed), hash1(qt * 47.3 + seed)) - 0.5;
	vec2 uv = cell_uv;
	if (flip_h) { uv.x = 1.0 - uv.x; }
	vec2 suv = frame_rect.xy + uv * frame_rect.zw + j * wobble_px / sheet_px;
	vec4 c = texture(sheet, suv);
	if (c.a < 0.5) { discard; }
	vec3 albedo = c.rgb * tint.rgb;
	vec3 emission = albedo * emission_strength;
	float alpha = opacity;

	// Porcelain states: hairline gold veins, the galaxy interior showing through the worst cracks.
	if (porcelain_state >= 2) {
		vec2 cuv = cell_uv * 2.0 + vec2(seed * 0.37, seed * 0.11);
		float n = texture(crack_noise, cuv).r;
		float vein = smoothstep(1.0 - crack_amount * 0.9, 1.0, n);
		vec3 vein_col = mix(vec3(0.85, 0.82, 0.78), crack_gold.rgb, clamp(kintsugi, 0.0, 1.0));
		albedo = mix(albedo, vein_col, vein * 0.9);
		emission += crack_gold.rgb * vein * kintsugi * 0.6;
		if (porcelain_state >= 3) {
			// Where the mask marks the chest and wrist (R) or where veins are widest, the shell opens on stars.
			float open = smoothstep(1.0 - crack_amount * 0.5, 1.0, n);
			if (use_mask) { open = max(open, texture(sheet_mask, suv).r * crack_amount); }
			vec3 dir = normalize(vec3(cell_uv - 0.5, 0.6));
			vec3 stars = texture(galaxy, dir + vec3(sin(TIME * 0.1), cos(TIME * 0.07), 0.0) * 0.2).rgb;
			albedo = mix(albedo, stars * 0.6, open);
			emission += stars * open * 1.6;
		}
		albedo = mix(albedo, moss_fill.rgb, vein * moss_amount);
	}
	ALBEDO = albedo;
	EMISSION = emission;
	ALPHA = alpha;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	ROUGHNESS = 0.9;
	METALLIC = 0.0;
	if (use_normal) { NORMAL_MAP = texture(sheet_normal, suv).rgb; }
	// A soft rim so the silhouette lifts off the backdrop (HD-2D light on paper).
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.0);
	EMISSION += rim_color.rgb * rim * rim_strength * 0.15;
}
