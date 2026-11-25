## Cuisson du héros, l'Esprit masqué (scripts/creature_art/heros/esprit.gd), en sprites lissés.
##
## Le dessin direct de l'Esprit coûte de 2 à 9 ms par image (encre, deux tons, reflets) : trop pour
## chaque image du jeu. À chaque changement d'apparence (hero_look.gd : achat d'un nœud, oubli,
## bascule de build, nouvelle attaque), il est dessiné une fois, image par image, dans deux atlas :
##   corps : la tenue seule (repos qui respire, marche), sans le bras ni l'arme ;
##   bras  : le bras et l'arme seuls, dans le repère immobile du corps (repos, une attaque complète).
## En jeu, HeroArt pose le bras sur le corps et y rejoue le rebond du pas et la visée (le bras pivote
## autour de l'épaule) : marcher et attaquer se combinent sans multiplier les images. Le corps ne dépend
## que de la tenue : changer d'attaque ne recuit que le bras.
##
## Rendu : à l'échelle de la fenêtre (auto_scale : l'atlas s'affiche pixel pour pixel), SubViewport
## suréchantillonné ×SS rempli en quelques images, puis réduction et passage en alpha droit (shaders/
## hero_unpremul.gdshader) dans un second SubViewport, qui garde l'atlas sur la carte graphique (pas de
## lecture ni de mipmaps). Les atlas se dessinent donc
## partout avec le mélange normal (signatures, galeries, silhouettes). Une case « mono » (silhouette
## blanche) sert aux images rémanentes de l'esquive.
## Apparence seulement : rien ici ne touche au jeu.
extends RefCounted

const Esprit = preload("res://scripts/creature_art/heros/esprit.gd")
const Ink = preload("res://scripts/creature_art/ink.gd")
const HeroLook = preload("res://scripts/hero_look.gd")
const UNPREMUL = preload("res://shaders/hero_unpremul.gdshader")

## Pixels de l'atlas par pixel du jeu (1600x900) ; 0 : selon la taille de la fenêtre (auto_scale).
static var scale := 0.0
## Cases dessinées par image pendant une cuisson.
const PER_FRAME := 6
const SS := 2
## Images : respiration (une période IDLE_LOOP), un pas complet, repos du bras, une attaque.
const BODY_IDLE := 12
const BODY_WALK := 12
const ARM_IDLE := 12
const ARM_ATTACK := 14
const IDLE_LOOP := 2.4
## Le repos du bras boucle sur π s (balancement de la main, orbites des ornements).
const ARM_LOOP := PI
## Cases (pixels du jeu) et place des pieds dans la case : larges pour les ailes, l'arme et sa portée.
const BODY_CELL := Vector2(76, 84)
const BODY_FEET := Vector2(38, 72)
const ARM_CELL := Vector2(132, 104)
const ARM_FEET := Vector2(54, 82)
## Apparences gardées en mémoire (bascule de build aller-retour sans recuire).
static var keep := 3

class Atlas:
	var key := ""
	var tex: Texture2D
	## Le SubViewport qui garde l'image de l'atlas (libéré quand l'atlas quitte le cache).
	var vp: SubViewport
	## Case et pieds (pixels de l'atlas), colonnes, animations -> indices de cases.
	var cell := Vector2.ZERO
	var feet := Vector2.ZERO
	var cols := 1
	var anims := {}
	var bytes := 0
	## Pixels de l'atlas par pixel du jeu.
	var k := 1.0
	## Apparence cuite, repères de l'Esprit (Esprit.anchors) et pixels du jeu par unité de l'Esprit.
	var look := {}
	var anchors := {}
	var fs := 1.0

	func src(i: int) -> Rect2:
		return Rect2(Vector2(i % cols, i / cols) * cell, cell)

	## Case de l'animation pour u (0 → 1, bouclé ou borné).
	func frame(anim: String, u: float, loop := true) -> int:
		var list: Array = anims[anim]
		var k := fposmod(u, 1.0) if loop else clampf(u, 0.0, 0.9999)
		return list[clampi(int(k * list.size()), 0, list.size() - 1)]

	## Dessine la case i, pieds en xf (repère en pixels du jeu, pieds à l'origine).
	func draw(ci: CanvasItem, i: int, xf: Transform2D, mod := Color.WHITE) -> void:
		ci.draw_set_transform_matrix(xf * Transform2D(0.0, Vector2.ONE / k, 0.0, Vector2.ZERO))
		ci.draw_texture_rect_region(tex, Rect2(-feet, cell), src(i), mod)


