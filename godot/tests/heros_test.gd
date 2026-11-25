## Test du héros « Esprit masqué » (scripts/creature_art/heros/) : toutes les combinaisons existent et
## se dessinent sans erreur, et chacune se voit.
##   - chaque forme d'attaque et chaque modification de data/attack.json a son dessin, chaque branche
##     de data/branches/ sa tenue ;
##   - chaque arme × chaque tenue (6 branches, 15 hybrides, la graine) × trois paliers × repos et coup ;
##   - chaque arme × chaque modification seule, et toutes les modifications cumulées, à trois instants ;
##   - les tenues sont différentes deux à deux, un hybride diffère de ses deux branches ;
##   - les armes sont différentes deux à deux, chaque modification change l'image et diffère des autres.
## Rendu réel : tools/godot.sh --xvfb -s res://tests/heros_test.gd
extends SceneTree

const Bake = preload("res://tests/bestiaire/bake.gd")
const Esprit = preload("res://scripts/creature_art/heros/esprit.gd")
const Arme = preload("res://scripts/creature_art/heros/arme.gd")
const Ink = preload("res://scripts/creature_art/ink.gd")

const CW := 340
const CH := 170
## Pixels qui doivent changer pour dire que deux images « se voient » différentes.
const MIN_DIFF := 25

var failures := 0
var b


func check(cond: bool, what: String) -> void:
	if not cond:
		failures += 1
		print("  ÉCHEC ", what)


func _initialize() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	_run.call_deferred()


