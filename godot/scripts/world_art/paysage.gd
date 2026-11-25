## Un paysage de la planche « Paysages d'herbier » (refonte du monde, vague 0, tâche W) : sol en couches,
## décor composé, lieux, personnages et air, dessinés dans le repère du monde pour un cadre de cadres.gd.
## Rien n'est branché dans le jeu : la planche pose ce nœud par-dessus la vraie partie (captures
## « après ») ou le dessine seul (GIF du bord de vie, lieux).
##
## Composition (au lieu d'un tirage uniforme) : une clairière dégagée où l'on se bat, une lisière dense
## autour (objets plus grands et plus serrés à mesure qu'on s'éloigne), un repère visible de loin, des
## objets de premier plan plus sombres sur le bord du bas. Le tri en hauteur mêle décor, lieux et
## personnages (le pied le plus bas passe devant).
extends Node2D

const Cadres = preload("res://scripts/world_art/cadres.gd")
const Regions = preload("res://scripts/regions.gd")
const O = preload("res://scripts/world_art/outils.gd")
const Sol = preload("res://scripts/world_art/sol.gd")
const Decor = preload("res://scripts/world_art/decor.gd")
const Lieux = preload("res://scripts/world_art/lieux.gd")
const Air = preload("res://scripts/world_art/air.gd")
const Ink = preload("res://scripts/creature_art/ink.gd")
const FletriArt = preload("res://scripts/fletri_art.gd")
const Tireur = preload("res://scripts/creature_art/ronce/tireur.gd")
const Scarabee = preload("res://scripts/creature_art/racine/scarabee.gd")
const Menhir = preload("res://scripts/creature_art/vent/menhir.gd")
const Esprit = preload("res://scripts/creature_art/heros/esprit.gd")

## Clairière de combat autour du héros (demi-axes, px du monde) et décalage de son centre.
const CLEARING := Vector2(470, 250)
## Objets de la lisière par région : [sorte, taille min, taille max, poids] ; « loin » = lisière dense.
const LISIERE := {
	"ronce": {
		"pres": [["buisson", 0.8, 1.2, 4], ["rocher", 0.7, 1.2, 1], ["muret", 0.9, 1.1, 1]],
		"loin": [["haie", 0.9, 1.4, 3], ["arbre", 0.85, 1.15, 2.5], ["buisson", 1.0, 1.4, 2], ["rocher", 1.0, 1.5, 0.5]],
	},
	"spore": {
		"pres": [["fougere", 0.8, 1.3, 3], ["roseaux", 0.8, 1.2, 3], ["rocher", 0.6, 1.0, 1], ["champignon", 0.35, 0.5, 2]],
		"loin": [["champignon", 0.6, 1.15, 2], ["roseaux", 1.0, 1.4, 2], ["tronc", 0.9, 1.2, 1], ["fougere", 1.1, 1.5, 2.5], ["rocher", 0.8, 1.2, 0.6]],
	},
}
## Repère de la région (grand, visible de loin) et sorte des objets de premier plan.
const REPERE := {"ronce": ["ruine", 1.0], "spore": ["chapeau_geant", 1.0]}
const PREMIER_PLAN := {"ronce": ["haie", "arbre"], "spore": ["champignon", "fougere"]}

var cadre: Dictionary
var region := "ronce"
## « fletri » : le Cœur vit ; « ravive » : le Cœur est purifié, la vie a repris autour de lui.
var etat := "fletri"
## Avancée du bord de vie (0 → 1 du rayon de vie) et pousse de l'herbe au front (0 → 1).
var front := 1.0
var front_grow := 1.0
var t := 0.5
var show_cast := true
## Rectangle du monde à couvrir (le cadre de la caméra).
var view := Rect2(-800, -450, 1600, 900)
## Positions réelles (monde) des personnages, sinon cadre.center + at.
var cast_pos: Array = []

var _decor: Array = []
## Lieux du cadre : {type: heart | sanctuary | altar, reg, pos, ours (le Cœur du cadre), size, zone}.
var _lieux: Array = []
var _regions: Array = []
var _lp := PackedVector2Array()
var _lp_r := -1.0
var _enemy_r := {}


func setup(reg: String, real_path := "") -> void:
	region = reg
	cadre = Cadres.get_cadre(reg)
	if real_path != "" and FileAccess.file_exists(real_path):
		_load_real(real_path)
	_load_radii()
	_find_lieux()
	_compose()


## Positions réelles relevées dans le jeu par tests/paysages/scene.gd (cadre_<région>.json).
func _load_real(path: String) -> void:
	var d = JSON.parse_string(FileAccess.get_file_as_string(path))
	var v := func(a): return Vector2(a[0], a[1])
	for k in ["heart_pos", "sanctuary_pos", "altar_pos"]:
		if d.has(k):
			cadre[k] = v.call(d[k])
	cast_pos = []
	for a in d.get("cast", []):
		cast_pos.append(v.call(a))
	if d.has("camera"):
		cadre["center"] = v.call(d["camera"])


