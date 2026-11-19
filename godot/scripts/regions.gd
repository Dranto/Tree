## Régions du monde : chaque branche de l'arbre a son secteur, dans la même direction que
## dans l'Arbre de vie, au-delà de l'oasis de départ.
##
## Une région est décrite tout entière par un fichier res://data/regions/<id>.json (format dans
## data/README.md, « Régions ») : palette du sol, décor, apparitions, sanctuaires, autels, secret,
## Cœur et boss. Ajouter une région, c'est écrire ce fichier (et les scripts qu'il nomme) : la
## liste des régions est lue dans ce dossier, rangée dans l'ordre des branches de tree.json.
##
## Logique pure (aucun nœud) : utilisée par main.gd (region_at, region_center, apparitions),
## ground.gd (teinte du sol), flora.gd (décor), sanctuaires, autels, Cœurs et arènes.
extends RefCounted

const Content = preload("res://scripts/content.gd")

const DIR := "res://data/regions/"
## Distance à la graine où commence une région (l'oasis de départ fait 260 px de rayon).
const INNER := 430.0
## Distance du centre d'une région (là où se dresse son Cœur de flétrissure).
const CENTER_DIST := 1650.0
## Largeur du fondu entre une région et le reste du monde (en pixels, de part et d'autre du bord).
const EDGE := 110.0
## Au plus une région par branche : six.
const MAX_REGIONS := 6
## Le monde est un carré de ± WORLD_HALF px autour de la graine (main.world_half). Les six secteurs
## n'y ont pas la même profondeur : ceux de Spore (est) et d'Aube (ouest) ne touchent aucun coin et
## s'arrêtent à WORLD_HALF dans leur axe ; les quatre autres vont jusqu'à WORLD_HALF / sin 60°
## (3349 px). Voir reach() et la vérification des lieux dans validate().
const WORLD_HALF := 2900.0
## Marge entre un lieu (ou le mur d'une arène) et le bord du monde.
const WORLD_MARGIN := 60.0
## Dossier des dessins propres à une région (champ « art » du fichier de la région) : son Cœur de
## flétrissure et le mur de l'arène de son boss. Sans « art », ceux du roncier (region_art.gd).
const ART_DIR := "res://scripts/region_art/"
const BASE_ART := "res://scripts/region_art.gd"

## Dossiers de régions en plus de data/regions/ (la région factice des tests, voir
## tests/region_engine_test.gd), à poser avec set_extra_dirs. Aussi par la ligne de commande :
## -- --regions=res://tests/regions/
static var extra_dirs: Array = []
static var _defs: Dictionary = {}
static var _ids: Array = []
static var _loaded := false
static var _arts: Dictionary = {}


## Identifiants des régions qui existent, dans l'ordre des branches de l'arbre.
static func ids() -> Array:
	_load_all()
	return _ids


## Description d'une région (data/regions/<id>.json), {} si elle n'existe pas.
static func def(id: String) -> Dictionary:
	_load_all()
	return _defs.get(id, {})


static func exists(id: String) -> bool:
	_load_all()
	return _defs.has(id)


## Branche de l'arbre dont la région occupe le secteur (par défaut, son identifiant).
static func branch_of(id: String) -> String:
	return str(def(id).get("branch", id))


## Ajoute des dossiers de régions (la région factice des tests) et relit tout. Passer par cette
## fonction : une affectation de extra_dirs depuis un autre script ne prend pas (Godot 4.3).
static func set_extra_dirs(dirs: Array) -> void:
	extra_dirs = dirs
	reload()


## Relit les régions (après un changement de extra_dirs, dans les tests).
static func reload() -> void:
	_loaded = false
	_defs = {}
	_ids = []
	_arts = {}
	Content._cache.erase("#rewards")
	_load_all()


