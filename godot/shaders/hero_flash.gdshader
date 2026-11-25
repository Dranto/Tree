// Éclair du coup reçu sur le héros cuit (player.gd) : tout le dessin du nœud vire vers flash_col.
shader_type canvas_item;

uniform vec4 flash_col : source_color = vec4(1.0);
uniform float flash = 0.0;

void fragment() {
	COLOR.rgb = mix(COLOR.rgb, flash_col.rgb, flash);
}
