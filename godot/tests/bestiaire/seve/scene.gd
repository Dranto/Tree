## Scène de combat avant / après des Flétris de Sève (R4) : la vraie partie, dans la vallée des sources,
## le héros et huit Flétris figés (Sangsues, Crapauds, Libellules, une Souche). Après : les mêmes acteurs
## aux mêmes places, dessinés dans la nouvelle direction (image cuite, lissée), par-dessus le jeu ; rien
## d'autre ne change (décor, sol, annonces, interface).
## Lancer (depuis la racine du dépôt) :
##   tools/godot.sh --xvfb --audio-driver Dummy --fixed-fps 60 --resolution 1920x1080 res://tests/bestiaire/seve/scene.tscn -- --seed=1234 --out=DOSSIER
extends Node

const MainScene = preload("res://scenes/main.tscn")
const Bake = preload("res://tests/bestiaire/bake.gd")
const C = preload("res://tests/bestiaire/commun.gd")
const Regions = preload("res://scripts/regions.gd")

var main
var b


## Calque d'un acteur : l'image cuite du nouveau dessin, pieds sur le point « feet » du nœud.
class Sprite extends Node2D:
	var tex: Texture2D
	var feet := Vector2.ZERO
	var box := Vector2.ZERO

	func _draw() -> void:
		draw_texture_rect(tex, Rect2(-feet, box), false)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var out := "user://bestiaire"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.get_slice("=", 1)
	DirAccess.make_dir_recursive_absolute(out)
	b = Bake.new(get_tree())
	main = MainScene.instantiate()
	main.autotest = true
	main.autotest_shots = []
	main.autotest_done = true
	add_child(main)
	main.tree_ui.play_intro = false
	main.autotest = false
	main.spawn_timer = 1.0e9
	var p = main.player
	p.set_physics_process(false)
	# Vallée des sources, aux deux tiers du rayon.
	var rc: Vector2 = main.region_center("seve")
	var spot: Vector2 = rc.normalized().rotated(float(_arg("--rot=", "0.05"))) * rc.length() * float(_arg("--rad=", "0.85"))
	p.position = spot
	p.reset_physics_interpolation()
	main.camera.reset_smoothing()
	await _frames(40)
	for e in main.enemies:
		if is_instance_valid(e):
			e.queue_free()
	main.enemies = []
	main.hud.glyphs.visible = false
	p.aim = Vector2(1, -0.2).normalized()
	# [sorte, décalage, pose (propriétés de enemy.gd)]
	var cast := [
		["sangsue_vase", Vector2(330, -170), {"state": "windup", "state_t": 0.25}],
		["sangsue_vase", Vector2(-360, -110), {"walk": 1.0, "moving": 1.0}],
		["crapaud", Vector2(420, 150), {"walk": 2.4, "moving": 1.0}],
		["crapaud", Vector2(-260, 200), {"state": "windup", "state_t": 0.3}],
		["libellule", Vector2(180, 40), {}],
		["libellule", Vector2(60, -260), {"state": "windup", "state_t": 0.2}],
		["souche", Vector2(-120, -230), {"state": "windup", "state_t": 0.5}],
		["sangsue_vase", Vector2(-420, 60), {"walk": 2.0, "moving": 1.0}],
	]
	var list := []
	for c in cast:
		var e = main.spawn_enemy_kind(c[0], spot + c[1] * 0.78, 1.0)
		e.t = 0.5
		for k in c[2]:
			e.set(k, c[2][k])
		# Les annonces visent à côté du héros : il reste visible (pas sous le voile rouge).
		e.attack_dir = (spot + Vector2(0, -110) - e.position).normalized()
		e.face = e.attack_dir
		e.cd = 99.0
		e.set_process(false)
		e.set_physics_process(false)
		list.append(e)
	main.hud.banner_queue = []
	main.hud.banner_time = 0.0
	await _frames(8)
	main.hud.banner_queue = []
	main.hud.banner_time = 0.0
	await _frames(2)
	var before := await _grab()
	before.save_png(out + "/scene_avant.png")
	# Après : chaque acteur reçoit son calque, l'ancien dessin du corps est caché.
	for e in list:
		var kind: String = e.kind_id
		var o := {"t": 0.5, "walk": e.walk, "moving": e.moving, "look": (spot - e.position).angle()}
		if e.state == "windup":
			o["k"] = e.windup_ratio()
		if e.state == "windup":
			o["state"] = "windup"
		var box: Vector2 = {"sangsue_vase": Vector2(120, 70), "crapaud": Vector2(110, 90), "libellule": Vector2(120, 110), "souche": Vector2(130, 140)}[kind]
		var feet := Vector2(box.x * 0.5, box.y * 0.85)
		await _attach(e, kind, o, box, feet, Vector2(0, e.radius * 0.45))
		e._body.visible = false
	p.self_modulate = Color(1, 1, 1, 0)
	await _attach(p, "heros", {"t": 0.5, "look": p.aim.angle(), "build": "seve"}, Vector2(220, 150), Vector2(110, 110), Vector2(0, 11))
	await _frames(4)
	var after := await _grab()
	after.save_png(out + "/scene_apres.png")
	# Avant | après côte à côte : la moitié centrale de chaque capture.
	var w := before.get_width()
	var h := before.get_height()
	var comp := Image.create(w, h, false, Image.FORMAT_RGB8)
	comp.blit_rect(before, Rect2i(w / 4, 0, w / 2, h), Vector2i(0, 0))
	comp.blit_rect(after, Rect2i(w / 4, 0, w / 2, h), Vector2i(w / 2, 0))
	comp.fill_rect(Rect2i(w / 2 - 2, 0, 4, h), Art.c("or"))
	comp.save_png(out + "/scene_avant_apres.png")
	# Gros plan ×2 autour du héros (les deux, l'un au-dessus de l'autre).
	var zoom := Image.create(w, h, false, Image.FORMAT_RGB8)
	for i in 2:
		var src: Image = [before, after][i]
		var part := src.get_region(Rect2i(w / 2 - 480, h / 2 - 135, 960, 270))
		part.resize(1920, 540, Image.INTERPOLATE_NEAREST)
		zoom.blit_rect(part, Rect2i(0, 0, 1920, 540), Vector2i(0, i * 540))
	zoom.fill_rect(Rect2i(0, 538, w, 4), Art.c("or"))
	zoom.save_png(out + "/scene_zoom.png")
	get_tree().quit(0)


func _attach(node: Node2D, kind: String, o: Dictionary, box: Vector2, feet: Vector2, at: Vector2) -> void:
	# Cuite à ×2 (pixels du jeu) puis ×4 de lissage : nette une fois étirée en 1080p.
	var img: Image
	if kind == "heros":
		img = await b.bake(Vector2i(box * 2.0), func(ci): C.draw_after(ci, kind, feet * 2.0, 2.0, o))
	else:
		var art = load("res://scripts/creature_art/seve/%s.gd" % kind)
		img = await b.bake(Vector2i(box * 2.0), func(ci): art.draw(ci, feet * 2.0, art.HEIGHT * 2.0, o))
	var s := Sprite.new()
	s.tex = ImageTexture.create_from_image(img)
	s.feet = feet
	s.box = box
	s.position = at
	s.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	node.add_child(s)
	if node.get_child_count() > 2 and node != main.player:
		node.move_child(s, 1)


func _arg(key: String, def: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with(key):
			return a.substr(key.length())
	return def


func _grab() -> Image:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	return img


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
