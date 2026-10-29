// AoE floor preview and enemy telegraph (Combat Laws §8.5): cyan while readable, orange on commit,
// with an inward scan wave. Ported from the prototype.
// shape_mode: 0 = circle ring, 1 = line beam, 2 = cone
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;

uniform vec4 base_color : source_color = vec4(0.25, 0.85, 1.0, 0.65);
uniform vec4 max_boost_color : source_color = vec4(1.0, 0.65, 0.15, 0.85);
uniform float boost_ratio : hint_range(0.0, 1.0) = 0.0;
uniform int shape_mode = 0;
uniform float cone_half_angle = 0.61; // radians

void fragment() {
	vec2 c = UV * 2.0 - 1.0;
	vec4 col = mix(base_color, max_boost_color, boost_ratio);
	float pulse = 0.85 + 0.15 * sin(TIME * 6.0);
	float a = 0.0;

	if (shape_mode == 0) {
		float d = length(c);
		float ring = smoothstep(0.90, 0.97, d) * (1.0 - smoothstep(0.97, 1.0, d));
		float fill = (1.0 - smoothstep(0.0, 0.97, d)) * 0.22;
		float scan = smoothstep(0.04, 0.0, abs(fract(d * 2.0 - TIME * 1.5) - 0.5)) * 0.25 * step(d, 0.97);
		a = ring * 1.4 + fill + scan;
	} else if (shape_mode == 1) {
		float ex = abs(c.x);
		float border = smoothstep(0.82, 0.96, ex) * (1.0 - smoothstep(0.96, 1.0, ex));
		float scroll = smoothstep(0.08, 0.0, abs(fract(UV.y * 3.0 + TIME * 2.5) - 0.5)) * 0.35;
		a = border * 1.3 + 0.20 + scroll;
	} else {
		// Cone apex at UV (0.5, 1.0) pointing toward UV.y = 0 (-Z in mesh space).
		vec2 p = vec2(c.x, -(c.y - 1.0) * 0.5) ; // p.y in 0..1 forward
		float d = length(p);
		float ang = abs(atan(p.x, max(p.y, 1e-4)));
		float inside = step(ang, cone_half_angle) * step(d, 1.0);
		float edge = smoothstep(cone_half_angle - 0.06, cone_half_angle, ang) + smoothstep(0.94, 1.0, d);
		a = inside * (0.22 + clamp(edge, 0.0, 1.0) * 1.2);
	}
	ALBEDO = col.rgb * pulse;
	ALPHA = clamp(a * col.a, 0.0, 1.0);
}
