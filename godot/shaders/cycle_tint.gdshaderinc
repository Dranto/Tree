// Monde fané du cycle (New Game+, jalon 14 W ; réglages dans data/cycles.json › cycles › "<n>" › tint,
// posés par scripts/cycle_tint.gd). Un étalonnage des couleurs appliqué au rendu des images cuites du
// monde (décor, sol en carrés, bords, lieux, petite vie) : palette plus sombre et plus grise, une pointe
// de cendre, et l'encre (les tons les plus sombres) plus marquée. Les images cuites ne changent pas :
// un seul cache pour tous les cycles, aucune recuisson au changement de cycle, et la vague de
// flétrissure (scripts/cycle_wave.gd) peut faire avancer la teinte d'un front net, pixel par pixel.
// Cycle 1 : réglages nuls, la couleur sort telle quelle (un test sur des uniformes, rien d'autre).
//
// Réglage : x sombre (part de lumière retirée), y gris (part de désaturation), z encre (assombrissement
// des tons sombres), w cendre (part de la teinte de cendre). « from » vaut hors du front, « to » dedans.
global uniform vec4 cycle_tint_from;
global uniform vec4 cycle_tint_to;
// Front de la vague : centre (x, y, pixels du monde), rayon, largeur du fondu.
global uniform vec4 cycle_tint_wave;
global uniform vec3 cycle_tint_ash;

// Première aventure (et hors du jeu) : aucun réglage, la couleur sort telle quelle.
bool cycle_tint_off() {
	return all(equal(cycle_tint_from, vec4(0.0))) && all(equal(cycle_tint_to, vec4(0.0)));
}

// Position dans le monde d'un sommet (à passer du vertex() au fragment() par un varying).
vec2 cycle_tint_world(vec2 v, mat4 model) {
	return (model * vec4(v, 0.0, 1.0)).xy;
}

// Couleur droite (non prémultipliée) étalonnée pour le cycle, au point « world » du monde.
vec3 cycle_tint_rgb(vec3 c, vec2 world) {
	if (cycle_tint_off()) {
		return c;
	}
	vec4 g = cycle_tint_to;
	float edge = 0.0;
	if (any(notEqual(cycle_tint_from, cycle_tint_to))) {
		float d = distance(world, cycle_tint_wave.xy);
		float w = max(cycle_tint_wave.w, 1.0);
		g = mix(cycle_tint_to, cycle_tint_from, smoothstep(cycle_tint_wave.z - w, cycle_tint_wave.z, d));
		// Le front lui-même : un liseré d'encre qui avance.
		edge = max(0.0, 1.0 - abs(d - cycle_tint_wave.z + w * 0.5) / (w * 0.5));
	}
	if (g.x + g.y + g.z + g.w + edge <= 0.0) {
		return c;
	}
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(c, vec3(l), g.y);
	float la = max(dot(cycle_tint_ash, vec3(0.299, 0.587, 0.114)), 0.01);
	c = mix(c, cycle_tint_ash * (l / la), g.w);
	c *= 1.0 - g.x;
	c *= 1.0 - clamp(g.z + edge * 0.35, 0.0, 1.0) * (1.0 - smoothstep(0.06, 0.42, l));
	return c;
}

// Même étalonnage pour une couleur en alpha prémultiplié.
vec4 cycle_tint_premul(vec4 c, vec2 world) {
	if (c.a <= 0.0 || cycle_tint_off()) {
		return c;
	}
	return vec4(cycle_tint_rgb(c.rgb / c.a, world) * c.a, c.a);
}
