## Lieux cuits (refonte du monde, vague 1 C) : les parties fixes des Cœurs, des sanctuaires et des autels
## (world_art/lieux.gd) dessinées une fois par le code, à ×scale et lissées (suréchantillonnées ss fois
## dans un SubViewport, réduites, mipmaps), dans un petit atlas par « jeu » (un Cœur et ses états, les
## pierres d'un sanctuaire allumées et éteintes, un autel). En jeu, la partie fixe n'est plus qu'un
## quadrilatère texturé ; seules les parties animées (halos, braises, flamme) restent dessinées en direct.
##
## Même méthode que la cuisson des Flétris (sprite_bake.gd) et du décor (decor_bake.gd) : leur API n'est
## pas reprise (propre aux Flétris et au décor), la méthode l'est. Un jeu est cuit à la demande, quand le
## lieu approche de l'écran (request) ; en attendant, et sans rendu (--headless), le lieu se dessine en
## direct (draw renvoie faux). Pas de cache disque : quelques images, cuites en une image de rendu.
##
## Aucun texte visible, aucun chiffre de jeu, aucune collision : apparence seulement.
extends RefCounted

## « -- --no-lieux-cuits » : dessin direct (comparaisons, banc).
static var enabled := true
## Résolution de cuisson (pixels de l'atlas par pixel du monde) et suréchantillonnage.
static var scale := 1.5
static var ss := 2
const PAD := 4
const ATLAS_W := 2048
## Mémoire des images gardées : au-delà, les jeux qui n'ont pas servi depuis UNUSED_MSEC sont rendus
## (recuits s'ils reviennent à l'écran).
const BUDGET := 24 * 1024 * 1024
const UNUSED_MSEC := 4000

## Jeu -> {"tex": ImageTexture, "cells": {clé: [src (Rect2, pixels de l'atlas), box (Rect2, monde)]}, "bytes": int}
static var sets := {}
static var _pending := {}
static var _failed := {}
## Change à chaque fois qu'une image cuite apparaît ou disparaît : un nœud qui ne se redessine pas à chaque
## image (les pierres du sanctuaire) compare son numéro au dernier dessin. Sinon ses commandes de dessin,
## gardées d'un dessin à l'autre, pointent vers une texture rendue et s'affichent en tache blanche.
static var epoch := 0
## Textures rendues depuis moins de GRAVE_MSEC : gardées vivantes le temps que les nœuds se redessinent.
const GRAVE_MSEC := 1500
static var _grave := []
## Mesures (banc, tests).
static var bytes := 0
static var bake_usec := 0
static var baked := 0
static var _material: ShaderMaterial
static var _configured := false


## Peint une liste de dessins à leur place dans l'atlas.
class Painter extends Node2D:
	var jobs := []
	var k := 1.0

	func _draw() -> void:
		for j in jobs:
			draw_set_transform(j["origin"] * k, 0.0, Vector2.ONE * j["scale"] * k)
			j["paint"].call(self)
		draw_set_transform_matrix(Transform2D.IDENTITY)


static func configure() -> void:
	if _configured:
		return
	_configured = true
	for a in OS.get_cmdline_user_args():
		if a == "--no-lieux-cuits":
			enabled = false


static func material() -> ShaderMaterial:
	if _material == null:
		_material = ShaderMaterial.new()
		_material.shader = load("res://shaders/lieux_baked.gdshader")
	return _material


## Prépare un nœud qui dessine des lieux cuits (matériau en alpha prémultiplié, filtre avec mipmaps).
static func prepare(n: CanvasItem) -> void:
	n.material = material()
	n.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS


static func ready(set_key: String) -> bool:
	# Appelé à chaque passage des lieux : de quoi vider le cimetière des textures sans minuterie.
	_empty_grave()
	return sets.has(set_key)


## Demande la cuisson d'un jeu. jobs : [{"key", "box" (Rect2 autour du pied, pixels du monde),
## "paint" (Callable(ci) qui dessine pied en (0, 0))}]. host : un nœud de l'arbre. Sans effet si le jeu
## est cuit, en cours, ou impossible à cuire.
static func request(host: Node, set_key: String, jobs: Array) -> void:
	configure()
	if not enabled or sets.has(set_key) or _pending.has(set_key) or _failed.has(set_key):
		return
	if host == null or not host.is_inside_tree() or DisplayServer.get_name() == "headless":
		_failed[set_key] = true
		return
	_pending[set_key] = true
	_empty_grave()
	trim()
	_bake(host, set_key, jobs)


