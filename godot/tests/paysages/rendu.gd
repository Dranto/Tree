## Rendu « après » d'un paysage seul (sans le jeu ni l'interface), dessiné à ×2 puis réduit (Lanczos) :
## c'est l'aspect lissé qu'aura le décor cuit. Le cadre est celui de scripts/world_art/cadres.gd, aux
## positions réelles relevées par scene.gd (--real=cadre_<région>.json).
##   tools/godot.sh --xvfb --audio-driver Dummy -s res://tests/paysages/rendu.gd -- --region=ronce --etat=ravive --out=x.png
## Options : --size=1920x1080 (1280x800 : Steam Deck, le jeu montre alors 1600×1000 du monde),
##   --front=1 (avancée du bord de vie), --t=0.5, --real=FICHIER, --no-cast,
##   --gif=N --out=DOSSIER : N images du bord de vie qui avance (000.png …), --crop=x,y,w,h (px de sortie).
extends SceneTree

const Paysage = preload("res://scripts/world_art/paysage.gd")

const SS := 2


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	var size := Vector2i(1920, 1080)
	var sz := _arg("--size=", "1920x1080").split("x")
	size = Vector2i(int(sz[0]), int(sz[1]))
	# Le jeu montre 1600 px du monde en largeur (900 en hauteur au moins : « expand »).
	var k := size.x / 1600.0
	var world := Vector2(1600.0, maxf(900.0, size.y / k))
	k = minf(size.x / world.x, size.y / world.y)
	var vp := SubViewport.new()
	vp.size = size * SS
	vp.disable_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var p := Paysage.new()
	p.setup(_arg("--region=", "ronce"), _arg("--real=", ""))
	p.etat = _arg("--etat=", "fletri")
	p.front = float(_arg("--front=", "1"))
	p.t = float(_arg("--t=", "0.5"))
	p.show_cast = not OS.get_cmdline_user_args().has("--no-cast")
	var c: Vector2 = p.cadre["center"]
	p.view = Rect2(c - world * 0.5, world)
	p.scale = Vector2(k, k) * SS
	p.position = -p.view.position * k * SS
	vp.add_child(p)
	var out := _arg("--out=", "/tmp/paysage.png")
	var frames := int(_arg("--gif=", "0"))
	var crop := _arg("--crop=", "")
	if frames <= 0:
		_save(await _grab(vp, size), out, crop)
		quit(0)
		return
	DirAccess.make_dir_recursive_absolute(out)
	p.etat = "ravive"
	for i in frames:
		# Le bord de vie part du Cœur et ralentit en arrivant (3,5 s à 24 images/s).
		var u := float(i) / maxi(frames - 1, 1)
		p.front = 0.04 + 0.96 * (1.0 - pow(1.0 - minf(u * 1.15, 1.0), 2.2))
		p.front_grow = 1.0
		p.t = 0.5 + i / 24.0
		p._lp_r = -1.0
		p.queue_redraw()
		_save(await _grab(vp, size), out + "/%03d.png" % i, crop)
	quit(0)


func _grab(vp: SubViewport, size: Vector2i) -> Image:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	img.resize(size.x, size.y, Image.INTERPOLATE_LANCZOS)
	return img


func _save(img: Image, path: String, crop: String) -> void:
	if crop != "":
		var v := crop.split(",")
		img = img.get_region(Rect2i(int(v[0]), int(v[1]), int(v[2]), int(v[3])))
	img.save_png(path)


func _arg(key: String, def: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with(key):
			return a.substr(key.length())
	return def