static var _cache := {}
static var _order := []
## Mesures (banc, rapport) : temps de la dernière cuisson (dessin des cases, total) et mémoire.
static var last_draw_usec := 0
static var last_total_usec := 0


## Hauteur h à donner à Esprit.draw (px du jeu pour 100 unités) pour la taille du héros en jeu :
## ~48 px du jeu au départ (58 px en 1080p), ~60 px tout développé (72 px), aura, bois et arme compris.
static func h_for(evol: float, r := 14.0) -> float:
	return lerpf(54.0, 40.0, evol) / (0.62 + 0.38 * evol) * r / 14.0


## Poses cuites d'une couche : [animation, pose].
static func _poses(look: Dictionary, couche: String) -> Array:
	var out := []
	var base := look.duplicate()
	base["couche"] = couche
	base["vol"] = false
	base["look"] = 0.0
	if couche == "corps":
		for i in BODY_IDLE:
			var o := base.duplicate()
			o["t"] = IDLE_LOOP * i / BODY_IDLE
			out.append(["idle", o])
		for i in BODY_WALK:
			var o := base.duplicate()
			o["t"] = 0.0
			o["walk"] = TAU * i / BODY_WALK
			o["moving"] = 1.0
			out.append(["walk", o])
	else:
		for i in ARM_IDLE:
			var o := base.duplicate()
			o["t"] = ARM_LOOP * i / ARM_IDLE
			out.append(["idle", o])
		for i in ARM_ATTACK:
			var o := base.duplicate()
			o["t"] = 0.0
			o["a"] = (i + 0.5) / ARM_ATTACK
			out.append(["attack", o])
	var m := base.duplicate()
	m["t"] = 0.0
	m["mono"] = true
	out.append(["mono", m])
	return out


## Bob vertical du corps (unités de l'Esprit) pour une pose cuite : le bras le rejoue.
static func bob(anim: String, u: float) -> float:
	if anim == "walk":
		var w := TAU * floorf(fposmod(u, 1.0) * BODY_WALK) / BODY_WALK
		return -absf(sin(w)) * 3.0
	var t := IDLE_LOOP * floorf(fposmod(u, 1.0) * BODY_IDLE) / BODY_IDLE
	return sin(t * TAU / IDLE_LOOP) * 1.2


## Échelle de cuisson : celle demandée (scale), sinon celle de la fenêtre (l'atlas se dessine à peu
## près pixel pour pixel à l'écran : net sans mipmaps, et pas plus grand que nécessaire).
static func auto_scale() -> float:
	if scale > 0.0:
		return scale
	var ml := Engine.get_main_loop()
	var hgt := 900.0
	if ml is SceneTree:
		hgt = float((ml as SceneTree).root.size.y)
	return clampf(snappedf(hgt / 900.0 * 1.1, 0.25), 1.0, 3.0)


static func _keys(look: Dictionary) -> Array:
	var k := "@%.2f " % auto_scale()
	return ["corps" + k + HeroLook.body_key(look), "bras" + k + HeroLook.key(look)]


## Atlas déjà cuits pour cette apparence ({} sinon).
static func cached(look: Dictionary) -> Dictionary:
	var ks := _keys(look)
	if _cache.has(ks[0]) and _cache.has(ks[1]):
		return {"corps": _cache[ks[0]], "bras": _cache[ks[1]]}
	return {}


