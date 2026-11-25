// Silhouette en couleur unie (impact frames, scripts/moments.gd) pour un sprite cuit (sprite_bake.gd) :
// même rôle que silhouette.gdshader, mais l'atlas est en alpha prémultiplié et la couleur du dessin
// porte la teinte d'état (rgb = couleur visée, 1 - alpha = part ; shaders/sprite_tint.gdshader).
// La forme se lit donc dans la texture seule : un Flétri qui vient d'être frappé (éclair) garde
// toute sa silhouette.
shader_type canvas_item;
render_mode blend_premul_alpha;

uniform vec4 tint : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float amount = 1.0;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	// Dessin d'origine, teinte d'état comprise (prémultiplié).
	vec3 orig = mix(c.rgb, COLOR.rgb * c.a, 1.0 - COLOR.a);
	float solid = smoothstep(0.4, 0.62, c.a) * tint.a;
	float a = mix(c.a, solid, amount);
	COLOR = vec4(mix(orig, tint.rgb * solid, amount), a);
}
