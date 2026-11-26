// Sol du monde « Paysages d'herbier » (refonte du monde, vague 1 S), couche 1 : le lavis.
// Charte (docs/charte-graphique.md) : le fond est sourd et calme, il ne doit jamais attirer l'œil
// plus qu'un ennemi. Le shader ne dessine que de grandes plaques nettes à trois tons par région
// (sombre, moyen, clair), sans bruit fin ; la matière de la région et les détails en grappes sont
// dessinés une fois par carré de sol en cache (scripts/world_bake/ground_layers.gd).
// Trois états par région : flétri (le Cœur vit), apaisé (purifié, hors du bord de vie) et ravivé
// (dans le bord de vie, la couleur propre à la région revient).
// Bord de vie : un front net (distance au front en pixels d'écran, tirée des dérivées de la carte de
// vie), une bande d'herbe dense plus sombre juste dedans et un liseré de sève ; plus de fumée.
// Toutes les couleurs viennent de la palette (Art.MONDE et data/regions/<id>.json), passées par ground.gd.
// Le bruit vient d'une texture précalculée (ground.gd) : aucun sin(), le rendu est le même partout.
shader_type canvas_item;
render_mode blend_disabled;

uniform sampler2D life_map : filter_linear;
uniform sampler2D noise_tex : filter_linear, repeat_enable;
uniform vec2 world_size = vec2(6000.0, 6000.0);
uniform float noise_period = 3000.0;
// Vie du front (ground.gd › FRONT) : la terre est ravivée au-delà.
uniform float front = 0.45;
// Régions (voir regions.gd et data/regions/<id>.json), six au plus : pour chacune, normales
// intérieures des deux bords de son secteur. Distance de la graine où elles commencent, largeur du
// fondu. Deux produits scalaires et une longueur par région.
uniform int region_count = 0;
uniform vec2 region_n1[6];
uniform vec2 region_n2[6];
uniform float region_inner = 430.0;
// Frontières entre régions (vague 3 B, world_art/frontieres.gd) : les deux sols ne se fondent pas, ils
// s'entremêlent en langues et en îlots sur une bande de ± border_half px autour de chaque demi-droite
// (± border_inner autour de l'oasis). Chaque pixel appartient à une seule région ; un fin liseré
// sombre marque le bord d'un îlot (une terre posée sur l'autre). Même calcul que Frontieres.inside().
uniform float border_half = 220.0;
uniform float border_inner = 120.0;
uniform float border_amp = 1.25;
uniform float border_scale = 1.7;
uniform vec2 border_offset = vec2(0.37, 0.61);
// Trois tons par région, pour la terre morte (mélange du flétri et de l'apaisé selon les Cœurs
// purifiés, fait par ground.gd) et pour la terre ravivée : sombre, moyen, clair.
uniform vec3 region_dead_dark[6];
uniform vec3 region_dead_mid[6];
uniform vec3 region_dead_light[6];
uniform vec3 region_alive_dark[6];
uniform vec3 region_alive_mid[6];
uniform vec3 region_alive_light[6];

// Oasis de la graine et hors des régions (ground.gd la remplit depuis Art).
uniform vec3 dead_dark;
uniform vec3 dead_mid;
uniform vec3 dead_light;
uniform vec3 alive_dark;
uniform vec3 alive_mid;
uniform vec3 alive_light;
// Liseré du bord de vie (vert sève, réservé au bord de vie et à la graine).
uniform vec3 seve_col;

// Hachage entier (exact sur toutes les cartes graphiques) d'une case de la grille.
uint hash_u(vec2 cell) {
	uvec2 q = uvec2(ivec2(cell) + ivec2(65536));
	uint h = q.x * 1597334677u ^ q.y * 3812015801u;
	h = (h ^ (h >> 16u)) * 2246822519u;
	return h ^ (h >> 13u);
}

// Décalage des îlots pour une distance s au bord (nul hors de la bande).
float border_shift(float s, float half_w, float n) {
	float t = clamp(s / half_w, -1.0, 1.0);
	return (n - 0.5) * 2.0 * border_amp * half_w * (1.0 - t * t);
}

vec3 plaques(vec3 d, vec3 m, vec3 l, vec2 k) {
	return mix(mix(m, d, k.x), l, k.y);
}

