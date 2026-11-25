## Test du héros « Esprit masqué » (scripts/creature_art/heros/) : toutes les combinaisons existent et
## se dessinent sans erreur, et chacune se voit.
##   - chaque forme d'attaque et chaque modification de data/attack.json a son dessin, chaque branche
##     de data/branches/ sa tenue ;
##   - chaque arme × chaque tenue (6 branches, 15 hybrides, la graine) × trois paliers × repos et coup ;
##   - chaque arme × chaque modification seule, et toutes les modifications cumulées, à trois instants ;
##   - les tenues sont différentes deux à deux, un hybride diffère de ses deux branches ;
##   - les armes sont différentes deux à deux, chaque modification change l'image et diffère des autres ;
##   - en jeu (hero_look.gd, hero_bake.gd, HeroArt) : le build donne la tenue (parts par branche, frontières,
##     paliers) et l'attaque l'arme ; chaque branche, hybride, palier et arme, avec toutes les
##     modifications, se cuit sans case vide ni dessin coupé ; chaque pose de l'ancien héros existe ;
##     la taille à l'écran reste celle voulue.
## Rendu réel : tools/godot.sh --xvfb -s res://tests/heros_test.gd
extends SceneTree

const Bake = preload("res://tests/bestiaire/bake.gd")
const Esprit = preload("res://scripts/creature_art/heros/esprit.gd")
const Arme = preload("res://scripts/creature_art/heros/arme.gd")
const Ink = preload("res://scripts/creature_art/ink.gd")
const HeroLook = preload("res://scripts/hero_look.gd")
const HeroBake = preload("res://scripts/hero_bake.gd")
const SkillTree = preload("res://scripts/skill_tree.gd")

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

	await _en_jeu()

	if failures == 0:
		print("OK : toutes les combinaisons du héros existent et se voient.")
	else:
		print("ÉCHEC : %d vérification(s)" % failures)
	quit(1 if failures > 0 else 0)


