## Galerie du héros et de ses attaques : chaque pose du Porte-Graine et chaque compétence
## (début, coup, fin), dessinées par les vrais HeroArt, SkillFx et projectile.gd, figés à un instant.
##
## page = "heros"        : poses et états du héros, en grand, puis à la taille du jeu.
## page = "competences"  : la graine et les sept compétences, en trois temps, avec leur icône.
## page = "anim"         : toutes les signatures en boucle (temps t), pour tools/heros-anim.sh.
extends Node2D

const ProjectileScript = preload("res://scripts/projectile.gd")

## Boucle de la page animée (secondes).
const PERIODE := 2.4
## Compétences de la galerie, dans l'ordre de la barre (la graine est l'arme de base).
const SKILLS := ["graine", "nova", "fouet", "racines", "volee", "saignee", "cloud", "bloom"]
## Compétences de la branche Vent (troisième page).
const VENT := ["tornade", "ruee", "appel_air"]
## Compétences de la branche Aube (quatrième page).
const AUBE := ["aurore", "prisme", "lance_aube"]
## Compétences de la branche Sève (cinquième page).
const SEVE := ["liane", "fontaine", "cocon"]
## Compétences de la branche Racine (sixième page).
const RACINE := ["ecorce", "ancrage", "pieux"]
const PHASES := ["début", "coup", "fin"]

var view := Vector2(2560, 1440)
var page := "heros"
## Page des compétences : les quatre premières (1), les quatre suivantes (2), celles de Vent (3), d'Aube (4),
## de Sève (5), de Racine (6).
var part := 1
var t := 0.0
var font: Font


func _ready() -> void:
	font = ThemeDB.fallback_font
	if page == "competences":
		_add_projectiles()


## Compétences de la page (quatre par page, pour que chaque zone tienne dans sa case).
func _skills() -> Array:
	if part == 3:
		return VENT
	if part == 4:
		return AUBE
	if part == 5:
		return SEVE
	if part == 6:
		return RACINE
	return SKILLS.slice((part - 1) * 4, part * 4)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, view), Color(Art.c("panneau").darkened(0.3), 1.0))
	match page:
		"heros":
			_page_heros()
		"competences":
			_page_competences()
		"anim":
			_page_anim()
	HeroArt.base = Transform2D.IDENTITY


# --- Héros ---

const POSES := [
	["Repos (respire)", "repos"], ["Marche", "marche"], ["Esquive (traînée de feuilles)", "esquive"],
	["Tir de graine", "tir"], ["Lancer de compétence", "lancer"], ["Coup reçu", "touche"],
	["Vie basse", "vie_basse"], ["Invulnérable", "invuln"], ["Chez soi (terre ravivée)", "chez_soi"],
	["Mort : il se fane", "mort"], ["Renaissance : la pousse", "pousse"], ["Renaissance : debout", "debout"],
]


func _page_heros() -> void:
	_text(Vector2(40, 48), "Porte-Graine · poses et états (taille ×4)", 30, Art.c("texte"), true)
	var cols := 6
	var cw := (view.x - 80) / cols
	var ch := 520.0
	for i in POSES.size():
		var r := Rect2(40 + (i % cols) * cw, 70 + (i / cols) * (ch + 14), cw - 12, ch)
		_ground(r, i, POSES[i][1] == "chez_soi")
		_text_c(Vector2(r.get_center().x, r.position.y + 36), POSES[i][0], 22, Art.c("texte"), cw, true)
		_pose(POSES[i][1], r.get_center() + Vector2(0, 20), 4.0, t)
	# À la taille du jeu : les huit orientations, pour vérifier la lecture à 40 px.
	var y := 70 + 2 * (ch + 14) + 6
	var r := Rect2(40, y, view.x - 80, view.y - y - 30)
	_ground(r, 40)
	_text(Vector2(56, y + 36), "À la taille du jeu (écran 2560 × 1440) : la capuche et la lanterne donnent le sens", 22, Art.c("texte"), true)
	for i in 8:
		var c := Vector2(150 + i * 150, y + 150)
		HeroArt.base = Transform2D(0.0, Vector2(1.6, 1.6), 0.0, c)
		HeroArt.draw(self, Vector2.ZERO, 14.0, i * TAU / 8.0, {"t": t + i * 0.3})
		HeroArt.base = Transform2D.IDENTITY
		draw_set_transform_matrix(Transform2D.IDENTITY)
	var states := [["marche", 0.0], ["tir", 0.0], ["lancer", 0.0], ["touche", 0.0], ["vie_basse", 0.0], ["invuln", 0.0], ["chez_soi", 0.0]]
	for i in states.size():
		var c := Vector2(1400 + i * 150, y + 150)
		_pose(states[i][0], c, 1.6, t)


