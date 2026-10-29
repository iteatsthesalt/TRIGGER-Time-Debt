// The battle plane overlay (Combat Laws Bible §2.1): a 28 × 28 m sheet settling over the ground with a soft
// edge, faint paper grain and a gold boundary line; `reveal` animates the spawn and the dissolve.
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, unshaded;

uniform float reveal : hint_range(0.0, 1.0) = 0.0;
uniform vec4 tint : source_color = vec4(0.96, 0.93, 0.86, 1.0);
uniform vec4 edge_color : source_color = vec4(0.83, 0.69, 0.22, 1.0);
uniform float edge_width = 0.03;
uniform float alpha_max = 0.09;

float hash12(vec2 p) { vec3 p3 = fract(vec3(p.xyx) * 0.1031); p3 += dot(p3, p3.yzx + 33.33); return fract((p3.x + p3.y) * p3.z); }

void fragment() {
	vec2 c = abs(UV - 0.5) * 2.0;
	float m = max(c.x, c.y);
	float inside = 1.0 - smoothstep(1.0 - edge_width * 2.0, 1.0, m);
	float edge = smoothstep(1.0 - edge_width * 2.0, 1.0 - edge_width, m) * (1.0 - smoothstep(1.0 - edge_width, 1.0, m));
	// reveal sweeps outward from the centre like water on paper
	float r = length(UV - 0.5) * 1.414;
	float wet = smoothstep(reveal, reveal - 0.12, r);
	float grain = hash12(floor(UV * 180.0)) * 0.08;
	vec3 col = mix(tint.rgb, edge_color.rgb, edge);
	ALBEDO = col;
	ALPHA = (inside * (alpha_max + grain) + edge * 0.9) * wet;
}
