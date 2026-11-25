// Cuisson du héros (scripts/hero_bake.gd) : réduit l'image suréchantillonnée (filtrage linéaire, une
// moyenne exacte à ×2) et repasse de l'alpha prémultiplié (rendu d'un SubViewport transparent) à
// l'alpha droit, pour que l'atlas se dessine partout avec le mélange normal.
shader_type canvas_item;
render_mode blend_disabled;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	COLOR = c.a > 0.0001 ? vec4(c.rgb / c.a, c.a) : vec4(0.0);
}