## Dessine une pose du héros centrée en c, à l'échelle k.
func _pose(kind: String, c: Vector2, k: float, time: float) -> void:
	var st := {"t": time}
	var facing := 0.0
	match kind:
		"marche":
			st["walk"] = 1.0
			st["step"] = 0.9
			st["move"] = Vector2.RIGHT
		"esquive":
			st["dash"] = 0.7
			st["walk"] = 1.0
			st["move"] = Vector2.RIGHT
			_dash_trail(c, k, Vector2.RIGHT)
		"tir":
			st["shoot"] = 0.8
			var sp := ProjectileScript.new()
			_seed_ghost(c + Vector2(34, 0) * k, k)
		"lancer":
			st["cast"] = 0.7
			st["cast_col"] = Art.ec("epine")
			st["squash"] = Anim.squash(0.45, 0.7)
		"touche":
			st["hurt"] = 0.6
			st["squash"] = Anim.squash(0.5, 0.8)
			for j in 2:
				_falling_leaf(c + Vector2(-40 - 22 * j, -12 + 26 * j) * k, 6.0 * k, 0.8 + j, 0.2)
		"vie_basse":
			st["low"] = 1.0
			st["t"] = 0.05   # au battement
		"invuln":
			st["invuln"] = 1.0
		"chez_soi":
			st["home"] = true
		"mort":
			st["wither"] = 0.75
		"pousse":
			st["appear"] = 0.3
		"debout":
			st["appear"] = 0.75
	HeroArt.base = Transform2D(0.0, Vector2(k, k), 0.0, c)
	HeroArt.draw(self, Vector2.ZERO, 14.0, facing, st)
	HeroArt.base = Transform2D.IDENTITY
	draw_set_transform_matrix(Transform2D.IDENTITY)


## Traînée d'esquive : feuilles semées et silhouettes fantômes derrière le héros.
func _dash_trail(c: Vector2, k: float, d: Vector2) -> void:
	for i in 3:
		draw_circle(c - d * (i + 1) * 13.0 * k, 14.0 * k * (0.85 - i * 0.18), Color(Art.ec("seve"), 0.22 - i * 0.06))
	for i in 6:
		var q := c - d * (20 + i * 14) * k + Vector2(0, sin(i * 1.7) * 10.0 * k)
		_falling_leaf(q, 5.0 * k, i * 1.3, i / 7.0)


func _falling_leaf(q: Vector2, l: float, a: float, fade: float) -> void:
	draw_colored_polygon(HeroArt.leaf_pts(q, l, a), Color(Art.c("joueur_accent").darkened(0.3), 1.0 - fade))


## Une graine en vol (même dessin que projectile.gd), à l'échelle k.
func _seed_ghost(c: Vector2, k: float) -> void:
	draw_set_transform(c, 0.0, Vector2(k, k))
	var r := 6.0
	var seve := Art.ec("seve")
	for i in 5:
		var f := 1.0 - i / 5.0
		draw_circle(Vector2(-r * 1.5 * (i + 1), 0), r * 0.85 * f, Color(seve, 0.28 * f))
	draw_circle(Vector2.ZERO, r * 1.9, Color(seve, 0.16))
	draw_circle(Vector2.ZERO, r * 1.3, Color(seve, 0.28))
	draw_colored_polygon(Art.ellipse(Vector2.ZERO, r * 1.25, r * 0.85, 12), Art.ec("seve", "sombre").lightened(0.35))
	draw_circle(Vector2(-r * 0.05, -r * 0.2), r * 0.55, Art.ec("seve", "clair"))
	draw_set_transform_matrix(Transform2D.IDENTITY)


# --- Compétences ---

## Instant de chaque phase (début, coup, fin), en part de la durée de la signature.
const PHASE_K := {
	"graine": [0.4, 0.25, 0.7], "nova": [0.08, 0.32, 0.75], "fouet": [0.09, 0.33, 0.72],
	"racines": [0.06, 0.16, 0.95], "volee": [0.3, 0.5, 0.4], "saignee": [0.12, 0.38, 0.72],
	"cloud": [0.03, 0.4, 0.95], "bloom": [0.12, 0.42, 0.8],
	"tornade": [0.04, 0.4, 0.95], "ruee": [0.1, 0.35, 0.8], "appel_air": [0.3, 0.68, 0.88],
	"aurore": [0.06, 0.35, 0.8], "prisme": [0.02, 0.3, 0.96], "lance_aube": [0.6, 0.12, 0.7],
	"liane": [0.04, 0.4, 0.95], "fontaine": [0.04, 0.4, 0.95], "cocon": [0.04, 0.5, 0.9],
	"ecorce": [0.03, 0.4, 0.9], "ancrage": [0.06, 0.4, 0.93], "pieux": [0.08, 0.3, 0.85],
}
## Échelle de chaque ligne : la zone de la compétence tient dans sa case.
const CELL_SCALE := {
	"graine": 2.0, "nova": 0.82, "fouet": 1.0, "racines": 1.3,
	"volee": 1.6, "saignee": 0.68, "cloud": 1.25, "bloom": 0.95,
	"tornade": 0.9, "ruee": 1.2, "appel_air": 0.55,
	"aurore": 0.62, "prisme": 1.3, "lance_aube": 0.75,
	"liane": 1.0, "fontaine": 0.95, "cocon": 1.6,
	"ecorce": 1.6, "ancrage": 0.75, "pieux": 1.0,
}


