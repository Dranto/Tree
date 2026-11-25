// Silhouette en couleur unie (impact frames, scripts/moments.gd) : le dessin existant d'un
// personnage (héros, Flétri, boss, Cœur) garde sa forme et prend une seule couleur, celle de
// l'encre, du papier ou de la région. Les parties très transparentes (ombre portée, auras) tombent :
// la silhouette reste nette, comme un trait d'encre.
shader_type canvas_item;

uniform vec4 tint : source_color = vec4(0.0, 0.0, 0.0, 1.0);
// 0 : dessin d'origine ; 1 : silhouette pleine (dosée par l'option des éclairs).
uniform float amount = 1.0;

void fragment() {
	vec4 c = COLOR;
	float solid = smoothstep(0.4, 0.62, c.a) * tint.a;
	COLOR = vec4(mix(c.rgb, tint.rgb, amount), mix(c.a, solid, amount));
}
