// Distorsion de tout l'écran (le dernier coup du boss final, final_blow.gd) : aspiration puis
// gonflement autour d'un point, onde de choc qui réfracte l'image, torsion et aberration
// chromatique. Posé sur un ColorRect plein écran dans un CanvasLayer au-dessus de tout (HUD compris).
shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform vec2 center = vec2(0.5, 0.5);
uniform float aspect = 1.7778;
// Gonflement (> 0) ou aspiration (< 0) autour du centre.
uniform float bulge = 0.0;
// Onde de choc : rayon (en hauteurs d'écran), épaisseur, force.
uniform float wave_r = 0.0;
uniform float wave_w = 0.12;
uniform float wave_amp = 0.0;
uniform float wave2_r = 0.0;
uniform float wave2_amp = 0.0;
// Torsion autour du centre (radians au centre).
uniform float twist = 0.0;
// Aberration chromatique (décalage des canaux, en hauteurs d'écran).
uniform float chroma = 0.0;
// Lueur de l'onde.
uniform float glow = 0.0;

float wave(float r, float at, float w, float amp) {
	float x = (r - at) / w;
	return amp * x * exp(-x * x);
}

void fragment() {
	vec2 d = SCREEN_UV - center;
	d.x *= aspect;
	float r = length(d);
	vec2 dir = r > 0.0001 ? d / r : vec2(0.0, 1.0);
	float rb = r * (1.0 - bulge * exp(-r * r * 4.0));
	float ang = twist * exp(-r * 2.5);
	vec2 dd = dir * rb;
	dd = vec2(dd.x * cos(ang) - dd.y * sin(ang), dd.x * sin(ang) + dd.y * cos(ang));
	float w1 = wave(r, wave_r, wave_w, wave_amp);
	float w2 = wave(r, wave2_r, wave_w * 0.7, wave2_amp);
	dd += dir * (w1 + w2) * wave_w;
	dd.x /= aspect;
	vec2 suv = center + dd;
	vec2 ca = dir * vec2(1.0 / aspect, 1.0) * chroma * (0.35 + r);
	vec3 col = vec3(texture(screen_tex, suv + ca).r, texture(screen_tex, suv).g, texture(screen_tex, suv - ca).b);
	col += vec3(1.0, 0.94, 0.82) * (abs(w1) + abs(w2)) * glow;
	COLOR = vec4(col, 1.0);
}
