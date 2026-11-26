// Boss « Bestiaire d'herbier » cuits (boss_bake.gd) : teinte d'état (poison, cendre de la mort) puis
// éclair du coup reçu, sur tout le dessin du nœud du boss (BossBase.tint_material).
shader_type canvas_item;

uniform vec4 tint_col : source_color = vec4(1.0);
uniform float tint = 0.0;
uniform vec4 flash_col : source_color = vec4(1.0);
uniform float flash = 0.0;

void fragment() {
	COLOR.rgb = mix(COLOR.rgb, tint_col.rgb, tint);
	COLOR.rgb = mix(COLOR.rgb, flash_col.rgb, flash);
}
