## Cuisson des silhouettes des Flétris en sprites (prototype, refonte des personnages, vague 0 T).
##
## Réglage interne, éteint par défaut (« -- --sprites », « --sprites=3 » pour une autre résolution) :
## au chargement, chaque sorte est dessinée une fois par le code (fletri_art.gd, enemy_art/), à
## ×scale et lissée (suréchantillonnée dans un SubViewport), image par image pour chaque animation (repos, marche,
## annonce, élan, retour, frappe), dans un atlas par sorte (ImageTexture avec mipmaps). En jeu,
## enemy.gd n'envoie plus qu'un quadrilatère texturé par Flétri au lieu d'un lot de triangles.
##
## Vue de trois quarts simulée : le dessin est cuit tourné vers la droite et retourné vers la gauche
## (plus de 32 orientations), avec une légère inclinaison vers la cible. L'écrasement (marche,
## respiration, annonce, coup reçu) reste une transformation au moment du dessin, la teinte d'état
## et l'éclair du coup reçu un petit shader (shaders/sprite_tint.gdshader).
##
## Ce qui ne vient pas de l'atlas (repli sur le dessin direct, retourné aussi) : les poses
## propres à un comportement (« live » : saut du Crapaud, Mandragore sous terre, Sangsue gorgée),
## les états inconnus de la cuisson, la cendre de la mort et les Flétris figés des galeries.
## Images identiques (une sorte sans annonce, par exemple) : cuites une seule fois.
##
## Aucun texte visible, aucun chiffre de jeu : apparence seulement.
extends RefCounted

const DrawBatch = preload("res://scripts/draw_batch.gd")
const FletriArt = preload("res://scripts/fletri_art.gd")

## Réglage interne : vrai avec « --sprites » sur la ligne de commande.
static var enabled := false
## Résolution de cuisson (×1 = pixels du jeu à 1600x900).
static var scale := 4.0
## Images de la marche (un pas complet), du repos (une respiration), de l'annonce, de la frappe.
static var walk_frames := 12
static var idle_frames := 6
static var windup_frames := 6
static var strike_frames := 4
## Lissage : suréchantillonnage. Le rendu Compatibility n'a pas de MSAA 2D : l'atlas est dessiné
## ss fois plus grand puis réduit (moyenne des ss×ss points de chaque pixel).
static var ss := 2
## Inclinaison maximale vers la cible (radians), en plus du retournement gauche/droite.
const TILT := 0.3
## Période des animations lentes (respiration), comme silhouette_cache.gd.
const TIME_LOOP := 2.4
## Marge autour de chaque image (pixels de l'atlas).
const PAD := 3

## Atlas d'une sorte.
class Atlas:
	var kind_id := ""
	var tex: ImageTexture
	## Rayon de la sorte (enemies.json) : une élite (rayon ×1,2) réutilise l'atlas, agrandi.
	var base_r := 1.0
	## Taille d'une case et origine (centre du Flétri) dans la case, en pixels de l'atlas.
	var cell := Vector2.ZERO
	var anchor := Vector2.ZERO
	var cols := 1
	## Animation -> indices de cases (après dédoublonnage).
	var anims := {}
	var unique := 0
	var total := 0
	var bytes := 0

	func src(i: int) -> Rect2:
		return Rect2(Vector2(i % cols, i / cols) * cell, cell)

static var atlases := {}
## Mesures (banc, rapport du prototype).
static var bake_usec := 0
static var build_usec := 0
## Lecture de l'image rendue, réduction, mipmaps et texture (après le rendu).
static var finish_usec := 0
static var drawn := 0
static var fallback := 0
static var _material: ShaderMaterial


## Lit le réglage sur la ligne de commande (« --sprites », « --sprites=3 », « --sprites-walk=8 »,
## « --sprites-ss=1|2|3|4 »).
static func configure() -> void:
	for a in OS.get_cmdline_user_args():
		if a == "--sprites":
			enabled = true
		elif a.begins_with("--sprites="):
			enabled = true
			scale = maxf(1.0, a.get_slice("=", 1).to_float())
		elif a.begins_with("--sprites-walk="):
			walk_frames = maxi(2, a.get_slice("=", 1).to_int())
		elif a.begins_with("--sprites-ss="):
			ss = clampi(a.get_slice("=", 1).to_int(), 1, 4)