func _cell_rect(row: int, col: int) -> Rect2:
	var top := 100.0
	var rh := (view.y - top - 20) / 4.0
	var left := 300.0
	var cw := (view.x - left - 30) / 3.0
	return Rect2(left + col * cw, top + row * rh, cw - 10, rh - 8)


func _page_competences() -> void:
	_text(Vector2(40, 44), "Signatures des attaques · début, coup, fin (couleur et motif de l'élément)", 30, Art.c("texte"), true)
	for j in 3:
		var r := _cell_rect(0, j)
		_text_c(Vector2(r.get_center().x, 88), PHASES[j], 24, Art.c("texte_doux"), r.size.x, true)
	var ids := _skills()
	for i in ids.size():
		var id: String = ids[i]
		var r0 := _cell_rect(i, 0)
		Art.icon_badge(self, id, Rect2(30, r0.position.y + r0.size.y / 2.0 - 70, 96, 96))
		_text(Vector2(30, r0.position.y + r0.size.y / 2.0 + 54), Art.NOM_ICONE[id], 22, Art.c("texte"), true)
		var elem: String = Art.ELEMENT_DE_COMPETENCE[id]
		_text(Vector2(30, r0.position.y + r0.size.y / 2.0 + 80), Art.ELEMENTS[elem]["nom"], 18, Art.ec(elem).lightened(0.2))
		for j in 3:
			var r := _cell_rect(i, j)
			_ground(r, i * 3 + j)
			draw_set_transform_matrix(Transform2D.IDENTITY)
			_skill_cell(id, r, PHASE_K[id][j], j)
	if part == 3:
		_vent_attaques()
	if part == 4:
		_aube_attaques()
	if part == 5:
		_seve_attaques()
	if part == 6:
		_racine_attaques()


## Une case : le héros (à gauche) et la signature de la compétence à l'instant k de sa durée.
func _skill_cell(id: String, r: Rect2, k: float, phase: int) -> void:
	var s: float = CELL_SCALE[id]
	var hero := r.position + Vector2(r.size.x * 0.3, r.size.y * 0.55)
	var target := r.position + Vector2(r.size.x * 0.72, r.size.y * 0.55)
	var xf := Transform2D(0.0, Vector2(s, s), 0.0, hero)
	var inv := xf.affine_inverse()
	var loc_target := inv * target
	var e := _effect(id, loc_target, k, r.size.x / s)
	# Cibles : des silhouettes de Flétris là où frappe la compétence.
	var marks := _targets(id, loc_target)
	draw_set_transform_matrix(xf)
	var dur: float = e["dur"]
	e["t"] = k * dur
	SkillFx.draw_effect(self, e, true)
	for m: Vector2 in marks:
		_fletri(m)
	draw_set_transform_matrix(Transform2D.IDENTITY)
	HeroArt.base = xf
	var st := {"t": 0.3 + phase * 0.4, "cast": [0.9, 0.4, 0.0][phase], "cast_col": Art.ec(Art.ELEMENT_DE_COMPETENCE[id])}
	if id == "graine":
		st = {"t": 0.3, "shoot": [0.9, 0.2, 0.0][phase]}
	HeroArt.draw(self, Vector2.ZERO, 14.0, 0.0, st)
	HeroArt.base = Transform2D.IDENTITY
	draw_set_transform_matrix(xf)
	SkillFx.draw_effect(self, e, false)
	draw_set_transform_matrix(Transform2D.IDENTITY)