func _run() -> void:
	b = Bake.new(self)
	var att: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/attack.json"))
	print("Tout ce que le jeu peut donner a un dessin")
	for f in att["forms"]:
		check(f in Arme.FORMES, "forme « %s » dessinée" % f)
	for f in Arme.FORMES:
		check(att["forms"].has(f), "forme « %s » existe dans attack.json" % f)
	for m in att["mods"]:
		check(m in Arme.ORNEMENTS, "modification « %s » a un ornement" % m)
	var branches := []
	for fn in DirAccess.get_files_at("res://data/branches"):
		if fn.ends_with(".json"):
			branches.append(fn.get_basename())
	for br in branches:
		check(br in Esprit.BRANCHES, "branche « %s » a une tenue" % br)
		check(Art.FEUILLES_BUILD.has(br), "branche « %s » a ses couleurs" % br)
		check(Esprit.FORME_DE.has(br) and Esprit.FORME_DE[br] in Arme.FORMES, "branche « %s » a une arme par défaut" % br)
	print("  %d formes, %d modifications, %d branches" % [att["forms"].size(), att["mods"].size(), branches.size()])

	# Tenues : la graine, chaque branche, chaque paire de branches.
	var voies: Array = [{}]
	for br in Esprit.BRANCHES:
		voies.append({br: 1.0})
	for i in Esprit.BRANCHES.size():
		for j in range(i + 1, Esprit.BRANCHES.size()):
			voies.append({Esprit.BRANCHES[i]: 0.55, Esprit.BRANCHES[j]: 0.45})
	var evols := [0.0, 0.5, 1.0]
	var poses := [-1.0, 0.62]
	print("Armes × tenues (%d tenues × %d paliers × %d instants)" % [voies.size(), evols.size(), poses.size()])
	var rest_by_form := {}
	for f in Arme.FORMES:
		var cells := []
		for v in voies:
			for e in evols:
				for a in poses:
					cells.append({"voie": v, "evol": e, "a": a, "forme": f, "t": 0.7, "look": 0.0, "mods": []})
		var imgs := await _render(cells)
		var pure := {}
		for k in cells.size():
			var o: Dictionary = cells[k]
			check(_ink(imgs[k]) > 300, "%s, %s, palier %.1f, a %.2f : dessiné" % [f, _name(o["voie"]), o["evol"], o["a"]])
			if o["evol"] == 1.0 and o["a"] < 0.0:
				pure[_name(o["voie"])] = imgs[k]
		for i in Esprit.BRANCHES.size():
			for j in range(i + 1, Esprit.BRANCHES.size()):
				var x: String = Esprit.BRANCHES[i]
				var y: String = Esprit.BRANCHES[j]
				check(_diff(pure[x], pure[y]) > MIN_DIFF * 10, "%s : tenues %s et %s différentes" % [f, x, y])
				var h := _name({x: 0.55, y: 0.45})
				check(_diff(pure[h], pure[x]) > MIN_DIFF and _diff(pure[h], pure[y]) > MIN_DIFF, "%s : l'hybride %s diffère de ses deux branches" % [f, h])
		rest_by_form[f] = pure
	for i in Arme.FORMES.size():
		for j in range(i + 1, Arme.FORMES.size()):
			var x: String = Arme.FORMES[i]
			var y: String = Arme.FORMES[j]
			for br in ["ronce", "aube"]:
				check(_diff(rest_by_form[x][br], rest_by_form[y][br]) > MIN_DIFF * 4, "armes %s et %s différentes (tenue %s)" % [x, y, br])

	print("Armes × modifications (seules et toutes cumulées)")
	var instants := [-1.0, 0.3, 0.62]
	for f in Arme.FORMES:
		var sets: Array = [[]]
		for m in Arme.ORNEMENTS:
			sets.append([m])
		sets.append(Arme.ORNEMENTS.duplicate())
		var cells := []
		for ms in sets:
			for a in instants:
				cells.append({"build": "ronce", "evol": 1.0, "a": a, "forme": f, "t": 0.7, "look": 0.0, "mods": ms})
		var imgs := await _render(cells)
		var n := instants.size()
		for k in cells.size():
			check(_ink(imgs[k]) > 300, "%s + %s, a %.2f : dessiné" % [f, ",".join(cells[k]["mods"]), cells[k]["a"]])
		for si in range(1, sets.size()):
			var seen := false
			for ai in n:
				seen = seen or _diff(imgs[si * n + ai], imgs[ai]) > MIN_DIFF
			check(seen, "%s : la modification « %s » se voit" % [f, ",".join(sets[si]) if sets[si].size() < 3 else "toutes"])
		for si in range(1, sets.size() - 1):
			for sj in range(si + 1, sets.size() - 1):
				var apart := false
				for ai in n:
					apart = apart or _diff(imgs[si * n + ai], imgs[sj * n + ai]) > MIN_DIFF
				check(apart, "%s : « %s » et « %s » se distinguent" % [f, sets[si][0], sets[sj][0]])

	print("Silhouette (mode mono) et pose retournée")
	var mono := []
	for f in Arme.FORMES:
		mono.append({"build": "vent", "evol": 1.0, "a": 0.62, "forme": f, "t": 0.2, "look": PI, "mods": Arme.ORNEMENTS})
	Ink.mono = true
	var mimgs := await _render(mono)
	Ink.mono = false
	for k in mimgs.size():
		check(_ink(mimgs[k]) > 300, "%s : silhouette retournée dessinée" % mono[k]["forme"])

	if failures == 0:
		print("OK : toutes les combinaisons du héros existent et se voient.")
	else:
		print("ÉCHEC : %d vérification(s)" % failures)
	quit(1 if failures > 0 else 0)


## Dessine les poses dans une grille (une cuisson) et rend une image par case.
func _render(cells: Array) -> Array:
	var cols := 12
	var rows := int(ceil(cells.size() / float(cols)))
	var big: Image = await b.bake(Vector2i(cols * CW, rows * CH), func(ci):
		for k in cells.size():
			var o: Dictionary = cells[k]
			var origin := Vector2((k % cols) * CW, (k / cols) * CH)
			var feet := origin + Vector2(70, CH - 20) if o["look"] == 0.0 else origin + Vector2(CW - 70, CH - 20)
			Esprit.draw(ci, feet, Esprit.HEIGHT * 2.0, o)
		Ink.flash = 0.0, 1)
	var out := []
	for k in cells.size():
		out.append(big.get_region(Rect2i((k % cols) * CW, (k / cols) * CH, CW, CH)))
	return out


## Surface couverte par le dessin (rectangle des pixels non transparents).
static func _ink(img: Image) -> int:
	var r := img.get_used_rect()
	return r.size.x * r.size.y


## Écart entre deux images, en « pixels entièrement différents » (écart moyen natif × surface).
static func _diff(a: Image, c: Image) -> int:
	var m: Dictionary = a.compute_image_metrics(c, false)
	return int(float(m["mean"]) / 255.0 * a.get_width() * a.get_height())


static func _name(v: Dictionary) -> String:
	if v.is_empty():
		return "graine"
	var ks := v.keys()
	return "+".join(ks)
