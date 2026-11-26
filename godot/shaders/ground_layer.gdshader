// Sol « Paysages d'herbier », couches 2 et 3 (matière de la région, détails en grappes) et pousses
// du bord de vie : la géométrie d'un carré de sol est tirée une fois (scripts/world_bake/ground_layers.gd),
// sans dépendre de la vie. C'est ici, au moment du rendu du carré, que chaque élément se montre ou
// non selon la vie sous son point d'ancrage : une vague de vie ne refait que le rendu, pas le dessin.
// Chaque sommet porte dans UV le point d'ancrage de son élément (coordonnées de la carte de vie),
// décalé de 2 × sorte en x et de 2 × région en y :
//   sorte 0 : terre morte (craquelures, feuilles sèches, cailloux) : se referme quand la vie arrive,
//             teinte apaisée une fois la région purifiée ;
//   sorte 1 : terre ravivée (herbe rase, touffes, fleurs) : pousse depuis son ancrage avec la vie ;
//   sorte 2 : bord de vie (brins et fleurs) : seulement sur une bande juste derrière le front.
shader_type canvas_item;
render_mode unshaded;

uniform sampler2D life_map : filter_linear;
uniform vec2 world_size = vec2(6000.0, 6000.0);
uniform float front = 0.45;
uniform float region_purified[6];
// Terre morte apaisée : couleur du flétri multipliée par ce gain (rapport des sols apaisé / flétri).
uniform vec3 region_calm_gain[6];

void vertex() {
	float kind = floor(UV.x * 0.5);
	float reg = floor(UV.y * 0.5);
	vec2 a = UV - vec2(kind, reg) * 2.0;
	float l = textureLod(life_map, a, 0.0).r;
	float g;
	if (kind < 0.5) {
		g = 1.0 - smoothstep(front - 0.12, front + 0.01, l);
		int i = int(reg);
		if (i < 6) {
			COLOR.rgb = mix(COLOR.rgb, min(COLOR.rgb * region_calm_gain[i], vec3(1.0)), region_purified[i]);
		}
	} else if (kind < 1.5) {
		g = smoothstep(front, front + 0.22, l);
	} else {
		g = smoothstep(front - 0.05, front + 0.02, l) * (1.0 - smoothstep(front + 0.22, front + 0.45, l));
	}
	vec2 anchor = a * world_size - world_size * 0.5;
	// Un élément éteint est réduit à son ancrage (triangles vides) : rien à remplir.
	VERTEX = anchor + (VERTEX - anchor) * g;
}
