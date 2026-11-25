// Sprites cuits des Flétris (scripts/sprite_bake.gd) : l'atlas est en alpha prémultiplié (rendu
// d'un SubViewport transparent). La couleur du dessin porte la teinte d'état ou l'éclair du coup
// reçu : rgb = couleur visée, 1 - alpha = part de cette couleur.
shader_type canvas_item;
render_mode blend_premul_alpha;

varying vec4 tint;

void vertex() {
	tint = COLOR;
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	c.rgb = mix(c.rgb, tint.rgb * c.a, 1.0 - tint.a);
	COLOR = c;
}