## La signature d'une compétence, dans le repère du héros (héros en 0, visée vers la droite).
func _effect(id: String, target: Vector2, k: float, width: float) -> Dictionary:
	var e := {"id": id, "t": 0.0, "pos": Vector2.ZERO, "dir": Vector2.RIGHT}
	e["dur"] = SkillFx.DUREE.get(id, VentFx.DUREE.get(id, AubeFx.DUREE.get(id, SeveFx.DUREE.get(id, RacineFx.DUREE.get(id, 0.4)))))
	match id:
		"graine":
			e["id"] = "graine_depart" if k > 0.35 else "graine_impact"
			e["dur"] = SkillFx.DUREE[e["id"]]
			e["pos"] = Vector2(21, 0) if k > 0.35 else target
			e["r"] = 6.0
		"nova":
			e["r"] = 170.0
		"fouet":
			e["r"] = 150.0
			e["arc"] = 2.1
		"racines":
			e["pos"] = target
			e["r"] = 110.0
			e["dur"] = 0.3 + 2.5 + 0.35
			e["seed"] = 7
		"volee":
			e["spread"] = 0.5
			e["count"] = 5
			if k == 0.4:
				e["id"] = "epine_impact"
				e["dur"] = SkillFx.DUREE["epine_impact"]
				e["pos"] = target
		"saignee":
			e["r"] = 230.0
			e["targets"] = _targets(id, target)
		"cloud":
			e["pos"] = target
			e["r"] = 120.0
			e["dur"] = 5.0
		"bloom":
			e["r"] = 150.0
		"tornade":
			e["pos"] = target
			e["r"] = 90.0
			e["dur"] = 4.0
			e["seed"] = 3
		"ruee":
			e["from"] = Vector2(-150, 0)
			e["w"] = 48.0
		"appel_air":
			e["pos"] = target
			e["r"] = 230.0
			e["pull"] = 0.6
		"aurore":
			e["r"] = 210.0
		"prisme":
			e["pos"] = target
		"lance_aube":
			# Début : la lumière se concentre ; puis le grand rayon part.
			if k == 0.6:
				e["id"] = "lance_charge"
				e["dur"] = AubeFx.DUREE["lance_charge"]
			else:
				e["pos"] = Vector2(20, 0)
				e["len"] = width * 0.55
				e["w"] = 44.0
		"liane":
			e["to"] = target + Vector2(-20, 10)
			e["seed"] = 2
		"fontaine":
			e["r"] = 140.0
		"cocon":
			e["r"] = 30.0
			e["part"] = [1.0, 0.6, 0.25][int(k * 2.2)]
		"ecorce":
			e["r"] = 28.0
			e["part"] = [1.0, 0.6, 0.25][int(k * 2.2)]
			e["seed"] = 5
		"ancrage":
			e["r"] = 190.0
			e["seed"] = 4
		"pieux":
			# Trois pieux le long de la ligne, à des âges différents (le premier redescend).
			e["id"] = "pieu"
			e["pos"] = target
			e["r"] = 46.0
			e["seed"] = 9
	return e


func _targets(id: String, target: Vector2) -> Array:
	match id:
		"racines", "cloud":
			return [target + Vector2(-30, -20), target + Vector2(35, 10), target + Vector2(-5, 40)]
		"saignee":
			return [Vector2(170, -60), Vector2(190, 50), Vector2(-150, 70)]
		"fouet":
			return [Vector2(110, -40), Vector2(120, 45)]
		"graine", "volee":
			return [target]
		"nova", "bloom":
			return [Vector2(150, -40), Vector2(-140, 60)]
		"tornade":
			return [target + Vector2(-25, 12), target + Vector2(40, -20)]
		"ruee":
			return [Vector2(-70, 52), Vector2(-120, -50)]
		"appel_air":
			return [target + Vector2(-30, 15), target + Vector2(28, -12), target + Vector2(5, 35)]
		"aurore":
			return [Vector2(150, -50), Vector2(-130, 70)]
		"prisme":
			return [target + Vector2(80, -10)]
		"lance_aube":
			return [Vector2(170, 0), Vector2(330, 8)]
		"liane":
			return [target + Vector2(-20, 10)]
		"fontaine":
			return [Vector2(90, -30)]
		"cocon":
			return [Vector2(60, -20)]
		"ecorce":
			return [Vector2(60, -20)]
		"ancrage":
			return [Vector2(130, -40), Vector2(-120, 60)]
		"pieux":
			return [target + Vector2(0, -6)]
	return []


## Silhouette sommaire d'un Flétri (cible des cases ; les vrais sont dessinés par la tâche D).
func _fletri(p: Vector2) -> void:
	var pts := PackedVector2Array()
	var radii := [1.0, 0.72, 1.05, 0.8, 0.95, 0.68, 1.0, 0.85]
	for i in radii.size():
		pts.append(p + Vector2.from_angle(0.2 + i * TAU / radii.size()) * 18.0 * radii[i])
	Art.shadow(self, p, 18.0)
	Art.volume(self, pts, Art.c("ennemi"), 0.6)
	Art.outline(self, pts, Art.c("ennemi_contour"), Art.TRAIT)