## Tous les lieux visibles du cadre (régions dessinées : celles d'Art.MONDE), pas seulement ceux du cadre.
func _find_lieux() -> void:
	_lieux = []
	var area := Rect2(cadre["center"] - Vector2(950, 600), Vector2(1900, 1200))
	for reg in Art.MONDE:
		if reg == "commun" or not Regions.exists(reg):
			continue
		for s in Regions.heart_spots(reg):
			var ours: bool = reg == region and s["pos"].distance_to(cadre["heart_pos"]) < 60.0
			var pos: Vector2 = cadre["heart_pos"] if ours else s["pos"]
			if area.has_point(pos):
				_lieux.append({"type": "heart", "reg": reg, "pos": pos, "ours": ours, "size": float(s["size"]), "zone": float(s["zone"])})
		for s in Regions.def(reg).get("sanctuaries", []):
			var pos: Vector2 = cadre["sanctuary_pos"] if reg == region and s["id"] == cadre["sanctuary"] else Regions.place(reg, s)
			if area.has_point(pos):
				_lieux.append({"type": "sanctuary", "reg": reg, "pos": pos})
		for s in Regions.def(reg).get("altars", []):
			var pos: Vector2 = cadre["altar_pos"] if reg == region and s["id"] == cadre["altar"] else Regions.place(reg, s)
			if area.has_point(pos):
				_lieux.append({"type": "altar", "reg": reg, "pos": pos})


## Région d'un point (seulement celles qui ont des couleurs dans Art.MONDE, sinon celle du cadre).
func region_at(p: Vector2) -> String:
	var r: String = Regions.region_at(p)
	return r if r != "" and Art.MONDE.has(r) else region


## État du sol hors du bord de vie pour une région : apaisé dans la région ravivée, flétri ailleurs.
func outside_etat_of(reg: String) -> String:
	return outside_etat() if reg == region else "fletri"


## Régions dessinées dans la vue : [id, polygone (la vue coupée par les deux bords du secteur)].
func regions_in_view() -> Array:
	var r := view.grow(60.0)
	var rect := PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])
	var out := []
	var covered := false
	for reg in Art.MONDE:
		if reg == "commun" or not Regions.exists(reg):
			continue
		var poly := rect
		for n in Regions.edge_normals(reg):
			poly = _clip_half(poly, n)
		if poly.size() >= 3:
			out.append([reg, poly])
			covered = covered or reg == region
	if not covered:
		out.append([region, rect])
	return out


