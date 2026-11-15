// Sol du monde : terre morte et craquelée qui devient prairie là où la vie revient.
// Le bruit vient d'une texture précalculée (ground.gd) et les paillettes d'un hachage entier :
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

// Hachage entier (exact sur toutes les cartes graphiques) d'une case de la grille.
float hash_cell(vec2 cell) {
	uvec2 q = uvec2(ivec2(cell) + ivec2(65536));
	uint h = q.x * 1597334677u ^ q.y * 3812015801u;
	h = (h ^ (h >> 16u)) * 2246822519u;
	h = h ^ (h >> 13u);
	return float(h & 0xFFFFu) / 65535.0;
}

void fragment() {
	vec2 w = UV * world_size;
	vec4 nz = texture(noise_tex, w / noise_period);
	float n = nz.r;
	float n2 = nz.g;

	// Terre morte : cendre, poussière et fissures.
	vec3 dead = mix(vec3(0.16, 0.145, 0.14), vec3(0.30, 0.27, 0.24), n);
	dead = mix(dead, vec3(0.36, 0.33, 0.30), smoothstep(0.55, 0.75, n2) * 0.35);
	// Fissures fines, seulement par endroits.
	float crack = smoothstep(0.014, 0.0, abs(nz.b - 0.5));
	float crack_mask = smoothstep(0.45, 0.65, nz.a);
	dead = mix(dead, vec3(0.09, 0.08, 0.075), crack * crack_mask * 0.8);

	// Terre vivante : herbe, mousse et touches de fleurs.
	vec3 alive = mix(vec3(0.13, 0.33, 0.13), vec3(0.30, 0.55, 0.20), n);
	alive = mix(alive, vec3(0.45, 0.68, 0.28), smoothstep(0.6, 0.8, n2) * 0.5);
	float speck = step(0.985, hash_cell(floor(w / 6.0)));
	alive = mix(alive, vec3(0.95, 0.85, 0.55), speck * 0.6);

	// Roncier : terre rouillée, veinée de sillons sombres comme des ronces mortes ;
	// une fois ravivé, herbe plus sombre semée de petites baies rouges.
	vec2 p = w - world_size * 0.5;
	float inside = min(min(dot(p, ronce_n1), dot(p, ronce_n2)), length(p) - region_inner);
	float rw = smoothstep(-region_edge, region_edge, inside + (n - 0.5) * 120.0);
	// Hors du roncier (presque tout l'écran ailleurs), rien de plus à calculer.
	if (rw > 0.002) {
		vec3 rust = mix(vec3(0.24, 0.13, 0.09), vec3(0.42, 0.23, 0.13), n);
		rust = mix(rust, vec3(0.12, 0.07, 0.06), crack * 0.9 + smoothstep(0.5, 0.0, abs(n2 - 0.5) * 12.0) * 0.3 * (1.0 - crack_mask));
		dead = mix(dead, rust, rw * (0.85 - 0.6 * ronce_purified));
		vec3 thicket = mix(vec3(0.12, 0.27, 0.12), vec3(0.24, 0.45, 0.17), n);
		float berry = step(0.992, hash_cell(floor(w / 5.0) + vec2(91.0, 17.0)));
		thicket = mix(thicket, vec3(0.80, 0.12, 0.16), berry * 0.85);
		alive = mix(alive, thicket, rw * 0.8);
	}

	float l = texture(life_map, UV).r;
	float edge = smoothstep(0.30, 0.60, l + (n2 - 0.5) * 0.35);
	COLOR = vec4(mix(dead, alive, edge), 1.0);
}
