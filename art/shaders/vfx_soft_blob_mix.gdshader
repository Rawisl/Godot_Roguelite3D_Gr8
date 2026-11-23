shader_type spatial;
// Soft blob particle, alpha blended (poison droplets and smoke).
// See vfx_soft_blob.gdshaderinc.
render_mode unshaded, blend_mix, cull_disabled, shadows_disabled, depth_draw_never;

#include "res://art/shaders/vfx_soft_blob.gdshaderinc"