## Le héros en jeu : apparence lue sur le build, cuisson, poses de HeroArt.
func _en_jeu() -> void:
	print("Le build donne l'apparence (hero_look.gd)")
	var bi := {}
	for i in SkillTree.BRANCHES.size():
		bi[SkillTree.BRANCHES[i]["id"]] = i
	var nodes := []
	var mk := func(br: String, ring: int, border: String) -> int:
		nodes.append({"branch": bi[br], "ring": ring, "border": bi[border] if border != "" else -1})
		return nodes.size() - 1
	var r1: int = mk.call("ronce", 1, "")
	var r2: int = mk.call("ronce", 2, "")
	var r5: int = mk.call("ronce", 5, "")
	var r9: int = mk.call("ronce", 9, "")
	var r12: int = mk.call("ronce", 12, "")
	var v2: int = mk.call("vent", 2, "")
	var v3: int = mk.call("vent", 3, "")
	var fr: int = mk.call("ronce", 3, "vent")
	var att := {"form": "fouet", "mods": {"saignement": 0.3, "fourche": 1.0, "taille": 0.0}}
	var none := HeroLook.compute(nodes, [], {"form": "graine", "mods": {}})
	check(none["voie"].is_empty() and none["evol"] == 0.0 and none["forme"] == "graine" and none["mods"].is_empty(), "sans nœud : la graine, au départ")
	var lk := HeroLook.compute(nodes, [r1, r2], att)
	check(lk["voie"] == {"ronce": 1.0} and lk["evol"] == 0.0, "deux nœuds de Ronce : tenue de Ronce, premier palier")
	check(lk["forme"] == "fouet" and lk["mods"] == ["fourche", "saignement"], "l'arme suit l'attaque (modifications actives, triées)")
	var ev := []
	for last in [r5, r9, r12]:
		ev.append(HeroLook.compute(nodes, [r1, last], att)["evol"])
	check(ev[0] > 0.0 and ev[0] < ev[1] and ev[1] < ev[2] and ev[2] == 1.0, "paliers des anneaux 4, 8 et 12 : la tenue se renforce (%s)" % [ev])
	var hy := HeroLook.compute(nodes, [r1, r2, v2, v3], att)
	check(hy["voie"] == {"ronce": 0.5, "vent": 0.5}, "hybride : parts des branches (%s)" % [hy["voie"]])
	var bo := HeroLook.compute(nodes, [fr], att)
	check(bo["voie"] == {"ronce": 0.5, "vent": 0.5}, "un nœud de frontière compte dans ses deux branches")
	var other := HeroLook.compute(nodes, [r1, r2], {"form": "massue", "mods": {}})
	check(HeroLook.body_key(other) == HeroLook.body_key(lk) and HeroLook.key(other) != HeroLook.key(lk), "changer d'attaque ne change que l'arme")
	check(HeroLook.key(hy) != HeroLook.key(lk), "changer de build change l'apparence")

	print("Cuisson (hero_bake.gd) : chaque branche, hybride, palier, chaque arme avec toutes les modifications")
	var host := Node.new()
	root.add_child(host)
	# Échelle fixe (en jeu, elle suit la fenêtre) : ×2,5, celle d'un écran 2560×1440.
	HeroBake.scale = 2.5
	var looks := []
	for br in Esprit.BRANCHES:
		looks.append({"voie": {br: 1.0}, "evol": 1.0, "forme": Esprit.FORME_DE[br], "mods": []})
	looks.append({"voie": {}, "evol": 0.0, "forme": "graine", "mods": []})
	looks.append({"voie": {"ronce": 0.6, "vent": 0.4}, "evol": 0.4, "forme": "echarde", "mods": ["fourche"]})
	looks.append({"voie": {"seve": 0.5, "aube": 0.5}, "evol": 0.72, "forme": "rayon", "mods": ["refraction", "rosee"]})
	for f in Arme.FORMES:
		looks.append({"voie": {"racine": 0.5, "aube": 0.5}, "evol": 1.0, "forme": f, "mods": Arme.ORNEMENTS.duplicate()})
	var t0 := Time.get_ticks_msec()
	var worst := 0
	var heights := {}
	for look in looks:
		HeroBake.clear()
		var sp: Dictionary = await HeroBake.bake(host, look)
		var what := "%s %.2f %s%s" % [_name(look["voie"]), look["evol"], look["forme"], " + toutes" if look["mods"].size() > 3 else ""]
		if not check_bool(sp.has("corps") and sp.has("bras"), what + " : cuit"):
			continue
		worst = maxi(worst, HeroBake.total_bytes())
		for layer in ["corps", "bras"]:
			var a = sp[layer]
			var img: Image = a.tex.get_image()
			img.clear_mipmaps()
			var imgs := {}
			for anim in a.anims:
				for i in a.anims[anim]:
					var cell := img.get_region(Rect2i(a.src(i)))
					imgs[i] = cell
					var used := cell.get_used_rect()
					check(used.size.x * used.size.y > 400, "%s : %s/%s case %d dessinée" % [what, layer, anim, i])
					# Rien de coupé : le dessin ne touche pas le bord de sa case.
					var inside := used.position.x > 0 and used.position.y > 0 and used.end.x < cell.get_width() and used.end.y < cell.get_height()
					check(inside, "%s : %s/%s case %d tient dans sa case (%s dans %s)" % [what, layer, anim, i, used, cell.get_size()])
					if layer == "corps" and anim == "idle" and i == 0:
						heights[what] = used.size.y / a.k
			var moves := "walk" if layer == "corps" else "attack"
			var seen := false
			for i in a.anims[moves]:
				seen = seen or _diff(imgs[i], imgs[a.anims["idle"][0]]) > MIN_DIFF
			check(seen, "%s : %s animé (%s)" % [what, layer, moves])
	print("  %d apparences cuites en %d ms, mémoire la plus haute %.1f Mo" % [looks.size(), Time.get_ticks_msec() - t0, worst / 1e6])
	check(worst < 30e6, "mémoire d'une apparence < 30 Mo")
	var h0: float = heights.get("graine 0.00 graine", 0.0)
	check(h0 >= 40.0 and h0 <= 56.0, "taille au départ : %.0f px du jeu (%.0f px en 1080p)" % [h0, h0 * 1.2])
	for k in heights:
		check(heights[k] <= 72.0, "%s : taille %.0f px du jeu (≤ 72)" % [k, heights[k]])

	print("Poses de HeroArt (dessin cuit et dessin direct)")
	HeroBake.clear()
	HeroArt.sprites = await HeroBake.bake(host, {"voie": {"ronce": 0.7, "vent": 0.3}, "evol": 0.72, "forme": "fouet", "mods": ["fourche", "saignement"]})
	var poses := [{}, {"walk": 1.0, "step": 1.2}, {"dash": 0.8}, {"a": 0.2}, {"a": 0.52}, {"a": 0.9}, {"cast": 0.7, "cast_col": Art.ec("epine")},
		{"hurt": 0.7}, {"low": 1.0}, {"invuln": 1.0}, {"home": true}, {"wither": 0.5}, {"wither": 1.0}, {"appear": 0.3}, {"appear": 0.8}, {"morph": 0.5}]
	for direct in [false, true]:
		var cells := []
		for po in poses:
			for face in [0.4, PI - 0.4, -PI * 0.5]:
				var st: Dictionary = po.duplicate()
				st["t"] = 0.4
				if direct:
					st["apparence"] = {"voie": {"seve": 1.0}, "evol": 0.4, "forme": "perle", "mods": ["rosee"]}
				cells.append([st, face])
		HeroArt.prev_sprites = HeroArt.sprites
		var big: Image = await b.bake(Vector2i(cells.size() * 120, 140), func(ci):
			for k in cells.size():
				HeroArt.draw(ci, Vector2(60 + k * 120, 80), 14.0, cells[k][1], cells[k][0])
			ci.draw_set_transform_matrix(Transform2D.IDENTITY), 1)
		HeroArt.prev_sprites = {}
		for k in cells.size():
			var img := big.get_region(Rect2i(k * 120, 0, 120, 140))
			check(_ink(img) > 200, "%s pose %s, regard %.1f : dessinée" % ["direct" if direct else "cuit", cells[k][0].keys(), cells[k][1]])
	var ghost: Image = await b.bake(Vector2i(120, 140), func(ci):
		HeroArt.draw_ghost(ci, Vector2(60, 80), 14.0, 0.0, Color(0.5, 1.0, 0.6, 0.5)), 1)
	check(_ink(ghost) > 200, "silhouette des images rémanentes (cases mono)")
	HeroArt.sprites = {}
	HeroBake.clear()
	HeroBake.scale = 0.0
	host.queue_free()


func check_bool(cond: bool, what: String) -> bool:
	check(cond, what)
	return cond


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