static func _bake(host: Node, set_key: String, jobs: Array) -> void:
	var t0 := Time.get_ticks_usec()
	# Rangement en étagères, les plus hautes d'abord.
	var order := jobs.duplicate()
	order.sort_custom(func(a, c): return a["box"].size.y > c["box"].size.y)
	var x := 0.0
	var y := 0.0
	var shelf := 0.0
	var placed := []
	for j in order:
		var box: Rect2 = j["box"]
		var cell: Vector2 = (box.size * scale).ceil() + Vector2.ONE * PAD * 2
		if x + cell.x > ATLAS_W and x > 0.0:
			x = 0.0
			y += shelf
			shelf = 0.0
		var src := Rect2(Vector2(x, y), cell)
		placed.append({"key": j["key"], "box": box, "src": src, "paint": j["paint"],
			"origin": src.position + Vector2.ONE * PAD - box.position * scale, "scale": scale})
		x += cell.x
		shelf = maxf(shelf, cell.y)
	var w := 0.0
	for p in placed:
		w = maxf(w, p["src"].end.x)
	var size := Vector2i(int(w), int(y + shelf))
	var vp := SubViewport.new()
	vp.size = size * ss
	vp.transparent_bg = true
	vp.disable_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	vp.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	var painter := Painter.new()
	painter.jobs = placed
	painter.k = ss
	vp.add_child(painter)
	var tree := host.get_tree()
	tree.root.add_child(vp)
	await tree.process_frame
	await RenderingServer.frame_post_draw
	var tex := vp.get_texture()
	var img: Image = tex.get_image() if tex != null else null
	vp.queue_free()
	_pending.erase(set_key)
	if img == null or img.is_empty():
		_failed[set_key] = true
		return
	if ss > 1:
		img.resize(img.get_width() / ss, img.get_height() / ss, Image.INTERPOLATE_TRILINEAR)
	img.generate_mipmaps()
	var cells := {}
	for p in placed:
		cells[p["key"]] = [p["src"], p["box"]]
	epoch += 1
	sets[set_key] = {"tex": ImageTexture.create_from_image(img), "cells": cells, "bytes": img.get_data_size(), "used": Time.get_ticks_msec()}
	bytes += img.get_data_size()
	baked += 1
	bake_usec = Time.get_ticks_usec() - t0


## Dessine l'image cuite « key » du jeu « set_key », pied en at, agrandie de k, teinte mod (alpha :
## fondu enchaîné). Faux si le jeu n'est pas (encore) cuit : le lieu se dessine alors en direct.
static func draw(ci: CanvasItem, set_key: String, key: String, at := Vector2.ZERO, k := 1.0, mod := Color.WHITE) -> bool:
	var s = sets.get(set_key)
	if s == null:
		return false
	var c = s["cells"].get(key)
	if c == null:
		return false
	s["used"] = Time.get_ticks_msec()
	var src: Rect2 = c[0]
	var box: Rect2 = c[1]
	var pad := PAD / scale
	var dst := Rect2(at + (box.position - Vector2(pad, pad)) * k, (src.size / scale) * k)
	ci.draw_texture_rect_region(s["tex"], dst, src, mod)
	return true


## Au-delà du budget, rend les jeux qui n'ont pas servi depuis UNUSED_MSEC, les plus anciens d'abord.
static func trim() -> int:
	var n := 0
	if bytes <= BUDGET:
		return n
	var keys := sets.keys()
	keys.sort_custom(func(a, b): return int(sets[a]["used"]) < int(sets[b]["used"]))
	var now := Time.get_ticks_msec()
	for key in keys:
		if bytes <= BUDGET:
			break
		if now - int(sets[key]["used"]) > UNUSED_MSEC:
			release(key)
			n += 1
	return n


## Oublie un jeu (sa mémoire est rendue ; il sera recuit s'il revient).
static func release(set_key: String) -> void:
	var s = sets.get(set_key)
	if s != null:
		bytes -= int(s["bytes"])
		sets.erase(set_key)
		epoch += 1
		# La texture reste vivante un instant : les commandes de dessin déjà posées la référencent encore.
		_grave.append([Time.get_ticks_msec(), s["tex"]])
	_empty_grave()


static func _empty_grave() -> void:
	var now := Time.get_ticks_msec()
	while not _grave.is_empty() and now - int(_grave[0][0]) > GRAVE_MSEC:
		_grave.pop_front()


## Rend toutes les images et le matériau (fin de partie : rien ne doit rester en mémoire à la sortie).
static func clear() -> void:
	sets.clear()
	_grave.clear()
	epoch += 1
	_material = null
	_pending.clear()
	_failed.clear()
	bytes = 0