void fragment() {
	vec2 w = UV * world_size;
	vec4 nz = texture(noise_tex, w / noise_period);
	// Plaques nettes : deux seuils sur deux bruits larges, bord fondu sur quelques pixels (le bruit est
	// une texture de 6 px par texel : un seuil plus dur montrerait ses marches).
	vec2 k = vec2(1.0 - smoothstep(0.37, 0.43, nz.r), smoothstep(0.57, 0.63, nz.a));

	// Bord de vie : distance au front en pixels d'écran (+ dedans), le front ondule un peu.
	float lv = texture(life_map, UV).r + (nz.g - 0.5) * 0.1;
	vec2 dl = vec2(dFdx(lv), dFdy(lv));
	float g = max(length(dl), 1e-5);
	float d = (lv - front) / g;
	float edge = clamp(d + 0.5, 0.0, 1.0);

	// Régions : secteurs des branches (fondu sur leurs bords). On ne calcule que la terre visible.
	vec2 p = w - world_size * 0.5;
	vec3 dead = edge < 1.0 ? plaques(dead_dark, dead_mid, dead_light, k) : vec3(0.0);
	vec3 alive = edge > 0.0 ? plaques(alive_dark, alive_mid, alive_light, k) : vec3(0.0);
	vec3 band_col = alive_dark;
	vec3 tip_col = alive_light;
	// Îlots de la bande : bruit propre (canal R relu à une autre échelle) ; largeur d'un pixel d'écran
	// en px du monde (dérivées prises hors de la boucle).
	float bn = texture(noise_tex, p * border_scale / noise_period + border_offset).r;
	float wpx = max(fwidth(w.x), 1e-3);
	float lip = 0.0;
	for (int i = 0; i < region_count; i++) {
		float s1 = dot(p, region_n1[i]);
		float s2 = dot(p, region_n2[i]);
		float s3 = length(p) - region_inner;
		float inside = min(min(s1 + border_shift(s1, border_half, bn), s2 - border_shift(s2, border_half, bn)), s3 + border_shift(s3, border_inner, bn));
		float rw = clamp(inside / (wpx * 1.3) + 0.5, 0.0, 1.0);
		lip = max(lip, 1.0 - smoothstep(wpx * 0.6, wpx * 0.6 + 2.4, abs(inside)));
		if (rw > 0.002) {
			if (edge < 1.0) {
				dead = mix(dead, plaques(region_dead_dark[i], region_dead_mid[i], region_dead_light[i], k), rw);
			}
			if (edge > 0.0) {
				alive = mix(alive, plaques(region_alive_dark[i], region_alive_mid[i], region_alive_light[i], k), rw);
			}
			band_col = mix(band_col, region_alive_dark[i], rw);
			tip_col = mix(tip_col, region_alive_light[i], rw);
		}
	}
	// Herbe rase couchée sur la terre ravivée : de petits traits penchés dans le même sens (lumière
	// d'en haut à gauche), un sur trois clair. Une racine possible par case de 7 px du monde.
	if (edge > 0.0) {
		vec3 dark_s = band_col * 0.86;
		vec3 light_s = mix(tip_col, vec3(1.0), 0.08);
		float hit = 0.0;
		vec3 stroke = alive;
		for (int j = 0; j < 2; j++) {
			for (int c = -1; c <= 0; c++) {
				vec2 cell = vec2(floor(w.x / 7.0) + float(c), floor(w.y / 7.0) + float(j));
				uint h = hash_u(cell + vec2(57.0, 811.0));
				if ((h & 15u) > 3u) {
					continue;
				}
				vec2 root = (cell + vec2(float((h >> 4u) & 255u), float((h >> 12u) & 255u)) / 255.0) * 7.0;
				vec2 dir = normalize(vec2(0.5 + float((h >> 20u) & 15u) / 60.0, -1.0));
				float len = 4.0 + float(h >> 26u) / 63.0 * 4.5;
				vec2 q = w - root;
				float along = dot(q, dir);
				float across = abs(q.x * dir.y - q.y * dir.x);
				if (along > 0.0 && along < len && across < 0.55 * (1.0 - along / len) + 0.15) {
					hit = 1.0;
					stroke = (h % 3u) == 0u ? light_s : dark_s;
				}
			}
		}
		alive = mix(alive, stroke, hit * 0.22);
	}
	vec3 col = mix(dead, alive, edge);
	// Bord d'un îlot de la bande : une terre posée sur l'autre, un liseré à peine plus sombre.
	col *= 1.0 - lip * 0.16;
	// Herbe dense juste dedans (ombre), liseré de sève sur le front, léger halo dehors.
	float band = edge * (1.0 - smoothstep(2.0, 9.0, d));
	col = mix(col, band_col * 0.82, band * 0.5);
	float line = 1.0 - smoothstep(0.5, 1.3, abs(d - 1.2));
	col = mix(col, seve_col, line * 0.7);
	float halo = (1.0 - edge) * (1.0 - smoothstep(0.0, 5.0, -d));
	col = mix(col, seve_col, halo * 0.12);
	// L'herbe du front : des brins qui poussent juste derrière la ligne, plus hauts en s'éloignant
	// du front, quelques pousses de sève qui la devancent. Une racine possible par case de 4 × 4 px du
	// monde ; la vie est lue à la racine (tous les pixels d'un brin voient la même), et seulement pour
	// les racines dont le brin peut couvrir le pixel.
	if (lv > front - 0.2 && lv < front + 0.32) {
		float best = -1.0;
		vec3 blade = col;
		for (int j = 0; j < 5; j++) {
			float ry = floor(w.y / 4.0) + float(j);
			for (int c = -1; c <= 1; c++) {
				float cx = floor(w.x / 4.0) + float(c);
				uint h = hash_u(vec2(cx, ry) + vec2(311.0, 97.0));
				vec2 root = vec2(cx + float(h & 255u) / 255.0, ry + float((h >> 8u) & 255u) / 255.0) * 4.0;
				float up = root.y - w.y;
				float r1 = float((h >> 16u) & 255u) / 255.0;
				float lean = (float(h >> 24u) / 255.0 - 0.35) * 0.55;
				if (up < 0.0 || up > 15.0 * (0.65 + 0.7 * r1) || abs(w.x - root.x - lean * up) > 1.35 || root.y <= best) {
					continue;
				}
				float lr = textureLod(life_map, root / world_size, 0.0).r + (textureLod(noise_tex, root / noise_period, 0.0).g - 0.5) * 0.1 - front;
				if (lr < -0.012 || lr > 0.13) {
					continue;
				}
				float hh = (lr < 0.0 ? 4.0 : 6.0 + min(lr / 0.12, 1.0) * 9.0) * (0.65 + 0.7 * r1);
				float t = up / hh;
				if (t > 1.0 || abs(w.x - root.x - lean * up) > (1.0 - t) * 1.15 + 0.2) {
					continue;
				}
				best = root.y;
				vec3 base = lr < 0.0 ? seve_col * 0.85 : ((h & 1u) == 0u ? band_col * 0.7 : mix(tip_col, vec3(1.0), 0.1));
				blade = mix(base, mix(tip_col, seve_col, 0.25), t * 0.35);
			}
		}
		col = blade;
	}
	COLOR = vec4(col, 1.0);
}
