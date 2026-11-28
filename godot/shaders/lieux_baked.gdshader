// Lieux cuits (Cœurs, sanctuaires, autels ; scripts/world_bake/lieux_bake.gd) : l'atlas est en alpha
// prémultiplié (rendu d'un SubViewport transparent, comme shaders/decor_baked.gdshader). Le même
// matériau sert aux parties animées dessinées en direct sur le même nœud (halos, braises, flamme) et au
// repli sans cuisson : la couleur des triangles, droite, est prémultipliée ici (sans texture, TEXTURE
// est blanche).
shader_type canvas_item;
render_mode blend_premul_alpha;

// Monde fané du cycle (New Game+, jalon 14 W) : seulement pour les lieux et le bord du monde montrés
// à l'écran (LieuxBake.material(), BordBake.material()) ; pas pour le sol des arènes peint dans les
// carrés du sol (déjà étalonnés à leur affichage) ni pour les poses cuites des créatures.
#include "res://shaders/cycle_tint.gdshaderinc"
uniform bool cycle_graded = false;

varying vec4 vcol;
varying vec2 vworld;

void vertex() {
	vcol = COLOR;
	vworld = cycle_tint_world(VERTEX, MODEL_MATRIX);
}

void fragment() {
	COLOR = texture(TEXTURE, UV) * vec4(vcol.rgb * vcol.a, vcol.a);
	if (cycle_graded) {
		COLOR = cycle_tint_premul(COLOR, vworld);
	}
}