## Projectiles réels (projectile.gd) dans les cases de la graine et de la volée.
func _add_projectiles() -> void:
	if part >= 3:
		return
	if part == 1:
		_projectile(_cell_rect(0, 1), Vector2(130, 0), false, 0.0)
		return
	for j in 2:
		var r := _cell_rect(0, j)
		for i in 5:
			var a := (i / 4.0 - 0.5) * 0.5
			_projectile(r, Vector2.from_angle(a) * (60.0 + 90.0 * j), true, a)


func _projectile(r: Rect2, local: Vector2, thorn: bool, a: float) -> void:
	var s: float = CELL_SCALE["graine" if not thorn else "volee"]
	var hero := r.position + Vector2(r.size.x * 0.3, r.size.y * 0.55)
	var pr = ProjectileScript.new()
	pr.thorn = thorn
	pr.vel = Vector2.from_angle(a) * 600.0
	pr.age = 1.0
	pr.position = hero + local * s
	pr.scale = Vector2(s, s) * 1.2
	add_child(pr)
	pr.set_physics_process(false)


# --- Page animée ---

## Toutes les signatures en boucle : chaque case rejoue sa compétence du début à la fin.
func _page_anim() -> void:
	_text(Vector2(40, 44), "Porte-Graine · attaques en boucle", 24, Art.c("texte"), true)
	var cols := 4
	var cw := (view.x - 80) / cols
	var ch := (view.y - 90) / 2.0
	for i in SKILLS.size():
		var id: String = SKILLS[i]
		var r := Rect2(40 + (i % cols) * cw, 70 + (i / cols) * ch, cw - 12, ch - 12)
		_ground(r, i)
		Art.icon_badge(self, id, Rect2(r.position + Vector2(14, 14), Vector2(52, 52)))
		_text(r.position + Vector2(78, 46), Art.NOM_ICONE[id], 18, Art.c("texte"), true)
		var u := fposmod(t / PERIODE + i * 0.0, 1.0)
		_anim_cell(id, r, u)


func _anim_cell(id: String, r: Rect2, u: float) -> void:
	var s: float = CELL_SCALE[id] * 1.35
	var centered: bool = id in ["nova", "fouet", "saignee", "bloom"]
	var hero := r.position + Vector2(r.size.x * (0.42 if centered else 0.2), r.size.y * 0.56)
	var target := r.position + Vector2(r.size.x * 0.66, r.size.y * 0.56)
	var xf := Transform2D(0.0, Vector2(s, s), 0.0, hero)
	var loc_target := xf.affine_inverse() * target
	var e := _effect(id, loc_target, 0.0, r.size.x / s)
	var st := {"t": t}
	var effects: Array = []
	match id:
		"graine":
			# Trois graines par boucle : départ, vol, impact.
			var w := fposmod(u * 3.0, 1.0)
			st["shoot"] = maxf(0.0, 1.0 - w * 6.0)
			if w < 0.2:
				effects.append({"id": "graine_depart", "t": w * 0.6, "dur": SkillFx.DUREE["graine_depart"], "pos": Vector2(21, 0), "dir": Vector2.RIGHT})
			var fly := clampf(w / 0.55, 0.0, 1.0)
			if w < 0.55:
				_seed_ghost(xf * Vector2(21.0 + (loc_target.x - 21.0) * fly, 0), s)
			else:
				effects.append({"id": "graine_impact", "t": (w - 0.55) / 0.45 * 0.3, "dur": 0.3, "pos": loc_target, "dir": Vector2.RIGHT, "r": 6.0})
		"volee":
			var dur := 0.9
			var tt := u * PERIODE
			if tt < dur:
				e["t"] = minf(tt, e["dur"] - 0.001)
				if tt < e["dur"]:
					effects.append(e)
				st["cast"] = maxf(0.0, 1.0 - tt / 0.32)
				st["cast_col"] = Art.ec("epine")
				for i in 5:
					var a := (i / 4.0 - 0.5) * 0.5
					var q := Vector2.from_angle(a) * (20.0 + 300.0 * tt / dur)
					if q.x < loc_target.x - 10:
						_thorn_ghost(xf * q, a, s)
			if tt >= dur * 0.75 and tt < dur * 0.75 + 0.3:
				effects.append({"id": "epine_impact", "t": tt - dur * 0.75, "dur": 0.3, "pos": loc_target, "dir": Vector2.RIGHT})
		_:
			# Les compétences courtes reviennent deux fois par boucle.
			var tt := fposmod(u * PERIODE, PERIODE / 2.0)
			var dur: float = e["dur"]
			if id == "cloud" or id == "racines":
				# Effets longs : on montre l'apparition, la tenue, et la fin, compressées dans la boucle.
				tt = u * dur
			if tt < dur:
				e["t"] = tt
				effects.append(e)
				st["cast"] = maxf(0.0, 1.0 - (tt if id != "cloud" and id != "racines" else u * PERIODE) / 0.32)
				st["cast_col"] = Art.ec(Art.ELEMENT_DE_COMPETENCE[id])
	draw_set_transform_matrix(xf)
	for f in effects:
		SkillFx.draw_effect(self, f, true)
	for m: Vector2 in _targets(id, loc_target):
		_fletri(m)
	draw_set_transform_matrix(Transform2D.IDENTITY)
	HeroArt.base = xf
	HeroArt.draw(self, Vector2.ZERO, 14.0, 0.0, st)
	HeroArt.base = Transform2D.IDENTITY
	draw_set_transform_matrix(xf)
	for f in effects:
		SkillFx.draw_effect(self, f, false)
	draw_set_transform_matrix(Transform2D.IDENTITY)


