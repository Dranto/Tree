// Héros caché derrière un boss (player.gd, calque « fantôme » au-dessus des acteurs) : le héros cuit
// redessiné en transparence, cerné d'un filet d'encre ivoire à l'intérieur de sa forme et d'un trait
// d'encre sombre à l'extérieur, pour qu'on le suive à travers le corps du boss (clair ou sombre) sans
// que la silhouette ne couvre le combat.
shader_type canvas_item;

uniform vec4 ink_col : source_color = vec4(0.937, 0.902, 0.812, 1.0);
uniform vec4 dark_col : source_color = vec4(0.078, 0.059, 0.047, 1.0);
// 0 : invisible ; 1 : le héros est entièrement caché (fondu de player.gd).
uniform float amount = 0.0;
// Part du dessin du héros vu à travers le boss, opacité des deux traits.
uniform float body = 0.55;
uniform float line = 0.95;
uniform float outline = 0.8;

// Modulation du dessin (fondu de la transition de tenue, flétrissure).
varying vec4 mod_col;

void vertex() {
	mod_col = COLOR;
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec2 p1 = TEXTURE_PIXEL_SIZE * 1.5;
	vec2 p2 = TEXTURE_PIXEL_SIZE * 3.0;
	float mn = min(min(texture(TEXTURE, UV - vec2(p1.x, 0.0)).a, texture(TEXTURE, UV + vec2(p1.x, 0.0)).a),
			min(texture(TEXTURE, UV - vec2(0.0, p1.y)).a, texture(TEXTURE, UV + vec2(0.0, p1.y)).a));
	float mx = max(max(texture(TEXTURE, UV - vec2(p2.x, 0.0)).a, texture(TEXTURE, UV + vec2(p2.x, 0.0)).a),
			max(texture(TEXTURE, UV - vec2(0.0, p2.y)).a, texture(TEXTURE, UV + vec2(0.0, p2.y)).a));
	mx = max(mx, max(max(texture(TEXTURE, UV + p2 * 0.7).a, texture(TEXTURE, UV - p2 * 0.7).a),
			max(texture(TEXTURE, UV + vec2(p2.x, -p2.y) * 0.7).a, texture(TEXTURE, UV + vec2(-p2.x, p2.y) * 0.7).a)));
	// Filet ivoire au bord intérieur de la forme, trait sombre juste dehors.
	float inner = clamp(c.a * (1.0 - mn), 0.0, 1.0) * line;
	float outer = clamp(mx * (1.0 - c.a), 0.0, 1.0) * outline;
	vec4 col = vec4(mix(c.rgb, ink_col.rgb, 0.15), c.a * body);
	col = mix(col, vec4(ink_col.rgb, 1.0), inner);
	col = mix(col, vec4(dark_col.rgb, 1.0), outer);
	COLOR = vec4(col.rgb, col.a * amount * mod_col.a);
}
