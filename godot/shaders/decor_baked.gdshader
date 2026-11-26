// Décor cuit (prototype, refonte du monde vague 0 P ; scripts/world_bake/decor_bake.gd) : l'atlas est en
// alpha prémultiplié (rendu d'un SubViewport transparent, comme shaders/sprite_tint.gdshader). Le même
// matériau sert au repli sur le dessin direct (arbre qui pousse) : la couleur des triangles, droite, est
// prémultipliée ici (sans texture, TEXTURE est blanche).
shader_type canvas_item;
render_mode blend_premul_alpha;

// Monde vivant (tâche V) : balancement et lueur du décor.
#include "res://shaders/decor_sway.gdshaderinc"

// Couleur du sommet (le COLOR de fragment() est déjà multiplié par la texture).
varying vec4 vcol;

void vertex() {
	VERTEX += decor_sway(VERTEX, MODEL_MATRIX);
	COLOR.rgb *= decor_light(VERTEX, MODEL_MATRIX);
	vcol = COLOR;
}

void fragment() {
	COLOR = texture(TEXTURE, UV) * vec4(vcol.rgb * vcol.a, vcol.a);
}
