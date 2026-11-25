// Sol du monde : terre morte qui devient prairie là où la vie revient.
// Charte (docs/charte-graphique.md) : le fond est sourd et calme, il ne doit jamais attirer l'œil
// plus qu'un ennemi. Grands aplats doux, peu de traits sombres, quelques cailloux ; la frontière
// de la vie est soulignée d'un liseré de mousse claire (la vague de vie se lit d'un coup d'œil).
// Toutes les couleurs viennent de la palette (Art), passées par ground.gd.
// Le bruit vient d'une texture précalculée (ground.gd) et les détails d'un hachage entier :
// aucun sin() ni calcul flottant sensible à la carte graphique, le rendu est le même partout.
shader_type canvas_item;
render_mode blend_disabled;

uniform sampler2D life_map : filter_linear;
uniform sampler2D noise_tex : filter_linear, repeat_enable;
uniform vec2 world_size = vec2(6000.0, 6000.0);
uniform float noise_period = 3000.0;
// Régions (voir regions.gd et data/regions/<id>.json), REGION_COUNT au plus six : pour chacune,
// normales intérieures des deux bords de son secteur. Distance de la graine où elles commencent,
// largeur du fondu. Deux produits scalaires et une longueur par région : moins cher qu'une texture
// ou un atan par pixel (et le sol n'est recalculé que par carrés, voir ground.gd).
uniform int region_count = 0;
uniform vec2 region_n1[6];
uniform vec2 region_n2[6];
uniform float region_inner = 430.0;
uniform float region_edge = 110.0;
// 0 tant que le Cœur de flétrissure de la région vit, 1 une fois purifié.
uniform float region_purified[6];
// Palette de chaque région : terre morte (Cœur vivant), terre apaisée (purifiée), herbe, points
// sur l'herbe (couleur, case, rareté, sel du hachage, taille, force) et part de l'herbe de la
// région sur l'herbe commune (avant, et retirée une fois purifiée).
uniform vec3 region_dead_dark[6];
uniform vec3 region_dead_light[6];
uniform vec3 region_calm_dark[6];
uniform vec3 region_calm_light[6];
uniform vec3 region_alive_dark[6];
uniform vec3 region_alive_light[6];
uniform vec3 region_dot_col[6];
uniform vec4 region_dot[6];
uniform vec2 region_dot_salt[6];
uniform vec2 region_alive_mix[6];

// Palette (ground.gd la remplit depuis Art).
uniform vec3 dead_dark;
uniform vec3 dead_light;
uniform vec3 crack_col;
uniform vec3 pebble_col;
uniform vec3 alive_dark;
uniform vec3 alive_light;
uniform vec3 moss_col;
uniform vec3 bloom_col;

// Prototype « Paysages d'herbier » (refonte du monde, vague 0 P ; scripts/world_bake/ground_layers.gd) :
// dans la région wash_region, le shader ne dessine plus que le lavis (couche 1 : grandes formes, sans
// bruit fin, fissures, cailloux ni points) ; la matière et les détails sont dessinés par-dessus, à
// l'encre, dans chaque carré en cache. -1 (par défaut) : rien ne change.
uniform int wash_region = -1;
uniform vec3 wash_dead_dark;
uniform vec3 wash_dead_light;
uniform vec3 wash_alive_dark;
uniform vec3 wash_alive_light;

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

	// Régions : secteurs des branches (fondu sur leurs bords). Les secteurs ne se chevauchent que
	// dans leurs fondus.
	vec2 p = w - world_size * 0.5;
	float rws[6];
	float rw_any = 0.0;
	for (int i = 0; i < region_count; i++) {
		float inside = min(min(dot(p, region_n1[i]), dot(p, region_n2[i])), length(p) - region_inner);
		rws[i] = smoothstep(-region_edge, region_edge, inside + (n - 0.5) * 120.0);
		rw_any = max(rw_any, rws[i]);
	}

	float wash = 0.0;
	if (wash_region >= 0 && wash_region < region_count) {
		wash = rws[wash_region];
	}
	float tone_wash = smoothstep(0.25, 0.75, n);

	float l = texture(life_map, UV).r;
	// Lavis : front de vie plus net (le bord de vie est aussi dessiné, ground_layers.gd).
	float edge = smoothstep(mix(0.30, 0.41, wash), mix(0.60, 0.49, wash), l + (n2 - 0.5) * 0.3);

	// On ne calcule que la terre visible : morte, vivante, ou les deux sur la frontière.
	vec3 dead = vec3(0.0);
	if (edge < 1.0) {
		// Terre morte : aplats doux, quelques fissures fines et rares, des cailloux.
		dead = mix(dead_dark, dead_light, tone);
		float crack = smoothstep(0.008, 0.0, abs(nz.b - 0.5)) * smoothstep(0.66, 0.8, nz.a);
		float pebble = dot_in(w, 26.0, 0.975, vec2(3.0, 5.0), 0.16);
		for (int i = 0; i < region_count; i++) {
			if (rws[i] > 0.002) {
				// Terre de la région tant que son Cœur vit, terre apaisée une fois purifié.
				vec3 rust = mix(region_dead_dark[i], region_dead_light[i], tone);
				vec3 calm = mix(region_calm_dark[i], region_calm_light[i], tone);
				dead = mix(dead, mix(rust, calm, region_purified[i]), rws[i]);
			}
		}
		dead = mix(dead, crack_col, crack * 0.3 * (1.0 - wash));
		dead = mix(dead, pebble_col, pebble * 0.4 * (1.0 - wash));
		if (wash > 0.0) {
			vec3 lavis = mix(wash_dead_dark, wash_dead_light, tone_wash);
			dead = mix(dead, lavis, wash * (1.0 - region_purified[wash_region]));
		}
	}
	vec3 alive = vec3(0.0);
	if (edge > 0.0) {
		// Terre vivante : herbe calme, rares fleurs ; dans une région, son herbe et ses points.
		alive = mix(alive_dark, alive_light, tone_alive);
		if (rw_any > 0.002) {
			for (int i = 0; i < region_count; i++) {
				if (rws[i] > 0.002) {
					vec3 thicket = mix(region_alive_dark[i], region_alive_light[i], tone_alive);
					vec4 d = region_dot[i];
					float berry = dot_in(w, d.x, d.y, region_dot_salt[i], d.z);
					thicket = mix(thicket, region_dot_col[i], berry * d.w);
					alive = mix(alive, thicket, rws[i] * (region_alive_mix[i].x - region_alive_mix[i].y * region_purified[i]));
				}
			}
		} else {
			float bloom = dot_in(w, 18.0, 0.982, vec2(41.0, 9.0), 0.2);
			alive = mix(alive, bloom_col, bloom * 0.7);
		}
	}
	if (wash > 0.0 && edge > 0.0) {
		alive = mix(alive, mix(wash_alive_dark, wash_alive_light, tone_wash), wash);
	}
	vec3 col = mix(dead, alive, edge);
	// Liseré de mousse à la frontière de la vie : la terre ravivée a un bord net et vivant.
	float rim = smoothstep(0.03, 0.2, edge) * smoothstep(0.45, 0.22, edge);
	col = mix(col, moss_col, rim * 0.45 * (1.0 - wash));
	COLOR = vec4(col, 1.0);
}
