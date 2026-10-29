#[compute]
#version 450

// The canvas stack (Reference Bible §1.7, §2.2): paper multiply → grade → edge/quantisation → VHS.
// One shader, two dispatches: mode 0 copies the colour buffer to a scratch image, mode 1 reads the
// scratch and writes the graded result back. Per-universe parameters are blended by the
// UniverseSwitcher weights so a Chronoslip is a continuous 0.8 s slide between looks.

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(rgba16f, set = 0, binding = 0) uniform image2D dst;
layout(rgba16f, set = 0, binding = 1) uniform image2D src;
layout(set = 0, binding = 2, std430) restrict readonly buffer Params { float data[]; } params;

layout(push_constant, std430) uniform PC {
	vec2 size;
	float time;
	float mode;
} pc;

// params layout: [0] reduced_flicker, [1] debt (paper show-through), [2] vaelos_near, [3] global strength,
// [4..13] weights for U0..U9, then per universe 16 floats from index 16 + u*16:
//   0 sat, 1 paper_r, 2 paper_g, 3 paper_b, 4 paper_amt, 5 gold, 6 edge, 7 vhs,
//   8 posterize_levels, 9 ink, 10 edge_r, 11 edge_g, 12 edge_b, 13 scanline, 14 chroma_px, 15 fps
const int U_BASE = 16;
const int U_STRIDE = 16;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash12(i);
	float b = hash12(i + vec2(1.0, 0.0));
	float c = hash12(i + vec2(0.0, 1.0));
	float d = hash12(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float luma(vec3 c) { return dot(c, vec3(0.299, 0.587, 0.114)); }

// The colour buffer is linear HDR before tonemapping; grade in a display-like space so the
// paper, ink and posterise thresholds mean what they say, then return to linear.
vec3 to_display(vec3 c) { return pow(c / (c + vec3(1.0)) * 1.9, vec3(1.0 / 2.2)); }
vec3 to_linear(vec3 d) { vec3 t = pow(clamp(d, vec3(0.0), vec3(0.999)), vec3(2.2)) / 1.9; return t / max(vec3(1e-4), vec3(1.0) - t); }

vec3 load(ivec2 p) {
	p = clamp(p, ivec2(0), ivec2(pc.size) - 1);
	return to_display(imageLoad(src, p).rgb);
}

float blended(int field) {
	float s = 0.0;
	for (int u = 0; u < 10; u++) {
		s += params.data[4 + u] * params.data[U_BASE + u * U_STRIDE + field];
	}
	return s;
}

void main() {
	ivec2 px = ivec2(gl_GlobalInvocationID.xy);
	if (px.x >= int(pc.size.x) || px.y >= int(pc.size.y)) { return; }
	if (pc.mode < 0.5) {
		imageStore(dst, px, imageLoad(src, px));
		return;
	}
	float reduced = params.data[0];
	float debt = params.data[1];
	float strength = params.data[3];
	float sat = blended(0);
	vec3 paper_tint = vec3(blended(1), blended(2), blended(3));
	float paper_amt = blended(4);
	float gold = blended(5);
	float edge_amt = blended(6);
	float vhs = blended(7);
	float post_levels = blended(8);
	float ink = blended(9);
	vec3 edge_col = vec3(blended(10), blended(11), blended(12));
	float scan = blended(13);
	float chroma_px = blended(14);
	float fps = max(1.0, blended(15));
	float qt = floor(pc.time * fps) / fps;
	if (reduced > 0.5) { qt = floor(pc.time * 2.0) / 2.0; }

	vec2 uv = (vec2(px) + 0.5) / pc.size;

	// VHS horizontal slip (quantised to the canvas rate) decides where we sample from.
	float slip = 0.0;
	if (vhs > 0.01 && reduced < 0.5) {
		float roll = step(0.93, hash12(vec2(qt * 7.1, floor(uv.y * 40.0))));
		slip = roll * (hash12(vec2(qt, uv.y)) - 0.5) * 6.0 * vhs;
	}
	ivec2 sp = px + ivec2(int(slip), 0);
	vec3 col = load(sp);
	if (chroma_px > 0.01) {
		int off = int(round(chroma_px * vhs));
		col.r = load(sp + ivec2(off, 0)).r;
		col.b = load(sp - ivec2(off, 0)).b;
	}

	// 1. Paper multiply: fibre noise at two scales, tinted per canvas; the Debt lets more paper through.
	float grain = vnoise(vec2(px) * 0.11) * 0.6 + vnoise(vec2(px) * 0.37) * 0.4;
	vec3 paper = paper_tint * (0.90 + 0.20 * grain);
	float show = clamp(paper_amt + debt * 0.35, 0.0, 1.0);
	// Paper texture over light: the grain lifts highlights slightly and darkens the valleys.
	col = mix(col, col * (paper / max(vec3(0.05), paper_tint)) * paper_tint * 1.04, show * 0.6);
	// Debt washes the picture toward the paper itself (U0 diluting as the Debt grows).
	col = mix(col, paper * (0.6 + 0.6 * luma(col)), debt * 0.3);

	// 2. Grade.
	float l = luma(col);
	col = mix(vec3(l), col, sat);
	if (post_levels > 1.5) {
		float lv = max(2.0, round(post_levels));
		vec3 p = floor(col * lv + 0.5) / lv;
		float amt = clamp(post_levels / 4.0, 0.0, 1.0);
		col = mix(col, p, amt);
	}
	if (ink > 0.01) {
		// Four inks: sumi black, cobalt, paper white; cinnabar survives for saturated reds (fire, banners).
		float li = luma(col);
		float g2 = vnoise(vec2(px) * 0.23) - 0.5;      // washi grain breaks the ink boundaries
		float lv = li + g2 * 0.08;
		vec3 sumi = vec3(0.102, 0.102, 0.102);
		vec3 cobalt = vec3(0.051, 0.149, 0.251);
		vec3 white = vec3(0.949, 0.933, 0.847);
		vec3 inked = mix(sumi, cobalt, smoothstep(0.18, 0.30, lv));
		inked = mix(inked, white, smoothstep(0.42, 0.58, lv));
		float redness = clamp((col.r - max(col.g, col.b)) * 3.0, 0.0, 1.0);
		inked = mix(inked, vec3(0.549, 0.114, 0.094) * (0.6 + li), redness);
		col = mix(col, inked, ink);
	}
	if (gold > 0.01) {
		// Gold leaf: highlights warm toward leaf, the picture lifts toward white paper (negative space).
		vec3 gold_col = vec3(0.86, 0.70, 0.32);
		float li2 = luma(col);
		float hi = smoothstep(0.40, 0.90, li2);
		vec3 leafed = mix(col, gold_col * (0.55 + 0.6 * li2), hi * 0.85);
		leafed = mix(leafed, vec3(0.99, 0.98, 0.95), smoothstep(0.70, 1.0, li2) * 0.7);
		col = mix(col, leafed, gold);
	}

	// 3. Edge: sobel on the scratch luminance, darkened in the canvas's line colour.
	if (edge_amt > 0.01) {
		float tl = luma(load(sp + ivec2(-1, -1))), t = luma(load(sp + ivec2(0, -1))), tr = luma(load(sp + ivec2(1, -1)));
		float ll = luma(load(sp + ivec2(-1, 0))), rr = luma(load(sp + ivec2(1, 0)));
		float bl = luma(load(sp + ivec2(-1, 1))), b = luma(load(sp + ivec2(0, 1))), br = luma(load(sp + ivec2(1, 1)));
		float gx = (tr + 2.0 * rr + br) - (tl + 2.0 * ll + bl);
		float gy = (bl + 2.0 * b + br) - (tl + 2.0 * t + tr);
		float mag = clamp(length(vec2(gx, gy)) * 2.2, 0.0, 1.0);
		// Dry-brush: break the line up with grain when ink is on.
		mag *= mix(1.0, step(0.25, grain + 0.3 * vnoise(vec2(px) * 0.9)), ink * 0.7);
		col = mix(col, edge_col, mag * edge_amt * 0.9);
	}

	// 4. VHS, CRT and vignette.
	if (vhs > 0.01) {
		float line = step(0.5, fract(float(px.y) / 3.0 + 0.01));
		col *= 1.0 - scan * vhs * (1.0 - line) * 0.4;
		if (reduced < 0.5) {
			float noise = (hash12(vec2(px) + vec2(qt * 13.0)) - 0.5) * 0.08 * vhs;
			col += noise;
		}
		vec2 d = uv - 0.5;
		col *= 1.0 - dot(d, d) * 0.6 * vhs;
	}

	// Vaelos near: watercolour bleeds into whatever canvas is showing (contamination as horror).
	float vn = params.data[2];
	if (vn > 0.01) {
		vec3 bleed = load(sp + ivec2(int(3.0 * sin(pc.time * 2.0 + uv.y * 30.0)), 0));
		col = mix(col, bleed * vec3(1.02, 0.98, 0.95), vn * 0.4);
	}

	vec3 original = imageLoad(src, px).rgb;
	imageStore(dst, px, vec4(mix(original, to_linear(col), strength), 1.0));
}