static func _load_all() -> void:
	if _loaded:
		return
	_loaded = true
	var dirs: Array = [DIR] + extra_dirs
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--regions="):
			dirs.append(arg.substr(10))
	var found := {}
	for dir in dirs:
		# Une région des tests (dossiers en plus) n'occupe qu'un secteur resté libre : la vraie région
		# d'une branche l'emporte sur sa région factice (tests/regions/seve.json, aube.json).
		var taken := {}
		for id in found:
			taken[str(found[id].get("branch", id))] = true
		for file in DirAccess.get_files_at(dir):
			# Dans un jeu exporté, les fichiers importés portent un suffixe (.remap, .import).
			if not file.ends_with(".json"):
				continue
			var path: String = dir.path_join(file)
			var data = JSON.parse_string(FileAccess.get_file_as_string(path))
			if not data is Dictionary:
				push_error("Région illisible : " + path)
				continue
			var id := str(data.get("id", file.get_basename()))
			if dir != DIR and (taken.has(str(data.get("branch", id))) or found.has(id)):
				continue
			data["id"] = id
			data["_path"] = path
			found[id] = data
	# Ordre des branches de l'arbre : il fixe aussi l'ordre des Cœurs, des objectifs et de la carte.
	var branches: Array = Content.tree().get("branches", [])
	var order := found.keys()
	order.sort_custom(func(a, b):
		var ia := branches.find(str(found[a].get("branch", a)))
		var ib := branches.find(str(found[b].get("branch", b)))
		return ia < ib if ia != ib else str(a) < str(b))
	for id in order:
		_ids.append(id)
		_defs[id] = found[id]


## Angle (radians) du milieu du secteur de la région (ou de la branche du même nom), comme dans
## skill_tree.gd.
static func angle_of(id: String) -> float:
	var ids_: Array = Content.tree().get("branches", [])
	var bi := ids_.find(branch_of(id) if exists(id) else id)
	if bi < 0:
		return 0.0
	var sector := TAU / ids_.size()
	return bi * sector - PI / 2.0 + sector / 2.0


## Demi-ouverture d'un secteur (radians).
static func half_width() -> float:
	return PI / maxf(1.0, Content.tree().get("branches", []).size())


## Normales intérieures des deux bords du secteur (le secteur fait moins d'un demi-tour :
## un point est dedans s'il est du bon côté des deux bords).
static func edge_normals(id: String) -> Array:
	var a := angle_of(id)
	var h := half_width()
	return [-Vector2.from_angle(a - h).orthogonal(), Vector2.from_angle(a + h).orthogonal()]


## Distance (en pixels, positive à l'intérieur) entre une position et le bord de la région :
## le plus proche des deux bords du secteur et du cercle intérieur. Même calcul que le shader du sol.
static func inside_distance(pos: Vector2, id: String) -> float:
	var n := edge_normals(id)
	return minf(minf(pos.dot(n[0]), pos.dot(n[1])), pos.length() - INNER)


static func region_at(pos: Vector2) -> String:
	for id in ids():
		if inside_distance(pos, id) > 0.0:
			return id
	return ""


static func center(id: String) -> Vector2:
	return Vector2.from_angle(angle_of(id)) * CENTER_DIST


## Distance entre la graine et le bord du monde carré, dans la direction « angle ».
static func reach(angle: float) -> float:
	var d := Vector2.from_angle(angle)
	return WORLD_HALF / maxf(absf(d.x), absf(d.y))


## Vrai si le disque (pos, radius) tient dans le monde, à WORLD_MARGIN du bord.
static func fits_world(pos: Vector2, radius := 0.0) -> bool:
	var limit := WORLD_HALF - WORLD_MARGIN - radius
	return absf(pos.x) <= limit and absf(pos.y) <= limit


## Centre de l'arène du boss : au-delà du Cœur, à « offset » px dans l'axe de la région (boss ›
## arena), ramené dans le monde si le mur en sortirait. Même calcul pour boss_arena.gd et check_data.
static func arena_center(id: String) -> Vector2:
	var ar: Dictionary = section(id, "boss").get("arena", {})
	var radius := float(ar.get("radius", 470.0))
	var heart := center(id)
	var dir: Vector2 = heart.normalized() if heart.length() > 1.0 else Vector2.UP
	var limit := WORLD_HALF - radius - WORLD_MARGIN
	return (heart + dir * float(ar.get("offset", 800.0))).clamp(Vector2(-limit, -limit), Vector2(limit, limit))