static func material() -> ShaderMaterial:
	if _material == null:
		_material = ShaderMaterial.new()
		_material.shader = load("res://shaders/sprite_tint.gdshader")
	return _material


## Toutes les sortes de enemies.json.
static func all_kinds() -> Array:
	var out := []
	var f := FileAccess.open("res://data/enemies.json", FileAccess.READ)
	for k in JSON.parse_string(f.get_as_text()).get("kinds", []):
		out.append([str(k["id"]), float(k["radius"])])
	return out


## Poses à cuire : [animation, pose, temps].
static func _poses() -> Array:
	var out := []
	for i in idle_frames:
		out.append(["idle", {}, (i + 0.5) * TIME_LOOP / idle_frames])
	for i in walk_frames:
		out.append(["walk", {"walk": i * TAU / walk_frames, "moving": 1.0}, TIME_LOOP * 0.5])
	for i in windup_frames:
		out.append(["windup", {"state": "windup", "k": (i + 0.5) / windup_frames}, TIME_LOOP * 0.5])
	for i in 2:
		out.append(["charge", {"state": "charge", "moving": 1.0, "walk": i * PI}, (i + 0.5) * TIME_LOOP / 2.0])
	out.append(["recover", {"state": "recover"}, TIME_LOOP * 0.5])
	for i in strike_frames:
		out.append(["strike", {"strike": (i + 0.5) / strike_frames}, TIME_LOOP * 0.5])
	return out


## Cuit les sortes demandées ([[id, rayon], ...]) ; host : un nœud de l'arbre (pour les SubViewport).
## Coroutine : attend que le rendu des SubViewport soit fait (une image).
static func bake(host: Node, kinds: Array) -> void:
	var t0 := Time.get_ticks_usec()
	var jobs := []
	var b = DrawBatch.new()
	b.exact = true
	for kr in kinds:
		var kind_id: String = kr[0]
		if atlases.has(kind_id):
			continue
		var r: float = kr[1]
		var a := Atlas.new()
		a.kind_id = kind_id
		a.base_r = r
		var frames := []
		var seen := {}
		var box := Rect2()
		var box_set := false
		for p in _poses():
			var o: Dictionary = p[1].duplicate()
			o["no_squash"] = true
			b.draw_colored_polygon(Art.ellipse(Vector2(0, r * Art.OMBRE_DECALAGE * 0.5), r * 1.05, r * 0.75, 32), Art.c("ombre"))
			FletriArt.draw(b, kind_id, Vector2.ZERO, r, Vector2.RIGHT, p[2], o)
			var key := hash([b.points, b.colors])
			if not seen.has(key):
				seen[key] = frames.size()
				frames.append([b.points.duplicate(), b.colors.duplicate(), b.indices.duplicate()])
				for q in b.points:
					if not box_set:
						box = Rect2(q, Vector2.ZERO)
						box_set = true
					box = box.expand(q)
			if not a.anims.has(p[0]):
				a.anims[p[0]] = []
			a.anims[p[0]].append(seen[key])
			a.total += 1
			b.clear()
		a.unique = frames.size()
		a.cell = (box.size * scale).ceil() + Vector2.ONE * PAD * 2
		a.anchor = -box.position * scale + Vector2.ONE * PAD
		a.cols = maxi(1, ceili(sqrt(frames.size() * a.cell.y / a.cell.x)))
		var rows := ceili(float(frames.size()) / a.cols)
		var vp := SubViewport.new()
		vp.size = Vector2i(a.cell * Vector2(a.cols, rows)) * ss
		vp.transparent_bg = true
		vp.render_target_update_mode = SubViewport.UPDATE_ONCE
		vp.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
		var painter := Painter.new()
		for i in frames.size():
			var origin := a.src(i).position + a.anchor
			painter.items.append([Transform2D(0.0, Vector2(scale, scale) * ss, 0.0, origin * ss)] + frames[i])
		vp.add_child(painter)
		host.add_child(vp)
		jobs.append([a, vp])
	build_usec += Time.get_ticks_usec() - t0
	if jobs.is_empty():
		return
	await RenderingServer.frame_post_draw
	var t1 := Time.get_ticks_usec()
	for j in jobs:
		var a: Atlas = j[0]
		var vp: SubViewport = j[1]
		var img := vp.get_texture().get_image()
		if ss > 1:
			# Trilinéaire : la réduction passe par les mipmaps, une moyenne de boîte exacte pour ss = 2 ou 4.
			img.resize(img.get_width() / ss, img.get_height() / ss, Image.INTERPOLATE_TRILINEAR)
		img.generate_mipmaps()
		a.tex = ImageTexture.create_from_image(img)
		a.bytes = img.get_data_size()
		atlases[a.kind_id] = a
		vp.queue_free()
	finish_usec += Time.get_ticks_usec() - t1
	bake_usec += Time.get_ticks_usec() - t0