## Coupe un polygone convexe par le demi-plan p·n ≥ 0.
static func _clip_half(poly: PackedVector2Array, n: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	var k := poly.size()
	for i in k:
		var a := poly[i]
		var b := poly[(i + 1) % k]
		var da := a.dot(n)
		var db := b.dot(n)
		if da >= 0.0:
			out.append(a)
		if (da >= 0.0) != (db >= 0.0):
			out.append(a.lerp(b, da / (da - db)))
	return out


func _load_radii() -> void:
	var f := FileAccess.open("res://data/enemies.json", FileAccess.READ)
	var d = JSON.parse_string(f.get_as_text())
	for k in d["kinds"]:
		_enemy_r[k["id"]] = float(k.get("radius", 14.0))


# --- État en chaque point ---


func outside_etat() -> String:
	return "fletri" if etat == "fletri" else "apaise"


func life_center() -> Vector2:
	return cadre["heart_pos"]


func life_radius() -> float:
	return 0.0 if etat == "fletri" else float(cadre["life_radius"]) * front


func _r_at(a: float, base: float) -> float:
	return base * (1.0 + 0.045 * O.wave(a * 3.0, 1.3)) + 14.0 * O.wave(a * 11.0, 4.1)


## Contour du bord de vie (ondulé, net), vide quand le monde est flétri.
func life_poly() -> PackedVector2Array:
	var base := life_radius()
	if base <= 1.0:
		return PackedVector2Array()
	if absf(base - _lp_r) < 0.01:
		return _lp
	_lp = PackedVector2Array()
	var n := 220
	for i in n:
		var a := TAU * i / n
		_lp.append(life_center() + Vector2(cos(a), sin(a)) * maxf(_r_at(a, base), 4.0))
	_lp_r = base
	return _lp


func etat_at(p: Vector2) -> String:
	var base := life_radius()
	if base > 1.0:
		var d := p - life_center()
		if d.length() < _r_at(d.angle(), base):
			return "ravive"
	return outside_etat_of(region_at(p))


func decor_etat_at(p: Vector2) -> String:
	return etat_at(p)


func clearings() -> Array:
	return [[cadre["center"] + Vector2(20, 10), CLEARING]]


## Vrai si rien d'important (lieu, personnage) n'occupe le disque (p, r).
func free_at(p: Vector2, r: float) -> bool:
	for z in _exclusions():
		if p.distance_to(z[0]) < r + z[1]:
			return false
	return true


func _exclusions() -> Array:
	var out := []
	for l in _lieux:
		out.append([l["pos"], {"heart": 90.0, "sanctuary": 90.0, "altar": 40.0}[l["type"]]])
	for i in cadre["cast"].size():
		out.append([_cast_at(i), 26.0])
	out.append([cadre["center"], 34.0])
	return out


func _cast_at(i: int) -> Vector2:
	if i < cast_pos.size():
		return cast_pos[i]
	return cadre["center"] + cadre["cast"][i]["at"]


# --- Composition du décor ---


func _compose() -> void:
	_decor = []
	var rect := Rect2(cadre["center"] - Vector2(900, 540), Vector2(1800, 1080))
	var cl: Array = clearings()[0]
	var placed := []
	var cell := 56.0
	for y in range(int(rect.position.y / cell), int(rect.end.y / cell) + 1):
		for x in range(int(rect.position.x / cell), int(rect.end.x / cell) + 1):
			var r := O.rng_at(Vector2i(x, y), 301)
			var p := (Vector2(x, y) + Vector2(r.randf(), r.randf())) * cell
			var q: Vector2 = (p - cl[0]) / cl[1]
			var d := q.length()
			if d < 1.08:
				continue
			var dense := clampf((d - 1.08) / 0.4, 0.0, 1.0)
			if r.randf() > 0.18 + 0.6 * dense:
				continue
			var lis: Dictionary = LISIERE[region_at(p)]
			var list: Array = lis["loin"] if r.randf() < dense else lis["pres"]
			var pick: Array = _weighted(list, r)

			var size := r.randf_range(pick[1], pick[2]) * (1.0 + 0.2 * dense)
			var foot: float = Decor.HEIGHT[pick[0]] * size * (0.45 if pick[0] not in ["haie", "tronc", "muret"] else 0.9)
			if not free_at(p, foot * 0.6) or _hides(p, pick[0], size):
				continue
			# En haut du cadre, un objet haut serait coupé (un pied sans chapeau) : on en met un bas.
			if Decor.HEIGHT[pick[0]] * size > (p.y - rect.position.y - 90.0) * 1.1 and pick[0] in ["champignon", "arbre"]:
				pick = ["fougere" if region_at(p) == "spore" else "haie", 1.0, 1.3, 1]
				size = r.randf_range(1.0, 1.3)
			var ok := true
			for o in placed:
				if p.distance_to(o["at"]) < (foot + o["foot"]) * 0.42:
					ok = false
					break
			if not ok:
				continue
			var o := {"kind": pick[0], "at": p, "size": size, "seed": r.randi(), "flip": r.randf() < 0.5, "foot": foot}
			placed.append(o)
	_decor = placed
	# Repère : sur le lieu-repère du fichier de la région s'il tombe dans la lisière, sinon en haut à gauche.
	var rp: Vector2 = cadre.get("landmark_pos", Vector2.ZERO)
	if ((rp - cl[0]) / cl[1]).length() < 1.15 or cadre.has("repere_at"):
		rp = cadre["center"] + cadre.get("repere_at", Vector2(-560, -250))
	var rep := {"kind": REPERE[region][0], "at": rp, "size": REPERE[region][1], "seed": 7, "flip": false, "foot": 200.0}
	_decor = _decor.filter(func(o): return o["at"].distance_to(rp) > 130.0 + o["foot"] * 0.3)
	_decor.append(rep)
	# Premier plan : deux grandes masses plus sombres qui débordent du bas du cadre.
	var c: Vector2 = cadre["center"]
	for f in [[Vector2(-690, 500), 0, 2.1, false], [Vector2(730, 540), 1, 1.35, true], [Vector2(120, 560), 0, 1.6, true]]:
		var at: Vector2 = c + f[0]
		_decor.append({"kind": PREMIER_PLAN[region_at(at)][f[1]], "at": at, "size": f[2], "seed": 11 + f[1], "flip": f[3], "fg": 1.0, "foot": 0.0})


## Vrai si un objet haut posé en p cacherait un lieu ou un personnage placé derrière lui (plus haut à
## l'écran) : le décor encadre, il ne masque jamais ce qu'on doit lire.
func _hides(p: Vector2, kind: String, size: float) -> bool:
	var hh: float = Decor.HEIGHT[kind] * size
	var ww := hh * (0.9 if kind in ["champignon", "chapeau_geant", "arbre"] else 1.2)
	for z in _exclusions():
		var q: Vector2 = z[0]
		if q.y < p.y + 10.0 and q.y > p.y - hh - z[1] and absf(q.x - p.x) < ww * 0.5 + z[1]:
			return true
	return false


func _weighted(list: Array, r: RandomNumberGenerator) -> Array:
	var total := 0.0
	for e in list:
		total += e[3]
	var x := r.randf() * total
	for e in list:
		x -= e[3]
		if x <= 0.0:
			return e
	return list[0]


# --- Dessin ---


func _draw() -> void:
	paint(self)


func paint(ci: CanvasItem) -> void:
	var rect := view
	Sol.draw(ci, self, rect)
	Air.under(ci, self, rect)
	var items := []
	var fg := []
	for o in _decor:
		if not rect.grow(400.0).has_point(o["at"]):
			continue
		if o.get("fg", 0.0) > 0.0:
			fg.append(o)
		else:
			items.append([o["at"].y, func(): Decor.draw(ci, o, self)])
	for l in _lieux:
		var lp: Vector2 = l["pos"]
		var lr: String = l["reg"]
		var le := etat_at(lp)
		match l["type"]:
			"heart":
				var pur: bool = l["ours"] and etat == "ravive"
				items.append([lp.y, func(): Lieux.heart(ci, lr, lp, l["size"], pur, l["zone"], t)])
			"sanctuary":
				var lit := le == "ravive"
				items.append([lp.y - Lieux.SANCT_RY, func(): Lieux.sanctuary_stones(ci, lr, lp, le, lit, true)])
				items.append([lp.y - 1.0, func(): Lieux.sanctuary_center(ci, lr, lp, le, lit, t)])
				items.append([lp.y + Lieux.SANCT_RY * 0.3, func(): Lieux.sanctuary_stones(ci, lr, lp, le, lit, false)])
			"altar":
				items.append([lp.y, func(): Lieux.altar(ci, lr, lp, le, t)])
	if show_cast:
		for i in cadre["cast"].size():
			var c: Dictionary = cadre["cast"][i]
			var p := _cast_at(i)
			var feet := p + Vector2(0, _enemy_r.get(c["kind"], 14.0) * 0.45)
			items.append([feet.y, func(): _draw_enemy(ci, c, p, feet)])
		var hp: Vector2 = cadre["center"]
		items.append([hp.y + 6.0, func(): _draw_hero(ci, hp)])
	items.sort_custom(func(a, b): return a[0] < b[0])
	for it in items:
		it[1].call()
	fg.sort_custom(func(a, b): return a["at"].y < b["at"].y)
	for o in fg:
		Decor.draw(ci, o, self)
	Air.over(ci, self, rect)


func _hero_build() -> String:
	return "ronce" if region == "ronce" else "spore"


func _draw_hero(ci: CanvasItem, p: Vector2) -> void:
	var feet := p + Vector2(0, 11)
	Esprit.draw(ci, feet, Esprit.HEIGHT, {"t": t, "look": -0.2, "build": _hero_build()})
	Ink.flash = 0.0


func _draw_enemy(ci: CanvasItem, c: Dictionary, p: Vector2, feet: Vector2) -> void:
	var hero: Vector2 = cadre["center"] + Vector2(0, -20)
	var look := (hero - p).angle()
	var pose: Dictionary = c["pose"]
	var o := {"t": t + p.x * 0.01, "walk": pose.get("walk", 0.0), "moving": pose.get("moving", 0.0), "look": look}
	var windup: bool = pose.get("state", "") == "windup"
	if windup:
		o["k"] = 0.65
		var dir := (hero - p).normalized()
		ci.draw_set_transform(p)
		var r: float = _enemy_r.get(c["kind"], 14.0)
		if c["art"] == "tireur":
			Art.telegraph(ci, {"type": "ligne", "de": dir * r, "a": dir * 300.0, "largeur": 10.0}, 0.65, -1.0, t)
		else:
			Art.telegraph(ci, {"type": "ligne", "de": Vector2.ZERO, "a": dir * 260.0, "largeur": r * 2.0}, 0.65, -1.0, t)
		ci.draw_set_transform_matrix(Transform2D.IDENTITY)
	match c["art"]:
		"tireur":
			Tireur.draw(ci, feet, Tireur.HEIGHT, o)
		"scarabee":
			Scarabee.draw(ci, feet, Scarabee.HEIGHT, o)
		"menhir":
			Menhir.draw(ci, feet, Menhir.HEIGHT, o)
		_:
			var r: float = _enemy_r.get(c["kind"], 14.0)
			ci.draw_colored_polygon(Art.ellipse(p + Vector2(0, r * Art.OMBRE_DECALAGE * 0.5), r * 1.05, r * 0.75, 14), Art.c("ombre"))
			FletriArt.draw(ci, c["kind"], p, r, Vector2.from_angle(look), o["t"], {"walk": o["walk"], "moving": o["moving"]})
	Ink.flash = 0.0
