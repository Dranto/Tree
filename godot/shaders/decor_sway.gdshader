// Décor dessiné en direct (pas encore cuit) : même balancement et même lueur que le décor cuit
// (shaders/decor_sway.gdshaderinc), même teinte du monde fané (shaders/cycle_tint.gdshaderinc).
shader_type canvas_item;

#include "res://shaders/decor_sway.gdshaderinc"
#include "res://shaders/cycle_tint.gdshaderinc"

varying vec2 vworld;

void vertex() {
	VERTEX += decor_sway(VERTEX, MODEL_MATRIX);
	vec3 ev = COLOR.rgb;
	VERTEX += decor_event(VERTEX, MODEL_MATRIX, ev);
	COLOR.rgb = ev;
	COLOR.rgb *= decor_light(VERTEX, MODEL_MATRIX);
	vworld = cycle_tint_world(VERTEX, MODEL_MATRIX);
}

void fragment() {
	COLOR.rgb = cycle_tint_rgb(COLOR.rgb, vworld);
}
