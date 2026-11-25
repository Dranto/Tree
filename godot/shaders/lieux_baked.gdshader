// Lieux cuits (Cœurs, sanctuaires, autels ; scripts/world_bake/lieux_bake.gd) : l'atlas est en alpha
// prémultiplié (rendu d'un SubViewport transparent, comme shaders/decor_baked.gdshader). Le même
// matériau sert aux parties animées dessinées en direct sur le même nœud (halos, braises, flamme) et au
// repli sans cuisson : la couleur des triangles, droite, est prémultipliée ici (sans texture, TEXTURE
// est blanche).
shader_type canvas_item;
render_mode blend_premul_alpha;

varying vec4 vcol;

void vertex() {
	vcol = COLOR;
}

void fragment() {
	COLOR = texture(TEXTURE, UV) * vec4(vcol.rgb * vcol.a, vcol.a);
}
