// Monde vivant (refonte du monde, vague 1 V ; scripts/world_life.gd) : balancement et lueur du décor.
//
// À inclure dans le shader du décor, puis dans vertex(), avant toute lecture de COLOR :
//     VERTEX += decor_sway(VERTEX, MODEL_MATRIX);
//     COLOR.rgb *= decor_light(VERTEX, MODEL_MATRIX);
// Le pied de l'élément est à l'origine du nœud (VERTEX.y < 0 : au-dessus du pied). Le pied ne bouge
// jamais, le haut suit le vent ; un élément à « sway » nul (rocher, falaise) ne bouge pas. Tout est nul
// quand world_life.gd ne pose rien (tests visuels figés) : mêmes pixels qu'avant.
//
// Uniforms posés chaque image par world_life.gd sur chaque matériau du décor (aucun global) :
//   sway_wind  : direction du vent (xy), force du balancement de fond (z), horloge (w) ;
//   sway_gust  : front de la rafale le long du vent (x), demi-largeur (y), force (z) ;
//   sway_push  : impulsions (centre xy, rayon z, âge w ; rayon 0 = vide) et sway_force leur force
//                (> 0 : l'élément se couche loin du centre puis oscille ; < 0 : il se tord autour) ;
//   sway_light : lanterne du héros (centre xy, rayon z, force w).
uniform vec4 sway_wind = vec4(1.0, 0.0, 0.0, 0.0);
uniform vec4 sway_gust = vec4(0.0, 1.0, 0.0, 0.0);
uniform vec4 sway_push[8];
uniform float sway_force[8];
uniform vec4 sway_light = vec4(0.0, 0.0, 1.0, 0.0);
// Souplesse des éléments de ce matériau : 0 rigide, 1 arbre, plus de 1 roseaux. Pas d'« instance
// uniform » (plafond de 4096 éléments en rendu Compatibility) : world_life.gd donne à chaque élément
// une copie du matériau à la souplesse de sa sorte (quelques paliers).
uniform float sway = 0.0;

vec2 decor_sway(vec2 v, mat4 model) {
	if (sway <= 0.0) {
		return vec2(0.0);
	}
	vec2 foot = (model * vec4(0.0, 0.0, 0.0, 1.0)).xy;
	float hk = max(0.0, -v.y) / 64.0;
	// Le bas tient, le haut plie : courbe douce, bornée pour les très grands éléments.
	float bend = min(hk * (0.45 + 0.55 * hk), 2.6) * sway;
	if (bend <= 0.0) {
		return vec2(0.0);
	}
	vec2 wdir = sway_wind.xy;
	float t = sway_wind.w;
	float ph = dot(foot, vec2(0.0131, 0.0077));
	float amb = sway_wind.z * (0.62 * sin(t * 1.25 + ph) + 0.38 * sin(t * 2.3 + ph * 1.9));
	float along = dot(foot, wdir);
	float gx = (along - sway_gust.x) / max(sway_gust.y, 1.0);
	float g = sway_gust.z * exp(-gx * gx) * (1.0 + 0.22 * sin(t * 8.0 + ph * 3.0));
	vec2 off = wdir * (amb + g);
	for (int i = 0; i < 8; i++) {
		vec4 p = sway_push[i];
		if (p.z <= 0.0) {
			continue;
		}
		vec2 d = foot - p.xy;
		float dist = length(d);
		if (dist >= p.z) {
			continue;
		}
		vec2 n = dist > 0.5 ? d / dist : vec2(0.0, 1.0);
		float near = 1.0 - dist / p.z;
		float age = p.w;
		float f = sway_force[i];
		if (f >= 0.0) {
			// Couché loin du centre, puis oscille en revenant.
			off += n * f * near * exp(-age * 3.2) * cos(age * 15.0);
		} else {
			// Torsion : l'élément tourne autour du centre, lentement.
			off += vec2(-n.y, n.x) * f * near * sin(age * 3.0 + ph);
		}
	}
	return off * bend * 6.0;
}

// Lueur de la lanterne du héros sur le décor proche (multiplie la couleur du sommet).
vec3 decor_light(vec2 v, mat4 model) {
	if (sway_light.w <= 0.0) {
		return vec3(1.0);
	}
	vec2 wp = (model * vec4(v, 0.0, 1.0)).xy;
	float k = 1.0 - smoothstep(0.0, sway_light.z, distance(wp, sway_light.xy));
	k *= sway_light.w;
	return vec3(1.0 + 0.30 * k, 1.0 + 0.22 * k, 1.0 + 0.08 * k);
}
