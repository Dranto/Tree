## Cuisson d'un dessin du code en image lissée (planche du « Bestiaire d'herbier ») : le dessin est fait
## à ×ss dans un SubViewport, puis réduit (Lanczos). ss = 1 : rendu brut, sans lissage (comme en jeu).
extends RefCounted

var tree: SceneTree


func _init(t: SceneTree) -> void:
	tree = t


## drawer(ci: CanvasItem) dessine en px de l'image finale (le nœud est mis à l'échelle ×ss).
func bake(size: Vector2i, drawer: Callable, ss := 4, bg := Color(0, 0, 0, 0)) -> Image:
	var vp := SubViewport.new()
	vp.size = size * ss
	vp.transparent_bg = bg.a < 1.0
	vp.disable_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	tree.root.add_child(vp)
	if bg.a > 0.0:
		var rect := ColorRect.new()
		rect.color = bg
		rect.size = Vector2(size * ss)
		vp.add_child(rect)
	var n := Node2D.new()
	n.scale = Vector2(ss, ss)
	n.draw.connect(func(): drawer.call(n))
	vp.add_child(n)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	vp.queue_free()
	if ss > 1:
		img.convert(Image.FORMAT_RGBA8)
		img.resize(size.x, size.y, Image.INTERPOLATE_LANCZOS)
	return img
