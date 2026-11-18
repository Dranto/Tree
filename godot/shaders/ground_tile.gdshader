// Carré de sol en cache (ground.gd) : recopie opaque de sa texture, sans mélange avec ce qui est
// dessous ni lumière (le sol est le premier calque et toujours opaque) : moins de travail par pixel
// en rendu logiciel, mêmes pixels.
shader_type canvas_item;
render_mode blend_disabled, unshaded;

void fragment() {
	COLOR = texture(TEXTURE, UV);
}
