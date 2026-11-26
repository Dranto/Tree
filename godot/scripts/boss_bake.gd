## Cuisson des boss « Bestiaire d'herbier » (refonte des personnages, vague 2 B) en sprites lissés.
##
## Un boss se dessine à chaque image : son dessin à l'encre (scripts/creature_art/<région>/_<boss>.gd :
## encre, deux tons, reflets) coûterait plusieurs millisecondes. Il est donc dessiné une fois, pose par
## pose, dans un atlas par « groupe » (le sol, le corps, l'endormi…), comme le héros (hero_bake.gd) :
## SubViewport suréchantillonné ×SS rempli en quelques images, puis réduit et repassé en alpha droit
## (shaders/hero_unpremul.gdshader) dans un second SubViewport qui garde l'atlas sur la carte graphique.
## En jeu, le boss ne pose plus qu'un quadrilatère texturé par groupe ; ce qui bouge vite (lianes,
## yeux, braises) reste dessiné en direct par des traits simples, sans encre calculée.
##
## Le script de dessin décrit ses groupes : static func groups() -> {nom: {"rect": Rect2 (unités, pieds
## en 0), "poses": [[animation, pose], ...]}}, const HEIGHT (px du jeu pour 100 unités) et
## static func draw(ci, feet, h, o) (o reçoit « groupe »). Tant que l'atlas n'est pas prêt (cuisson en
## cours, ou pas de rendu : --headless), le boss se dessine en direct : même image, plus lente.
## Clé : script, échelle, mode daltonien (Art.bc) ; seuls les KEEP derniers boss sont gardés.
## Apparence seulement : rien ici ne touche au jeu.
extends RefCounted

const Ink = preload("res://scripts/creature_art/ink.gd")
const Cuisson = preload("res://scripts/boss_art/cuisson.gd")
const UNPREMUL = preload("res://shaders/hero_unpremul.gdshader")

const SS := 2
## Cases dessinées par image pendant une cuisson.
const PER_FRAME := 4
## Échelle de cuisson (pixels de l'atlas par pixel du jeu) : celle de la fenêtre, bornée (mémoire).
const MAX_SCALE := 1.5
const KEEP := 2
## Réglage des tests et des planches : 0 = selon la fenêtre.
static var scale := 0.0
## « -- --no-sprites » : dessin direct (comparaisons).
static var enabled := true


class Group:
	var tex: Texture2D
	var vp: SubViewport
	var cell := Vector2.ZERO
	var feet := Vector2.ZERO
	var cols := 1
	var anims := {}

	func src(i: int) -> Rect2:
		return Rect2(Vector2(i % cols, i / cols) * cell, cell)

	func has(anim: String) -> bool:
		return anims.has(anim)

	## Case de l'animation pour u (0 → 1, bouclé ou borné).
	func frame(anim: String, u: float, loop := true) -> int:
		var list: Array = anims[anim]
		var q := fposmod(u, 1.0) if loop else clampf(u, 0.0, 0.9999)
		return list[clampi(int(q * list.size()), 0, list.size() - 1)]


class Atlas:
	var key := ""
	var ready := false
	var k := 1.0
	## Pixels du jeu par unité du dessin.
	var px := 1.0
	var groups := {}
	var bytes := 0

	## Dessine la case de l'animation anim (u : 0 → 1) du groupe g, pieds en xf (repère en pixels du
	## jeu, pieds à l'origine ; retournement et échelle dans xf). Faux si rien n'est cuit pour elle.
	func draw(ci: CanvasItem, g: String, anim: String, u: float, xf: Transform2D, mod := Color.WHITE, loop := true) -> bool:
		if not ready or not groups.has(g):
			return false
		var gr: Group = groups[g]
		if not gr.has(anim):
			return false
		var i := gr.frame(anim, u, loop)
		ci.draw_set_transform_matrix(xf * Transform2D(0.0, Vector2.ONE / k, 0.0, Vector2.ZERO))
		ci.draw_texture_rect_region(gr.tex, Rect2(-gr.feet, gr.cell), gr.src(i), mod)
		ci.draw_set_transform_matrix(Transform2D.IDENTITY)
		return true


	## Comme draw, mais une animation bouclée passe d'une case à la suivante en fondu (respiration
	## douce avec peu de cases).
	func draw_blend(ci: CanvasItem, g: String, anim: String, u: float, xf: Transform2D, loop := true, mod := Color.WHITE) -> bool:
		if not ready or not groups.has(g):
			return false
		var gr: Group = groups[g]
		if not gr.has(anim):
			return false
		var list: Array = gr.anims[anim]
		var n := list.size()
		var q := fposmod(u, 1.0) * n if loop else clampf(u, 0.0, 0.9999) * n
		var i0 := int(q) % n
		var f := q - floorf(q)
		ci.draw_set_transform_matrix(xf * Transform2D(0.0, Vector2.ONE / k, 0.0, Vector2.ZERO))
		ci.draw_texture_rect_region(gr.tex, Rect2(-gr.feet, gr.cell), gr.src(list[i0]), mod)
		if n > 1 and f > 0.02 and (loop or i0 < n - 1):
			ci.draw_texture_rect_region(gr.tex, Rect2(-gr.feet, gr.cell), gr.src(list[(i0 + 1) % n]), Color(mod, mod.a * f))
		ci.draw_set_transform_matrix(Transform2D.IDENTITY)
		return true


static var _cache := {}
static var _order := []
## Mesures (tests) : dernière cuisson.
static var last_usec := 0