func _thorn_ghost(c: Vector2, a: float, k: float) -> void:
	draw_set_transform(c, a, Vector2(k, k) * 1.2)
	var r := 6.0
	var clair := Art.ec("epine", "clair")
	draw_line(Vector2(-r * 4.5, 0), Vector2(-r * 1.3, 0), Color(clair, 0.18), r * 0.9)
	draw_colored_polygon(PackedVector2Array([Vector2(r * 2.4, 0), Vector2(-r * 1.3, r * 0.6), Vector2(-r * 1.3, 0)]), clair)
	draw_colored_polygon(PackedVector2Array([Vector2(r * 2.4, 0), Vector2(-r * 1.3, 0), Vector2(-r * 1.3, -r * 0.6)]), Art.ec("epine").darkened(0.2))
	draw_circle(Vector2(-r * 1.3, 0), r * 0.4, Art.ec("saignement", "clair"))
	draw_set_transform_matrix(Transform2D.IDENTITY)


# --- Outils ---

## Un carré de sol mort (ou ravivé), calme : la charte veut un fond sourd.
func _ground(r: Rect2, seed_: int, vivant := false) -> void:
	draw_rect(r, Art.c("sol_vivant") if vivant else Art.c("sol_mort"))
	var rng := RandomNumberGenerator.new()
	rng.seed = 2000 + seed_
	for i in 10:
		var q := r.position + Vector2(rng.randf_range(8, r.size.x - 8), rng.randf_range(40, r.size.y - 8))
		var s := rng.randf_range(1.5, 3.5)
		draw_colored_polygon(Art.ellipse(q, s * 1.3, s, 8), Color(Art.c("brume"), 0.3))


