// Décor dessiné en direct (pas encore cuit) : même balancement et même lueur que le décor cuit
// (shaders/decor_sway.gdshaderinc). Couleur des triangles inchangée sinon.
shader_type canvas_item;

#include "res://shaders/decor_sway.gdshaderinc"

void vertex() {
	VERTEX += decor_sway(VERTEX, MODEL_MATRIX);
	COLOR.rgb *= decor_light(VERTEX, MODEL_MATRIX);
}
