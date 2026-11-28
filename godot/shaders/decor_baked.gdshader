// Décor cuit (prototype, refonte du monde vague 0 P ; scripts/world_bake/decor_bake.gd) : l'atlas est en
// alpha prémultiplié (rendu d'un SubViewport transparent, comme shaders/sprite_tint.gdshader). Le même
// matériau sert au repli sur le dessin direct (arbre qui pousse) : la couleur des triangles, droite, est
// prémultipliée ici (sans texture, TEXTURE est blanche).
shader_type canvas_item;
render_mode blend_premul_alpha;

// Monde vivant (tâche V) : balancement et lueur du décor ; événements du monde (vague 2 E).
#include "res://shaders/decor_sway.gdshaderinc"
// Monde fané du cycle (New Game+, jalon 14 W).
#include "res://shaders/cycle_tint.gdshaderinc"

// Couleur du sommet (le COLOR de fragment() est déjà multiplié par la texture).
varying vec4 vcol;
varying vec2 vworld;

void vertex() {
	VERTEX += decor_sway(VERTEX, MODEL_MATRIX);
	vec3 ev = COLOR.rgb;
	VERTEX += decor_event(VERTEX, MODEL_MATRIX, ev);
	COLOR.rgb = ev;
	COLOR.rgb *= decor_light(VERTEX, MODEL_MATRIX);
	vcol = COLOR;
	vworld = cycle_tint_world(VERTEX, MODEL_MATRIX);
}

void fragment() {
	COLOR = cycle_tint_premul(texture(TEXTURE, UV) * vec4(vcol.rgb * vcol.a, vcol.a), vworld);
}
