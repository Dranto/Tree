// Sprites cuits des Flétris (scripts/sprite_bake.gd) : l'atlas est en alpha prémultiplié (rendu
// d'un SubViewport transparent). La couleur du dessin porte la teinte d'état ou l'éclair du coup
// reçu : rgb = couleur visée, 1 - alpha = part de cette couleur.
// Élite (outline = 1) : un liseré doré autour de la silhouette, lu dans les pixels voisins de
// l'image (les cases de l'atlas ont une marge transparente plus large que le liseré).
shader_type canvas_item;
render_mode blend_premul_alpha;

uniform float outline = 0.0;
uniform vec4 outline_color : source_color = vec4(0.85, 0.71, 0.4, 1.0);
// Épaisseur du liseré, en pixels de l'atlas (×3 : un peu plus d'un pixel du jeu).
uniform float outline_px = 4.0;

varying vec4 tint;

void vertex() {
	tint = COLOR;
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	c.rgb = mix(c.rgb, tint.rgb * c.a, 1.0 - tint.a);
	if (outline > 0.5) {
		vec2 d = TEXTURE_PIXEL_SIZE * outline_px;
		float n = 0.0;
		n = max(n, textureLod(TEXTURE, UV + vec2(d.x, 0.0), 0.0).a);
		n = max(n, textureLod(TEXTURE, UV - vec2(d.x, 0.0), 0.0).a);
		n = max(n, textureLod(TEXTURE, UV + vec2(0.0, d.y), 0.0).a);
		n = max(n, textureLod(TEXTURE, UV - vec2(0.0, d.y), 0.0).a);
		n = max(n, textureLod(TEXTURE, UV + d * 0.7, 0.0).a);
		n = max(n, textureLod(TEXTURE, UV - d * 0.7, 0.0).a);
		n = max(n, textureLod(TEXTURE, UV + vec2(d.x, -d.y) * 0.7, 0.0).a);
		n = max(n, textureLod(TEXTURE, UV + vec2(-d.x, d.y) * 0.7, 0.0).a);
		float o = smoothstep(0.15, 0.6, n) * (1.0 - c.a);
		c += vec4(outline_color.rgb, 1.0) * o * outline_color.a;
	}
	COLOR = c;
}
