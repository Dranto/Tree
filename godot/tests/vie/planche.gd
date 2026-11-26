## Planche des formes guéries et de la faune d'une région (tâche F) : pour chaque sorte, le Flétri (à gauche, sur
## le sol flétri) puis sa forme guérie au repos, en marche et à la taille réelle en 1080p (sur le sol ravivé) ;
## pour la faune, chaque espèce dans ses poses. Sortie : un PNG par région et par rangée (compose.py ajoute les
## légendes). Mode daltonien facultatif : ce que voit un joueur daltonien.
##   tools/godot.sh --xvfb -s res://tests/vie/planche.gd -- <dossier> [aucun|protanopie|deuteranopie|tritanopie]
extends SceneTree

const Bake = preload("res://tests/bestiaire/bake.gd")
const Vie = preload("res://scripts/world_life_vie.gd")
const Ink = preload("res://scripts/creature_art/ink.gd")

const COL := 250
const ROW := 250
const BIG := 3.4
const S1080 := 1.2


func _initialize() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	_run.call_deferred()


func _soil(reg: String, state: String) -> Color:
	var r := reg if Art.MONDE.get(reg, {}).has(state) else "ronce"
	var d: Dictionary = Art.MONDE.get(r, {}).get(state, {})
	return d.get("sol", Color("5a4a3a"))


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out := args[0]
	var mode: String = args[1] if args.size() > 1 else "aucun"
	DirAccess.make_dir_recursive_absolute(out)
	Art._set_bestiaire_mode(mode)
	var b := Bake.new(self)
	for reg in Vie.REGIONS:
		var g = Vie.script_of(reg, "gueri")
		var f = Vie.script_of(reg, "faune")
		var ids: Array = g.FORMES.keys() if g != null else []
		for i in ids.size():
			var id: String = ids[i]
			var img: Image = await b.bake(Vector2i(COL * 4, ROW), func(ci): _row_gueri(ci, reg, id, g), 2)
			img.save_png("%s/%s_gueri_%02d_%s_%s.png" % [out, reg, i, id, mode])
		var fids: Array = f.FORMES.keys() if f != null else []
		for i in fids.size():
			var id: String = fids[i]
			var img: Image = await b.bake(Vector2i(COL * 4, ROW), func(ci): _row_faune(ci, reg, id, f), 2)
			img.save_png("%s/%s_faune_%02d_%s_%s.png" % [out, reg, i, id, mode])
	print("planches dans ", out)
	quit(0)


func _row_gueri(ci: CanvasItem, reg: String, id: String, g) -> void:
	Ink.no_shadow = false
	var h: float = g.FORMES[id]["h"]
	var poses: Dictionary = g.FORMES[id]["poses"]
	ci.draw_rect(Rect2(0, 0, COL, ROW), _soil(reg if reg != "commun" else "ronce", "fletri"))
	ci.draw_rect(Rect2(COL, 0, COL * 3, ROW), _soil(reg if reg != "commun" else "ronce", "ravive"))
	var path := "res://scripts/creature_art/%s/%s.gd" % [reg, id]
	if ResourceLoader.exists(path):
		var fa = load(path)
		fa.draw(ci, Vector2(COL * 0.5, ROW - 38), fa.HEIGHT * BIG, {"t": 0.4, "look": 0.25, "region": reg})
	var rest := "repos" if poses.has("repos") else "vol"
	var move := "marche" if poses.has("marche") else "vol"
	g.draw(ci, Vector2(COL * 1.5, ROW - 38), h * BIG, Vie.pose_of(id, rest, 0, int(poses[rest])))
	g.draw(ci, Vector2(COL * 2.5, ROW - 38), h * BIG, Vie.pose_of(id, move, 1, int(poses[move])))
	# Taille réelle en 1080p : le Flétri (à gauche) et sa forme guérie côte à côte.
	if ResourceLoader.exists(path):
		var fa2 = load(path)
		fa2.draw(ci, Vector2(COL * 3.25, ROW - 60), fa2.HEIGHT * S1080, {"t": 0.4, "look": 0.25, "region": reg})
	g.draw(ci, Vector2(COL * 3.7, ROW - 60), h * S1080, Vie.pose_of(id, rest, 0, int(poses[rest])))


func _row_faune(ci: CanvasItem, reg: String, id: String, f) -> void:
	Ink.no_shadow = false
	var h: float = f.FORMES[id]["h"]
	ci.draw_rect(Rect2(0, 0, COL * 4, ROW), _soil(reg, "ravive"))
	var x := 0
	var frames := []
	for pose in f.FORMES[id]["poses"]:
		for i in int(f.FORMES[id]["poses"][pose]):
			frames.append([pose, i, int(f.FORMES[id]["poses"][pose])])
	var n := mini(frames.size(), 6)
	var step := float(COL * 3) / n
	for k in n:
		var fr: Array = frames[k]
		f.draw(ci, Vector2(step * (k + 0.5), ROW - 40), h * 3.0, Vie.pose_of(id, fr[0], fr[1], fr[2]))
	# Taille réelle en 1080p, avec une silhouette de héros de 40 px pour l'échelle.
	f.draw(ci, Vector2(COL * 3.5, ROW - 60), h * S1080, Vie.pose_of(id, "repos" if f.FORMES[id]["poses"].has("repos") else "vol", 0, 2))