func _text(pos: Vector2, s: String, size: int, col: Color, _bold := false) -> void:
	draw_string(font, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


func _text_c(center: Vector2, s: String, size: int, col: Color, width: float, _bold := false) -> void:
	draw_string(font, center - Vector2(width / 2.0, 0), s, HORIZONTAL_ALIGNMENT_CENTER, width, size, col)


# --- Attaque de base de Vent (page 3) ---

## Dernière ligne de la page de Vent : les deux formes de l'attaque (lames de vent qui reviennent,
## bourrasque en cône) et le modificateur « repousse », dessinés par projectile.gd et attack_fx.gd.
func _vent_attaques() -> void:
	var r0 := _cell_rect(3, 0)
	Art.icon_badge(self, "attaque_lame", Rect2(30, r0.position.y + r0.size.y / 2.0 - 70, 96, 96))
	_text(Vector2(30, r0.position.y + r0.size.y / 2.0 + 54), "Attaque de Vent", 22, Art.c("texte"), true)
	var labels := ["Lames de vent : aller-retour", "Bourrasque : cône qui repousse", "Repousse et élan"]
	for j in 3:
		var r := _cell_rect(3, j)
		_ground(r, 40 + j)
		var hero := r.position + Vector2(r.size.x * 0.3, r.size.y * 0.55)
		var xf := Transform2D(0.0, Vector2(1.2, 1.2), 0.0, hero)
		draw_set_transform_matrix(xf)
		match j:
			0:
				_fletri(Vector2(170, -40))
				_fletri(Vector2(200, 45))
				for i in 7:
					draw_line(Vector2(40 + i * 24, 14), Vector2(52 + i * 24, 14), Color(Art.ec("vent", "clair"), 0.6), 2.0, true)
				_lame(xf, Vector2(130, -42))
				_lame(xf, Vector2(235, 44))
			1:
				_fletri(Vector2(130, -30))
				_fletri(Vector2(140, 34))
				AttackFx.draw_effect(self, {"id": "bourrasque", "pos": Vector2.ZERO, "dir": Vector2.RIGHT, "r": 185.0, "arc": 1.3, "t": 0.12, "dur": 0.26})
			2:
				_fletri(Vector2(190, 0))
				for i in 3:
					draw_arc(Vector2(160 - i * 10, 0), 16.0 + i * 6.0, -0.8, 0.8, 8, Color(Art.ec("vent", "clair"), 0.8 - 0.2 * i), 2.0, true)
				for i in 3:
					draw_line(Vector2(-14 - i * 8, -12 + i * 12), Vector2(-50 - i * 8, -12 + i * 12), Color(Art.ec("vent", "clair"), 0.7), 2.0, true)
				_lame(xf, Vector2(110, 0))
		draw_set_transform_matrix(Transform2D.IDENTITY)
		HeroArt.base = xf
		HeroArt.draw(self, Vector2.ZERO, 14.0, 0.0, {"t": 0.3, "cast": 0.5 if j == 1 else 0.0, "cast_col": Art.ec("vent"), "shoot": 0.5 if j != 1 else 0.0})
		HeroArt.base = Transform2D.IDENTITY
		draw_set_transform_matrix(Transform2D.IDENTITY)
		_text(r.position + Vector2(12, 30), labels[j], 22, Art.c("texte"))


## Une lame de vent à « at » (repère xf de la case), un peu tournée.
func _lame(xf: Transform2D, at: Vector2) -> void:
	draw_set_transform_matrix(xf * Transform2D(0.4, at))
	ProjectileScript.draw_shot(self, "lame", Vector2.RIGHT, 7.8)
	draw_set_transform_matrix(xf)


# --- Attaque de base d'Aube (page 4) ---

## Dernière ligne de la page d'Aube : le rayon d'aube, sa réfraction, et un Flétri ébloui (attack_fx.gd,
## aube_fx.gd, Art.status).
func _aube_attaques() -> void:
	var r0 := _cell_rect(3, 0)
	Art.icon_badge(self, "attaque_rayon", Rect2(30, r0.position.y + r0.size.y / 2.0 - 70, 96, 96))
	_text(Vector2(30, r0.position.y + r0.size.y / 2.0 + 54), "Attaque d'Aube", 22, Art.c("texte"), true)
	var labels := ["Rayon d'aube : traverse tout", "Réfraction : il se brise", "Ébloui : plus de critiques"]
	for j in 3:
		var r := _cell_rect(3, j)
		_ground(r, 50 + j)
		var hero := r.position + Vector2(r.size.x * 0.3, r.size.y * 0.55)
		var xf := Transform2D(0.0, Vector2(1.2, 1.2), 0.0, hero)
		draw_set_transform_matrix(xf)
		match j:
			0:
				_fletri(Vector2(110, 0))
				_fletri(Vector2(230, 6))
				AttackFx.draw_effect(self, {"id": "rayon", "pos": Vector2(18, 0), "dir": Vector2.RIGHT, "len": 300.0, "w": 14.0, "t": 0.03, "dur": 0.18})
			1:
				_fletri(Vector2(120, 0))
				_fletri(Vector2(200, -60))
				_fletri(Vector2(200, 60))
				AttackFx.draw_effect(self, {"id": "rayon", "pos": Vector2(18, 0), "dir": Vector2.RIGHT, "len": 120.0, "w": 14.0, "t": 0.03, "dur": 0.18})
				for sgn: int in [-1, 1]:
					AttackFx.draw_effect(self, {"id": "rayon", "pos": Vector2(120, 0), "dir": Vector2.from_angle(sgn * 0.55), "len": 130.0, "w": 10.0, "t": 0.05, "dur": 0.18})
			2:
				_fletri(Vector2(150, 0))
				Art.status(self, "lumiere", Vector2(150, 0), 16.0, 0.4)
		draw_set_transform_matrix(Transform2D.IDENTITY)
		HeroArt.base = xf
		HeroArt.draw(self, Vector2.ZERO, 14.0, 0.0, {"t": 0.3, "cast": 0.0, "cast_col": Art.ec("lumiere"), "shoot": 0.5})
		HeroArt.base = Transform2D.IDENTITY
		draw_set_transform_matrix(Transform2D.IDENTITY)
		_text(r.position + Vector2(12, 30), labels[j], 22, Art.c("texte"))


# --- Attaque de base de Sève (page 5) ---

## Dernière ligne de la page de Sève : la forme « perle » (lourdes gouttes qui éclaboussent),
## l'éclaboussure à l'impact et la rosée qui revient au héros, dessinées par projectile.gd et SeveFx.
func _seve_attaques() -> void:
	var r0 := _cell_rect(3, 0)
	Art.icon_badge(self, "attaque_perle", Rect2(30, r0.position.y + r0.size.y / 2.0 - 70, 96, 96))
	_text(Vector2(30, r0.position.y + r0.size.y / 2.0 + 54), "Attaque de Sève", 22, Art.c("texte"), true)
	var labels := ["Perles de sève : en vol", "Éclaboussure à l'impact", "Rosée : la vie revient"]
	for j in 3:
		var r := _cell_rect(3, j)
		_ground(r, 50 + j)
		var hero := r.position + Vector2(r.size.x * 0.3, r.size.y * 0.55)
		var xf := Transform2D(0.0, Vector2(1.2, 1.2), 0.0, hero)
		draw_set_transform_matrix(xf)
		match j:
			0:
				_fletri(Vector2(200, 0))
				for at: Vector2 in [Vector2(80, -12), Vector2(135, 10)]:
					draw_set_transform_matrix(xf * Transform2D(0.0, at))
					ProjectileScript.draw_shot(self, "perle", Vector2.RIGHT, 8.1)
					draw_set_transform_matrix(xf)
			1:
				_fletri(Vector2(150, 0))
				_fletri(Vector2(185, 38))
				AttackFx.draw_effect(self, {"id": "perle_eclat", "pos": Vector2(150, 0), "r": 56.0, "t": 0.1, "dur": 0.3})
			2:
				AttackFx.draw_effect(self, {"id": "rosee", "from": Vector2(170, 0), "pos": Vector2.ZERO, "t": 0.2, "dur": 0.45})
		draw_set_transform_matrix(Transform2D.IDENTITY)
		HeroArt.base = xf
		HeroArt.draw(self, Vector2.ZERO, 14.0, 0.0, {"t": 0.3, "shoot": 0.5 if j == 0 else 0.0})
		HeroArt.base = Transform2D.IDENTITY
		draw_set_transform_matrix(Transform2D.IDENTITY)
		_text(r.position + Vector2(12, 30), labels[j], 22, Art.c("texte"))


## Attaque de Racine (dernière ligne de la sixième page) : massue en plein coup, secousse, aubier.
func _racine_attaques() -> void:
	var r0 := _cell_rect(3, 0)
	Art.icon_badge(self, "attaque_massue", Rect2(30, r0.position.y + r0.size.y / 2.0 - 70, 96, 96))
	_text(Vector2(30, r0.position.y + r0.size.y / 2.0 + 54), "Attaque de Racine", 22, Art.c("texte"), true)
	var labels := ["Massue de bois : le coup", "Secousse : le sol se soulève", "Aubier : l'écorce se referme"]
	for j in 3:
		var r := _cell_rect(3, j)
		_ground(r, 60 + j)
		var hero := r.position + Vector2(r.size.x * 0.3, r.size.y * 0.55)
		var xf := Transform2D(0.0, Vector2(1.2, 1.2), 0.0, hero)
		draw_set_transform_matrix(xf)
		match j:
			0:
				_fletri(Vector2(120, -20))
				AttackFx.draw_effect(self, {"id": "massue", "pos": Vector2.ZERO, "dir": Vector2.RIGHT, "r": 150.0, "arc": 1.7, "t": 0.15, "dur": 0.32})
			1:
				_fletri(Vector2(110, 0))
				_fletri(Vector2(150, 40))
				AttackFx.draw_effect(self, {"id": "massue", "pos": Vector2.ZERO, "dir": Vector2.RIGHT, "r": 150.0, "arc": 1.7, "t": 0.22, "dur": 0.32})
				AttackFx.draw_effect(self, {"id": "secousse", "pos": Vector2(112, 0), "r": 80.0, "t": 0.12, "dur": 0.4})
			2:
				_fletri(Vector2(110, 10))
				AttackFx.draw_effect(self, {"id": "aubier", "pos": Vector2.ZERO, "t": 0.1, "dur": 0.35})
		draw_set_transform_matrix(Transform2D.IDENTITY)
		HeroArt.base = xf
		HeroArt.draw(self, Vector2.ZERO, 14.0, 0.0, {"t": 0.3, "cast": 0.5 if j == 0 else 0.0, "cast_col": Art.ec("racine")})
		HeroArt.base = Transform2D.IDENTITY
		if j == 2:
			draw_set_transform_matrix(xf)
			AttackFx.draw_effect(self, {"id": "aubier", "pos": Vector2.ZERO, "t": 0.1, "dur": 0.35})
		draw_set_transform_matrix(Transform2D.IDENTITY)
		_text(r.position + Vector2(12, 30), labels[j], 22, Art.c("texte"))