## Cuit l'apparence (coroutine : quelques images de rendu, PER_FRAME cases dessinées par image pour ne
## pas figer le jeu). host : un nœud de l'arbre. Rend {corps, bras}.
static func bake(host: Node, look: Dictionary) -> Dictionary:
	var t0 := Time.get_ticks_usec()
	var ks := _keys(look)
	var k := auto_scale()
	var h := h_for(float(look.get("evol", 0.0)))
	var holder: Node = host.get_tree().root if host.is_inside_tree() else host
	last_draw_usec = 0
	for job in [[ks[0], "corps", BODY_CELL, BODY_FEET], [ks[1], "bras", ARM_CELL, ARM_FEET]]:
		if _cache.has(job[0]):
			continue
		var a := Atlas.new()
		a.key = job[0]
		a.k = k
		a.look = look.duplicate(true)
		a.anchors = Esprit.anchors(look)
		a.fs = h * float(a.anchors["scale"]) / 100.0
		var poses := _poses(look, job[1])
		a.cell = (job[2] * k).ceil()
		a.feet = (job[3] * k).round()
		a.cols = maxi(1, ceili(sqrt(poses.size() * a.cell.y / a.cell.x)))
		var size := Vector2i(a.cell * Vector2(a.cols, ceili(float(poses.size()) / a.cols)))
		var painter := Painter.new()
		painter.h = h * k * SS
		var items := []
		for i in poses.size():
			var p: Array = poses[i]
			if not a.anims.has(p[0]):
				a.anims[p[0]] = []
			a.anims[p[0]].append(i)
			items.append([(a.src(i).position + a.feet) * SS, p[1]])
		var vp := _viewport(size * SS)
		vp.render_target_clear_mode = SubViewport.CLEAR_MODE_ONCE
		vp.add_child(painter)
		holder.add_child(vp)
		# Quelques cases par image, ajoutées à ce qui est déjà rendu (pas d'effacement après la première).
		for i0 in range(0, items.size(), PER_FRAME):
			var u0 := Time.get_ticks_usec()
			painter.items = items.slice(i0, i0 + PER_FRAME)
			painter.queue_redraw()
			vp.render_target_update_mode = SubViewport.UPDATE_ONCE
			await RenderingServer.frame_post_draw
			last_draw_usec += Time.get_ticks_usec() - u0
		# Réduction en alpha droit dans l'atlas final (gardé sur la carte graphique, sans lecture).
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
		a.vp = vp2
		a.tex = vp2.get_texture()
		a.bytes = size.x * size.y * 4
		_keep(a)
	last_total_usec = Time.get_ticks_usec() - t0
	return cached(look)


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
	# Garde les KEEP dernières apparences (deux atlas chacune).
	while _order.size() > keep * 2:
		var old: Atlas = _cache[_order.pop_front()]
		_cache.erase(old.key)
		if is_instance_valid(old.vp):
			old.vp.queue_free()


## Dessine les poses de l'Esprit, chacune à sa place dans l'atlas suréchantillonné.
class Painter extends Node2D:
	var items := []
	var h := 1.0

	func _draw() -> void:
		for it in items:
			var o: Dictionary = it[1]
			var mono: bool = o.get("mono", false)
			Ink.mono = mono
			Ink.mono_col = Color.WHITE
			Esprit.draw(self, it[0], h, o)
			Ink.mono = false
			Ink.mono_col = Color.BLACK
			Ink.flash = 0.0


## Mémoire des atlas en cache (octets, sur la carte graphique).
static func total_bytes() -> int:
	var n := 0
	for a in _cache.values():
		n += a.bytes
	return n


static func clear() -> void:
	for a in _cache.values():
		if is_instance_valid(a.vp):
			a.vp.queue_free()
	_cache.clear()
	_order.clear()
