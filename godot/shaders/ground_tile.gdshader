// Carré de sol en cache (ground.gd) : recopie opaque de sa texture, sans mélange avec ce qui est
// dessous ni lumière (le sol est le premier calque et toujours opaque) : moins de travail par pixel
// en rendu logiciel, mêmes pixels. Étalonné pour le monde fané du cycle (New Game+, jalon 14 W).
shader_type canvas_item;
render_mode blend_disabled, unshaded;

#include "res://shaders/cycle_tint.gdshaderinc"

varying vec2 vworld;

void vertex() {
	vworld = cycle_tint_world(VERTEX, MODEL_MATRIX);
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	COLOR = vec4(cycle_tint_rgb(c.rgb, vworld), c.a);
}