## Dessins propres à la région (son Cœur, le mur de son arène) : scripts/region_art/<art>.gd, qui
## étend region_art.gd et n'en remplace que ce qui change ; sans « art », region_art.gd (le roncier).
static func art(id: String) -> GDScript:
	if not _arts.has(id):
		var name := str(def(id).get("art", ""))
		var path := ART_DIR + name + ".gd" if name != "" else BASE_ART
		_arts[id] = load(path if ResourceLoader.exists(path) else BASE_ART)
	return _arts[id]


## Appartenance progressive (0 dehors, 1 bien à l'intérieur) : sert au fondu du décor.
static func weight(pos: Vector2, id: String) -> float:
	return smoothstep(-EDGE, EDGE, inside_distance(pos, id))


## Région dont le décor remplace celui du reste du monde ici (appartenance de plus de « above »),
## "" ailleurs.
static func region_weighted(pos: Vector2, above := 0.5) -> String:
	for id in ids():
		if weight(pos, id) > above:
			return id
	return ""


## Position d'un lieu de la région : « dist » depuis la graine, et « side » (écart au milieu du
## secteur, de -1 à 1) ou « angle » (écart en radians).
static func place(id: String, spot: Dictionary) -> Vector2:
	var a := angle_of(id)
	if spot.has("angle"):
		a += float(spot["angle"])
	else:
		a += float(spot.get("side", 0.0)) * half_width()
	return Vector2.from_angle(a) * float(spot.get("dist", 0.0))


## Une section de la description de la région (« heart », « boss », « spawn »…), {} sans elle.
static func section(id: String, key: String) -> Dictionary:
	var v = def(id).get(key, {})
	return v if v is Dictionary else {}


## Drapeaux d'aventure d'une région.
static func heart_flag(id: String) -> String:
	return id + "_coeur_purifie"


static func boss_flag(id: String) -> String:
	return id + "_boss_vaincu"


## Séquence « région purifiée » déjà montrée (la fin de la tranche Ronce, avant le jalon 7).
static func ending_flag(id: String) -> String:
	return id + "_fin_vue"


## Vrai quand le boss de chaque région qui existe est vaincu (flags : Game.flags) : c'est la fin
## de l'aventure.
static func all_purified(flags: Dictionary) -> bool:
	if ids().is_empty():
		return false
	for id in ids():
		if not flags.get(boss_flag(id), false):
			return false
	return true


# --- Couleurs écrites dans les fichiers de régions ---

## Une couleur des données : "#rrggbb", un rôle de la charte ("sol_mort"), un élément et sa
## variante ("cendre/sombre", "racine/" ou "racine"), une couleur nommée de la région ("$rouille"),
## ou une recette : {"mix": [a, b, t]}, {"dark": [a, part]}, {"light": [a, part]}.
## Les recettes reprennent exactement les calculs de la charte (Color.lerp, darkened, lightened).
static func color(spec, named := {}) -> Color:
	if spec is Dictionary:
		if spec.has("mix"):
			var m: Array = spec["mix"]
			return color(m[0], named).lerp(color(m[1], named), float(m[2]))
		if spec.has("dark"):
			return color(spec["dark"][0], named).darkened(float(spec["dark"][1]))
		if spec.has("light"):
			return color(spec["light"][0], named).lightened(float(spec["light"][1]))
		push_error("Couleur de région inconnue : %s" % [spec])
		return Color.MAGENTA
	var s := str(spec)
	if s.begins_with("#"):
		return Color(s)
	if s.begins_with("$"):
		if named.has(s.substr(1)):
			return named[s.substr(1)]
		push_error("Couleur nommée inconnue : " + s)
		return Color.MAGENTA
	if "/" in s:
		var parts := s.split("/")
		return Art.ec(parts[0], parts[1] if parts[1] != "" else "couleur")
	if Art.PALETTE.has(s):
		return Art.c(s)
	if Art.ELEMENTS.has(s):
		return Art.ec(s)
	push_error("Couleur de région inconnue : " + s)
	return Color.MAGENTA