## Dessine les lots de triangles des images, chacun à sa place dans l'atlas.
class Painter extends Node2D:
	var items := []

	func _draw() -> void:
		var rid := get_canvas_item()
		for it in items:
			RenderingServer.canvas_item_add_set_transform(rid, it[0])
			RenderingServer.canvas_item_add_triangle_array(rid, it[3], it[1], it[2])
		RenderingServer.canvas_item_add_set_transform(rid, Transform2D.IDENTITY)


## Vrai si cette pose a son image dans l'atlas.
static func usable(o: Dictionary) -> bool:
	if o.has("ash") or o.has("mono") or o.has("live"):
		return false
	return o.get("state", "") in ["", "windup", "charge", "recover"]


## Case de l'atlas pour cette pose.
static func frame_of(a: Atlas, o: Dictionary, t: float) -> int:
	var state: String = o.get("state", "")
	var list: Array
	var u := 0.0
	if state == "windup":
		list = a.anims["windup"]
		u = float(o.get("k", 0.0))
	elif state == "charge":
		list = a.anims["charge"]
		u = fposmod(t, TIME_LOOP) / TIME_LOOP
	elif state == "recover":
		list = a.anims["recover"]
	elif float(o.get("strike", -1.0)) >= 0.0:
		list = a.anims["strike"]
		u = float(o["strike"])
	elif float(o.get("moving", 0.0)) >= 0.5:
		list = a.anims["walk"]
		u = fposmod(float(o.get("walk", 0.0)), TAU) / TAU
	else:
		list = a.anims["idle"]
		u = fposmod(t, TIME_LOOP) / TIME_LOOP
	return list[clampi(int(u * list.size()), 0, list.size() - 1)]


## Regard simplifié : vers la droite ou vers la gauche, plus une inclinaison bornée.
## Rend [signe, inclinaison].
static func facing(face: Vector2, prev_sign: float) -> Array:
	var s := prev_sign
	# Un peu d'hystérésis : un Flétri qui monte droit vers le héros ne clignote pas.
	if face.x > 0.15:
		s = 1.0
	elif face.x < -0.15:
		s = -1.0
	var base := 0.0 if s > 0.0 else PI
	return [s, clampf(angle_difference(base, face.angle()), -TILT, TILT)]


## Dessine dans ci (son matériau : material()) l'image de la pose. Faux si la pose n'est pas cuite.
static func draw(ci: CanvasItem, kind_id: String, r: float, sgn: float, tilt: float, t: float, o: Dictionary) -> bool:
	var a: Atlas = atlases.get(kind_id)
	if a == null or not usable(o):
		return false
	drawn += 1
	var i := frame_of(a, o, t)
	var k := r / a.base_r / scale
	var sq := FletriArt.squash(o, t)
	ci.draw_set_transform_matrix(Transform2D(tilt, Vector2(k * sq.x * sgn, k * sq.y), 0.0, Vector2.ZERO))
	# Teinte : couleur visée en rgb, part de teinte en 1 - alpha (shaders/sprite_tint.gdshader).
	var mod := Color(1, 1, 1, 1)
	var fl: float = o.get("flash", 0.0)
	var tint: Color = o.get("tint", Color(0, 0, 0, 0))
	if fl > 0.0:
		mod = Color(Art.c("danger_eclair"), 1.0 - 0.85 * fl)
	elif tint.a > 0.0:
		mod = Color(tint, 1.0 - tint.a)
	ci.draw_texture_rect_region(a.tex, Rect2(-a.anchor, a.cell), a.src(i), mod)
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)
	return true


## Mémoire des atlas cuits (octets, mipmaps comprises).
static func total_bytes() -> int:
	var n := 0
	for a in atlases.values():
		n += a.bytes
	return n


static func clear() -> void:
	atlases.clear()
	bake_usec = 0
	build_usec = 0
	finish_usec = 0
	drawn = 0
	fallback = 0
