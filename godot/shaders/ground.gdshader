// Sol du monde : terre morte et craquelée qui devient prairie là où la vie revient.
// Le bruit vient d'une texture précalculée (ground.gd) et les paillettes d'un hachage entier :
// aucun sin() ni calcul flottant sensible à la carte graphique, le rendu est le même partout.
shader_type canvas_item;

uniform sampler2D life_map : filter_linear;
uniform sampler2D noise_tex : filter_linear, repeat_enable;
uniform vec2 world_size = vec2(6000.0, 6000.0);
uniform float noise_period = 3000.0;

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

	float l = texture(life_map, UV).r;
	float edge = smoothstep(0.30, 0.60, l + (n2 - 0.5) * 0.35);
	COLOR = vec4(mix(dead, alive, edge), 1.0);
}
