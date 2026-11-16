// Sol du monde : terre morte qui devient prairie là où la vie revient.
// Charte (docs/charte-graphique.md) : le fond est sourd et calme, il ne doit jamais attirer l'œil
// plus qu'un ennemi. Grands aplats doux, peu de traits sombres, quelques cailloux ; la frontière
// de la vie est soulignée d'un liseré de mousse claire (la vague de vie se lit d'un coup d'œil).
// Toutes les couleurs viennent de la palette (Art), passées par ground.gd.
// Le bruit vient d'une texture précalculée (ground.gd) et les détails d'un hachage entier :
// aucun sin() ni calcul flottant sensible à la carte graphique, le rendu est le même partout.
shader_type canvas_item;

uniform sampler2D life_map : filter_linear;
uniform sampler2D noise_tex : filter_linear, repeat_enable;
uniform vec2 world_size = vec2(6000.0, 6000.0);
uniform float noise_period = 3000.0;
// Région du roncier (secteur de la branche Ronce, voir regions.gd) : normales intérieures des
// deux bords du secteur, distance de la graine où il commence, largeur du fondu.
// Deux produits scalaires et une longueur : moins cher qu'une texture ou un atan par pixel.
uniform vec2 ronce_n1 = vec2(0.866, 0.5);
uniform vec2 ronce_n2 = vec2(-0.866, 0.5);
uniform float region_inner = 430.0;
uniform float region_edge = 110.0;
// 0 tant que le Cœur de flétrissure vit, 1 une fois purifié : la rouille s'efface.
uniform float ronce_purified = 0.0;

// Palette (ground.gd la remplit depuis Art).
uniform vec3 dead_dark;
uniform vec3 dead_light;
uniform vec3 crack_col;
uniform vec3 pebble_col;
uniform vec3 rust_dark;
uniform vec3 rust_light;
uniform vec3 calm_dark;
uniform vec3 calm_light;
uniform vec3 alive_dark;
uniform vec3 alive_light;
uniform vec3 moss_col;
uniform vec3 thicket_dark;
uniform vec3 thicket_light;
uniform vec3 berry_col;
uniform vec3 bloom_col;

// Hachage entier (exact sur toutes les cartes graphiques) d'une case de la grille.
uint hash_u(vec2 cell) {
	uvec2 q = uvec2(ivec2(cell) + ivec2(65536));
	uint h = q.x * 1597334677u ^ q.y * 3812015801u;
	h = (h ^ (h >> 16u)) * 2246822519u;
	return h ^ (h >> 13u);
}

// Petit point rond dans une case sur « rarity » : 0 ailleurs, 1 au centre du point.
// Un seul hachage : ses 16 bits bas décident s'il y a un point, les bits hauts le décalent
// dans sa case (pas de grille visible).
float dot_in(vec2 w, float cell, float rarity, vec2 salt, float size) {
	vec2 c = floor(w / cell);
	uint h = hash_u(c + salt);
	if (float(h & 0xFFFFu) / 65535.0 < rarity) {
		return 0.0;
	}
	vec2 off = vec2(float((h >> 16u) & 0xFFu), float(h >> 24u)) / 255.0 * 0.5 + 0.25;
	vec2 f = w / cell - c - off;
	return smoothstep(size, size * 0.55, length(f));
}

void fragment() {
	vec2 w = UV * world_size;
	vec4 nz = texture(noise_tex, w / noise_period);
	float n = nz.r;
	float n2 = nz.g;
	// Grandes taches adoucies : on garde le mouvement du sol, pas son bruit.
	float big = smoothstep(0.2, 0.8, n);
	float fine = (n2 - 0.5) * 0.25;
	float tone = clamp(big + fine, 0.0, 1.0);
	float tone_alive = clamp(big + fine * 1.4, 0.0, 1.0);

	// Roncier : secteur de la branche Ronce (fondu sur ses bords).
	vec2 p = w - world_size * 0.5;
	float inside = min(min(dot(p, ronce_n1), dot(p, ronce_n2)), length(p) - region_inner);
	float rw = smoothstep(-region_edge, region_edge, inside + (n - 0.5) * 120.0);

	float l = texture(life_map, UV).r;
	float edge = smoothstep(0.30, 0.60, l + (n2 - 0.5) * 0.3);

	// On ne calcule que la terre visible : morte, vivante, ou les deux sur la frontière.
	vec3 dead = vec3(0.0);
	if (edge < 1.0) {
		// Terre morte : aplats doux, quelques fissures fines et rares, des cailloux.
		dead = mix(dead_dark, dead_light, tone);
		float crack = smoothstep(0.008, 0.0, abs(nz.b - 0.5)) * smoothstep(0.66, 0.8, nz.a);
		float pebble = dot_in(w, 26.0, 0.975, vec2(3.0, 5.0), 0.16);
		if (rw > 0.002) {
			// Rouille tant que le Cœur vit, terre apaisée une fois purifié.
			vec3 rust = mix(rust_dark, rust_light, tone);
			vec3 calm = mix(calm_dark, calm_light, tone);
			dead = mix(dead, mix(rust, calm, ronce_purified), rw);
		}
		dead = mix(dead, crack_col, crack * 0.3);
		dead = mix(dead, pebble_col, pebble * 0.4);
	}
	vec3 alive = vec3(0.0);
	if (edge > 0.0) {
		// Terre vivante : herbe calme, rares fleurs ; dans le roncier, herbe plus profonde et baies.
		alive = mix(alive_dark, alive_light, tone_alive);
		if (rw > 0.002) {
			vec3 thicket = mix(thicket_dark, thicket_light, tone_alive);
			float berry = dot_in(w, 16.0, 0.985, vec2(91.0, 17.0), 0.18);
			thicket = mix(thicket, berry_col, berry * 0.85);
			alive = mix(alive, thicket, rw * (0.85 - 0.35 * ronce_purified));
		} else {
			float bloom = dot_in(w, 18.0, 0.982, vec2(41.0, 9.0), 0.2);
			alive = mix(alive, bloom_col, bloom * 0.7);
		}
	}
	vec3 col = mix(dead, alive, edge);
	// Liseré de mousse à la frontière de la vie : la terre ravivée a un bord net et vivant.
	float rim = smoothstep(0.03, 0.2, edge) * smoothstep(0.45, 0.22, edge);
	col = mix(col, moss_col, rim * 0.45);
	COLOR = vec4(col, 1.0);
}
