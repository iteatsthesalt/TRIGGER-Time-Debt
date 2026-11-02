// Billboard sprite material, the fade pass (Reference Bible §1.7): the same body as sprite_canvas.gdshader,
// blended at ALPHA = (1 - transparency) * opacity. Ghosts (field and battle Rewind, Boost style bleed), a
// phased Sera and the Debt fade (ActorSprite.set_opacity below 1). It draws no depth and casts no shadow.
shader_type spatial;
render_mode cull_disabled, depth_draw_opaque, specular_disabled;

#define SPRITE_FADE
#include "res://shaders/sprite_canvas.gdshaderinc"
