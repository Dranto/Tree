// Monde vivant (scripts/world_life.gd) : petite vie du monde dessinée depuis l'atlas cuit
// (scripts/world_life_atlas.gd, alpha prémultiplié). La couleur du sommet teinte l'image ; un sommet
// d'alpha nul et de couleur non nulle s'ajoute à la lumière (lucioles, lueurs).
shader_type canvas_item;
render_mode blend_premul_alpha;

varying vec4 vcol;

void vertex() {
	vcol = COLOR;
}

void fragment() {
	vec4 t = texture(TEXTURE, UV);
	// Teinte : rgb × couleur, puis prémultiplié par l'alpha du sommet ; « glow » (w nul) : additif.
	COLOR = vec4(t.rgb * vcol.rgb * max(vcol.a, 0.0001), t.a * vcol.a);
	if (vcol.a < 0.002) {
		COLOR = vec4(t.rgb * vcol.rgb, 0.0);
	}
}