static func auto_scale() -> float:
	if scale > 0.0:
		return scale
	return Cuisson.window_scale(1.1, 1.0, MAX_SCALE)


## Sans rendu (--headless : tests de logique, robots) : rien ne se voit, le dessin direct est sauté.
static func no_render() -> bool:
	return Cuisson.no_render()


static func key_of(art: GDScript) -> String:
	return "%s@%.2f/%s" % [art.resource_path, auto_scale(), Art.mode_daltonien]


## Atlas prêt pour ce dessin, ou null. Lance la cuisson s'il n'existe pas encore (host : un nœud de
## l'arbre). Sans rendu (--headless) ou réglage --no-sprites : toujours null (dessin direct).
static func get_atlas(host: Node, art: GDScript) -> Atlas:
	if not enabled or not Cuisson.active():
		return null
	var key := key_of(art)
	if _cache.has(key):
		var a: Atlas = _cache[key]
		return a if a.ready else null
	if host == null or not host.is_inside_tree():
		return null
	var a := Atlas.new()
	a.key = key
	_keep(a)
	_bake(host, art, a)
	return null


## Attend la fin de la cuisson (tests, planches). Rend l'atlas ou null (pas de rendu).
static func wait(host: Node, art: GDScript) -> Atlas:
	var a := get_atlas(host, art)
	if a != null or not _cache.has(key_of(art)):
		return a
	var at: Atlas = _cache[key_of(art)]
	while not at.ready and _cache.has(at.key):
		await host.get_tree().process_frame
	return at if at.ready else null


static func _bake(host: Node, art: GDScript, a: Atlas) -> void:
	var t0 := Time.get_ticks_usec()
	var k := auto_scale()
	a.k = k
	var h: float = art.HEIGHT
	a.px = h / 100.0
	var holder: Node = host.get_tree().root
	var groups: Dictionary = art.groups()
	for gname in groups:
		var spec: Dictionary = groups[gname]
		var rect: Rect2 = spec["rect"]
		var poses: Array = spec["poses"]
		var gr := Group.new()
		gr.cell = (rect.size * a.px * k).ceil()
		gr.feet = (-rect.position * a.px * k).round()
		gr.cols = maxi(1, ceili(sqrt(poses.size() * gr.cell.y / gr.cell.x)))
		var size := Vector2i(gr.cell * Vector2(gr.cols, ceili(float(poses.size()) / gr.cols)))
		var items := []
		for i in poses.size():
			var p: Array = poses[i]
			if not gr.anims.has(p[0]):
				gr.anims[p[0]] = []
			gr.anims[p[0]].append(i)
			var o: Dictionary = p[1].duplicate()
			o["groupe"] = gname
			items.append([(gr.src(i).position + gr.feet) * SS, o])
		var painter := Painter.new()
		painter.art = art
		painter.h = h * k * SS
		var vp := _viewport(size * SS)
		vp.render_target_clear_mode = SubViewport.CLEAR_MODE_ONCE
		vp.add_child(painter)
		holder.add_child(vp)
		for i0 in range(0, items.size(), PER_FRAME):
			painter.items = items.slice(i0, i0 + PER_FRAME)
			painter.queue_redraw()
			vp.render_target_update_mode = SubViewport.UPDATE_ONCE
			await RenderingServer.frame_post_draw
			if not _cache.has(a.key):
				vp.queue_free()
				return
		var vp2 := _viewport(size)
		var down := TextureRect.new()
		down.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		down.stretch_mode = TextureRect.STRETCH_SCALE
		down.texture = vp.get_texture()
		down.size = Vector2(size)
		down.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		var mat := ShaderMaterial.new()
		mat.shader = UNPREMUL
		down.material = mat
		vp2.add_child(down)
		holder.add_child(vp2)
		vp2.render_target_update_mode = SubViewport.UPDATE_ONCE
		await RenderingServer.frame_post_draw
		vp.queue_free()
		gr.vp = vp2
		gr.tex = vp2.get_texture()
		a.bytes += size.x * size.y * 4
		a.groups[gname] = gr
	a.ready = true
	last_usec = Time.get_ticks_usec() - t0


static func _viewport(size: Vector2i) -> SubViewport:
	var vp := SubViewport.new()
	vp.size = size
	vp.transparent_bg = true
	vp.disable_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	return vp


static func _keep(a: Atlas) -> void:
	_cache[a.key] = a
	_order.erase(a.key)
	_order.append(a.key)
	while _order.size() > KEEP:
		_free(_cache[_order.pop_front()])


static func _free(a: Atlas) -> void:
	_cache.erase(a.key)
	for g in a.groups.values():
		if is_instance_valid(g.vp):
			g.vp.queue_free()


## Vrai tant qu'une cuisson est en cours (les tests visuels attendent la fin avant de capturer).
static func baking() -> bool:
	for a in _cache.values():
		if not a.ready:
			return true
	return false


static func total_bytes() -> int:
	var n := 0
	for a in _cache.values():
		n += a.bytes
	return n


static func clear() -> void:
	for a in _cache.values().duplicate():
		_free(a)
	_order.clear()


## Dessine les poses, chacune à sa place dans l'atlas suréchantillonné.
class Painter extends Node2D:
	var items := []
	var h := 1.0
	var art: GDScript

	func _draw() -> void:
		for it in items:
			art.draw(self, it[0], h, it[1])
			Ink.flash = 0.0
			Ink.mono = false
