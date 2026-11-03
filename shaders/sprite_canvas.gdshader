// Billboard sprite material for every character (Reference Bible §1.7): the cut-out pass. Hard alpha by
// discard, opaque (depth, shadows); the body is sprite_canvas.gdshaderinc. A sprite below full opacity
// uses sprite_canvas_fade.gdshader instead (ActorSprite.set_opacity).
shader_type spatial;
render_mode cull_disabled, depth_draw_opaque, specular_disabled;

#include "res://shaders/sprite_canvas.gdshaderinc"
