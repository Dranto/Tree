// Monde vivant (scripts/world_life.gd) : petite vie du monde dessinée depuis l'atlas cuit
// (scripts/world_life_atlas.gd, alpha prémultiplié). La couleur du sommet teinte l'image ; un sommet
// d'alpha nul et de couleur non nulle s'ajoute à la lumière (lucioles, lueurs). Même teinte que le décor
// dans le monde fané du cycle (shaders/cycle_tint.gdshaderinc), sauf les lueurs.
shader_type canvas_item;
render_mode blend_premul_alpha;

#include "res://shaders/cycle_tint.gdshaderinc"

varying vec4 vcol;
varying vec2 vworld;

void vertex() {
	vcol = COLOR;
	vworld = cycle_tint_world(VERTEX, MODEL_MATRIX);
}

void fragment() {
	vec4 t = texture(TEXTURE, UV);
	// Teinte : rgb × couleur, puis prémultiplié par l'alpha du sommet ; « glow » (w nul) : additif.
	COLOR = cycle_tint_premul(vec4(t.rgb * vcol.rgb * max(vcol.a, 0.0001), t.a * vcol.a), vworld);
	if (vcol.a < 0.002) {
		COLOR = vec4(t.rgb * vcol.rgb, 0.0);
	}
}