## Vrai si la couleur est bien écrite (check_data).
static func color_ok(spec, named := {}) -> bool:
	if spec is Dictionary:
		for k in ["mix", "dark", "light"]:
			if spec.has(k) and spec[k] is Array:
				var a: Array = spec[k]
				if k == "mix":
					return a.size() == 3 and color_ok(a[0], named) and color_ok(a[1], named)
				return a.size() == 2 and color_ok(a[0], named)
		return false
	var s := str(spec)
	if s.begins_with("#"):
		return Color.html_is_valid(s)
	if s.begins_with("$"):
		return named.has(s.substr(1))
	if "/" in s:
		var parts := s.split("/")
		return Art.ELEMENTS.has(parts[0]) and (parts[1] == "" or Art.ELEMENTS[parts[0]].has(parts[1]))
	return Art.PALETTE.has(s) or Art.ELEMENTS.has(s)


## Couleurs nommées d'une palette (« colors »), dans l'ordre : une couleur peut citer les précédentes.
static func named_colors(palette: Dictionary) -> Dictionary:
	var named := {}
	var raw = palette.get("colors", {})
	if raw is Dictionary:
		for k in raw:
			named[k] = color(raw[k], named)
	return named


# --- Vérification (scripts/check_data.gd) ---

## Erreurs dans les fichiers des régions (liste vide si tout va bien) : champs obligatoires,
## branches, couleurs, lieux, Cœur, boss et fin. Les apparitions sont vérifiées par
## enemy.gd › validate_kinds, les récompenses par content.gd.
static func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	var branches: Array = Content.tree().get("branches", [])
	var kinds := {}
	for k in Content._load("enemies").get("kinds", []):
		kinds[str(k.get("id", ""))] = true
	if ids().size() > MAX_REGIONS:
		errors.append("régions : %d au plus (une par branche)" % MAX_REGIONS)
	var by_branch := {}
	var places := {}
	for id in ids():
		var d := def(id)
		var w := "%s" % d.get("_path", id)
		for f in ["name", "place", "map_name", "color", "ground", "heart", "boss", "ending"]:
			if not d.has(f):
				errors.append("%s : champ « %s » manquant" % [w, f])
		var br := branch_of(id)
		if not br in branches:
			errors.append("%s : branche inconnue « %s » (voir tree.json › branches)" % [w, br])
		elif by_branch.has(br):
			errors.append("%s : la branche « %s » a déjà une région (%s)" % [w, br, by_branch[br]])
		by_branch[br] = id
		if d.has("color") and not color_ok(d["color"]):
			errors.append("%s : couleur « color » mal écrite" % w)
		# Sol : les couleurs obligatoires, écrites avec les couleurs nommées de la palette.
		var g := section(id, "ground")
		var named := {}
		var raw = g.get("colors", {})
		if raw is Dictionary:
			for k in raw:
				if not color_ok(raw[k], named):
					errors.append("%s, ground › colors : couleur « %s » mal écrite" % [w, k])
				else:
					named[k] = color(raw[k], named)
		for k in ["dead_dark", "dead_light", "purified_dark", "purified_light", "alive_dark", "alive_light", "dot"]:
			if not g.has(k):
				errors.append("%s, ground : couleur « %s » manquante" % [w, k])
			elif not color_ok(g[k], named):
				errors.append("%s, ground : couleur « %s » mal écrite" % [w, k])
		# Décor : une sorte connue (scripts/decor_<sorte>.gd).
		var decor := section(id, "decor")
		if decor.has("kind") and not ResourceLoader.exists("res://scripts/decor_%s.gd" % decor["kind"]):
			errors.append("%s, decor : sorte inconnue « %s » (scripts/decor_%s.gd)" % [w, decor["kind"], decor["kind"]])
		# Lieux : identifiants uniques dans tout le monde, position dans le secteur.
		for kind in ["sanctuaries", "altars", "secrets", "landmarks"]:
			var list = d.get(kind, [])
			if not list is Array:
				errors.append("%s : « %s » doit être une liste" % [w, kind])
				continue
			for spot in list:
				var key := "%s:%s" % [kind, spot.get("id", "")]
				if kind != "landmarks":
					if str(spot.get("id", "")) == "" or places.has(key):
						errors.append("%s, %s : identifiant absent ou en double « %s »" % [w, kind, spot.get("id", "")])
					places[key] = true
				if not (spot.get("dist") is float or spot.get("dist") is int):
					errors.append("%s, %s « %s » : « dist » manquant" % [w, kind, spot.get("id", spot.get("kind", "?"))])
				if absf(float(spot.get("side", 0.0))) > 1.0 or absf(float(spot.get("angle", 0.0))) > half_width():
					errors.append("%s, %s « %s » : hors du secteur" % [w, kind, spot.get("id", spot.get("kind", "?"))])
				elif not fits_world(place(id, spot)):
					errors.append("%s, %s « %s » : hors du monde (à %.0f px de la graine, le bord est à %.0f px dans cette direction)" % [
						w, kind, spot.get("id", spot.get("kind", "?")), float(spot.get("dist", 0.0)), reach(place(id, spot).angle())])
		# Cœur : sortes d'ennemis connues.
		var h := section(id, "heart")
		var hw: Dictionary = h.get("waves", {})
		var hk: Array = hw.get("kinds", []).duplicate()
		for extra in [hw.get("big", ""), h.get("idle", {}).get("kind", "")]:
			if str(extra) != "":
				hk.append(extra)
		for k in hk:
			if not kinds.has(str(k)):
				errors.append("%s, heart : sorte d'ennemi inconnue « %s »" % [w, k])
		if h.has("life_color") and not color_ok(h["life_color"]):
			errors.append("%s, heart : « life_color » mal écrite" % w)
		# Dessins de la région (Cœur, mur de l'arène) : un script de scripts/region_art/.
		if d.has("art") and not ResourceLoader.exists(ART_DIR + str(d["art"]) + ".gd"):
			errors.append("%s : dessins inconnus « %s » (scripts/region_art/%s.gd)" % [w, d["art"], d["art"]])
		# Le Cœur, sa zone et l'arène du boss tiennent dans le secteur et dans le monde.
		var zone := float(h.get("zone", 240.0))
		if inside_distance(center(id), id) < zone or not fits_world(center(id), zone):
			errors.append("%s, heart : la zone du Cœur (%.0f px) déborde du secteur ou du monde" % [w, zone])
		# Boss : un script qui étend BossBase.
		var b := section(id, "boss")
		var path := str(b.get("script", ""))
		if not ResourceLoader.exists(path):
			errors.append("%s, boss : script introuvable « %s »" % [w, path])
		elif not "extends BossBase" in FileAccess.get_file_as_string(path):
			# Lu comme texte : check_data tourne sans les autoloads dont les boss ont besoin.
			errors.append("%s, boss : « %s » doit étendre BossBase (scripts/boss_base.gd)" % [w, path])
		for k in ["bar_color"]:
			if b.has(k) and not color_ok(b[k]):
				errors.append("%s, boss : « %s » mal écrite" % [w, k])
		var ar: Dictionary = b.get("arena", {})
		if ar.has("life_color") and not color_ok(ar["life_color"]):
			errors.append("%s, boss › arena : « life_color » mal écrite" % w)
		if float(ar.get("radius_min", 0.0)) > float(ar.get("radius", 470.0)):
			errors.append("%s, boss › arena : « radius_min » plus grand que « radius »" % w)
		# L'arène tient dans le monde sans glisser hors de son axe (sinon arena_center la ramène de
		# biais, vers une région voisine) et son mur reste dans le secteur.
		var ac := arena_center(id)
		var ar_r := float(ar.get("radius", 470.0))
		var wanted := center(id) + center(id).normalized() * float(ar.get("offset", 800.0))
		if ac.distance_to(wanted) > 1.0:
			errors.append("%s, boss › arena : l'arène sort du monde (« offset » + « radius » au plus %.0f px dans ce secteur)" % [
				w, reach(angle_of(id)) - WORLD_MARGIN - CENTER_DIST])
		elif inside_distance(ac, id) < ar_r:
			errors.append("%s, boss › arena : le mur de l'arène déborde du secteur" % w)
		elif ac.distance_to(center(id)) < ar_r + zone:
			errors.append("%s, boss › arena : l'arène empiète sur la zone du Cœur" % w)
		for f in ["sub", "title", "body"]:
			if str(section(id, "ending").get(f, "")) == "":
				errors.append("%s, ending : « %s » manquant" % [w, f])
	return errors
