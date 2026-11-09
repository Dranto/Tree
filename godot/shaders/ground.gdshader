// Sol du monde : terre morte et craquelée qui devient prairie là où la vie revient.
shader_type canvas_item;

uniform sampler2D life_map : filter_linear;
uniform vec2 world_size = vec2(6000.0, 6000.0);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
			mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * noise(p);
		p *= 2.0;
		a *= 0.5;
	}
	return v;
}

void fragment() {
	vec2 w = UV * world_size;
	float n = fbm(w / 260.0);
	float n2 = fbm(w / 45.0);

	// Terre morte : cendre, poussière et fissures.
	vec3 dead = mix(vec3(0.16, 0.145, 0.14), vec3(0.30, 0.27, 0.24), n);
	dead = mix(dead, vec3(0.36, 0.33, 0.30), smoothstep(0.55, 0.75, n2) * 0.35);
	float crack = smoothstep(0.035, 0.0, abs(noise(w / 70.0) - 0.5));
	dead = mix(dead, vec3(0.07, 0.06, 0.06), crack * 0.75);

	// Terre vivante : herbe, mousse et touches de fleurs.
	vec3 alive = mix(vec3(0.13, 0.33, 0.13), vec3(0.30, 0.55, 0.20), n);
	alive = mix(alive, vec3(0.45, 0.68, 0.28), smoothstep(0.6, 0.8, n2) * 0.5);
	float speck = step(0.985, hash(floor(w / 6.0)));
	alive = mix(alive, vec3(0.95, 0.85, 0.55), speck * 0.6);

	float l = texture(life_map, UV).r;
	float edge = smoothstep(0.30, 0.60, l + (n2 - 0.5) * 0.35);
	COLOR = vec4(mix(dead, alive, edge), 1.0);
}
