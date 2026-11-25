// Mort d'un Flétri depuis son image cuite (scripts/enemy_remains.gd, sprite_bake.gd) : l'atlas est en
// alpha prémultiplié. Le dessin garde ses traits d'encre et ses ombres : la teinte (venin, sang, pierre,
// lumière, sève) remplace la couleur en gardant la lumière du dessin ; « ash » l'éteint en cendre ;
// « crumble » l'effrite par le haut, en grains, avec un liseré de braise au front qui avance.
shader_type canvas_item;
render_mode blend_premul_alpha;

// rgb : couleur de la teinte ; a : part de la teinte (0 : dessin d'origine).
uniform vec4 tint = vec4(0.0);
uniform float ash = 0.0;
uniform vec3 ash_color = vec3(0.45, 0.42, 0.4);
uniform vec3 ember = vec3(0.95, 0.5, 0.2);
uniform float alpha = 1.0;
// Effritement, 0 (entier) à 1 (parti) ; il gagne du haut vers le bas de la case.
uniform float crumble = 0.0;
// Case de l'image dans l'atlas (UV) : x, y du coin haut gauche, z, w du coin bas droit.
uniform vec4 cell = vec4(0.0, 0.0, 1.0, 1.0);
// Taille d'un grain en pixels de l'atlas.
uniform float grain = 6.0;
// Repli du prototype (ombre au sol cuite dans la case) : les pixels noirs très transparents tombent.
uniform bool drop_shadow = false;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	if (drop_shadow && c.a < 0.4 && max(c.r, max(c.g, c.b)) < 0.03 * c.a + 0.004) {
		c = vec4(0.0);
	}
	float a = c.a;
	vec3 rgb = a > 0.002 ? c.rgb / a : vec3(0.0);
	float l = dot(rgb, vec3(0.299, 0.587, 0.114));
	rgb = mix(rgb, ash_color * (0.55 + 0.9 * l), ash);
	rgb = mix(rgb, tint.rgb * (0.45 + 1.1 * l), tint.a);
	if (crumble > 0.0) {
		vec2 px = UV / TEXTURE_PIXEL_SIZE;
		float n = hash(floor(px / grain));
		float v = clamp((UV.y - cell.y) / max(cell.w - cell.y, 1e-5), 0.0, 1.0);
		// Front qui descend : au-dessus, le grain est parti ; juste en dessous, il rougeoie.
		float front = crumble * 1.3 - 0.15;
		float d = v + (n - 0.5) * 0.3 - front;
		if (d < 0.0) {
			a = 0.0;
		}
		rgb = mix(rgb, ember, (1.0 - smoothstep(0.0, 0.08, d)) * step(0.0, d) * 0.85);
	}
	a *= alpha * COLOR.a;
	COLOR = vec4(rgb * a, a);
}
