## Galerie de l'attaque de base (attack.gd) : chaque forme et chaque modificateur, dessinés par les
## vrais HeroArt, projectile.gd (draw_shot) et attack_fx.gd (draw_effect, draw_zone), figés à un
## instant. Planche de 1600 × 900 (scénario « attaque » du banc visuel).
extends Node2D

const ProjectileScript = preload("res://scripts/projectile.gd")

const FORMES := [
	["graine", "Graines (départ)"], ["echarde", "Échardes : rafale perforante"],
	["fouet", "Fouet : arc au corps à corps"], ["ronce_vive", "Ronces vives : piège planté"],
	["lame", "Lames de vent : aller-retour"], ["bourrasque", "Bourrasque : cône qui repousse"],
]
const MODS := [
	["fourche", "Fourche"], ["ricochet", "Ricochet"], ["eclat", "Éclat à la mort"], ["saignement", "Saignement"],
	["enracine", "Enracinement"], ["trainee", "Traînée d'épines"], ["renforcee", "Une sur N renforcée"], ["volee", "Une sur N en volée"],
	["taille", "Taille"], ["portee", "Portée"], ["repetition", "Répétition (fouet)"], ["poison", "Poison"],
	["elan", "Élan (en mouvement)"], ["repousse", "Repousse"],
]
## Modificateurs par ligne.
const PAR_LIGNE := 7

var view := Vector2(1600, 900)
var font: Font


func _ready() -> void:
	font = ThemeDB.fallback_font


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, view), Color(Art.c("panneau").darkened(0.3), 1.0))
	_text(Vector2(24, 34), "Attaque de base : formes", 22, Art.c("texte"))
	var cw := (view.x - 48) / float(FORMES.size())
	for i in FORMES.size():
		var r := Rect2(24 + i * cw, 46, cw - 10, 250)
		_cell(r, FORMES[i][1], i)
		_form(FORMES[i][0], r)
	_text(Vector2(24, 328), "Modificateurs (cumulables)", 22, Art.c("texte"))
	var mw := (view.x - 48) / float(PAR_LIGNE)
	for i in MODS.size():
		var r := Rect2(24 + (i % PAR_LIGNE) * mw, 340 + (i / PAR_LIGNE) * 228, mw - 10, 218)
		_cell(r, MODS[i][1], 10 + i)
		_mod(MODS[i][0], r)
	# Icônes des formes et du nœud qui modifie l'attaque (arbre, infobulles).
	var ids: Array = Art.ICONES["attaques"]
	for i in ids.size():
		var q := Vector2(view.x - 24 - (ids.size() - i) * 46 + 18, 26)
		Art.icon_badge(self, ids[i], Rect2(q - Vector2(18, 18), Vector2(36, 36)))


# --- Formes ---

func _form(id: String, r: Rect2) -> void:
	var hero := r.position + Vector2(70, r.size.y * 0.58)
	var aim := Vector2.RIGHT
	match id:
		"graine":
			for m in [Vector2(250, -30), Vector2(270, 40)]:
				_fletri(hero + m)
			for i in 3:
				var d := aim.rotated((i - 1) * 0.14)
				_shot("graine", hero + d * (110.0 + 40.0 * i), d, 6.0)
			_hero(hero, 0.0, {"shoot": 0.6})
		"echarde":
			_fletri(hero + Vector2(240, 0))
			_fletri(hero + Vector2(300, 10))
			for i in 3:
				var d := aim.rotated([0.0, 0.07, -0.07][i])
				_shot("echarde", hero + d * (210.0 - i * 60.0), d, 4.8)
			AttackFx.draw_effect(self, {"id": "eclat", "pos": hero + Vector2(240, 0), "t": 0.05, "dur": 0.28})
			_hero(hero, 0.0, {"shoot": 0.6})
		"fouet":
			var c := hero + Vector2(40, 0)
			_fletri(c + Vector2(95, -40))
			_fletri(c + Vector2(110, 35))
			_fletri(c + Vector2(250, 0))
			AttackFx.draw_effect(self, {"id": "fouet", "pos": c, "dir": aim, "r": 135.0, "arc": 1.9, "t": 0.11, "dur": 0.22})
			_hero(c, 0.0, {"cast": 0.6, "cast_col": Art.ec("epine")})
		"ronce_vive":
			var trap := hero + Vector2(200, -20)
			AttackFx.draw_zone(self, {"kind": "piege", "pos": trap, "r": 40.0, "t": 1.0, "dur": 2.6, "seed": 17, "bleed": 0.0})
			_fletri(trap + Vector2(8, 4))
			Art.status(self, "racine", trap + Vector2(8, 4), 18.0, 0.3)
			var d := Vector2(1, 0.35).normalized()
			_shot("ronce_vive", hero + d * 120.0, d, 6.0)
			_hero(hero, 0.0, {"shoot": 0.4})
		"lame":
			# Une lame part, l'autre revient (flèche de retour en pointillés).
			_fletri(hero + Vector2(150, -30))
			_fletri(hero + Vector2(170, 40))
			_shot("lame", hero + Vector2(120, -32), aim, 7.8)
			_shot("lame", hero + Vector2(190, 40), aim, 7.8)
			for i in 6:
				var x := 40.0 + i * 24.0
				draw_line(hero + Vector2(x, 12), hero + Vector2(x + 12, 12), Color(Art.ec("vent", "clair"), 0.6), 2.0, true)
			_hero(hero, 0.0, {"shoot": 0.6})
		"bourrasque":
			var c := hero + Vector2(20, 0)
			_fletri(c + Vector2(120, -25))
			_fletri(c + Vector2(130, 30))
			AttackFx.draw_effect(self, {"id": "bourrasque", "pos": c, "dir": aim, "r": 160.0, "arc": 1.3, "t": 0.12, "dur": 0.26})
			_hero(c, 0.0, {"cast": 0.6, "cast_col": Art.ec("vent")})


# --- Modificateurs ---

func _mod(id: String, r: Rect2) -> void:
	var c := r.position + Vector2(r.size.x / 2.0, r.size.y * 0.6)
	var hero := r.position + Vector2(34, r.size.y * 0.6)
	var aim := Vector2.RIGHT
	match id:
		"fourche":
			var at := c + Vector2(-10, 0)
			_fletri(at)
			AttackFx.draw_effect(self, {"id": "fourche", "pos": at, "dir": aim, "n": 2, "a": 0.42, "t": 0.06, "dur": 0.22, "element": "seve"})
			for s in [-1.0, 1.0]:
				var d := aim.rotated(s * 0.42)
				_shot("graine", at + d * 70.0, d, 4.0)
			_hero(hero, 0.0, {})
		"ricochet":
			var a := c + Vector2(-20, 30)
			var b := c + Vector2(60, -50)
			_fletri(a)
			_fletri(b)
			AttackFx.draw_effect(self, {"id": "ricochet", "pos": a, "to": b, "t": 0.06, "dur": 0.2, "element": "seve"})
			_shot("graine", a.lerp(b, 0.55), (b - a).normalized(), 6.0)
			_hero(hero, 0.0, {})
		"eclat":
			AttackFx.draw_effect(self, {"id": "eclat", "pos": c, "t": 0.08, "dur": 0.28})
			for i in 6:
				var d := Vector2.from_angle(0.3 + i * TAU / 6.0)
				_shot("eclat", c + d * 46.0, d, 4.2)
		"saignement", "poison", "enracine":
			var at := c + Vector2(20, 0)
			_fletri(at)
			var el: String = {"saignement": "saignement", "poison": "poison", "enracine": "racine"}[id]
			Art.status(self, el, at, 18.0, 0.35)
			if id == "enracine":
				AttackFx.draw_effect(self, {"id": "enracine", "pos": at, "r": 18.0, "t": 0.16, "dur": 0.4})
			_shot("graine", at + Vector2(-34, 0), aim, 6.0)
			_hero(hero, 0.0, {"shoot": 0.5})
		"trainee":
			for i in 4:
				var q := hero + Vector2(40 + i * 34, 4)
				AttackFx.draw_zone(self, {"kind": "trainee", "pos": q, "r": 14.0, "t": 0.3 + i * 0.25, "dur": 1.6, "seed": i * 5})
			_shot("graine", hero + Vector2(190, 0), aim, 6.0)
			_hero(hero, 0.0, {})
		"renforcee":
			AttackFx.draw_effect(self, {"id": "renforcee", "pos": hero, "t": 0.2, "dur": 0.32})
			for i in 3:
				var d := aim.rotated((i - 1) * 0.14)
				_shot("graine", hero + d * 120.0, d, 9.0, true)
			_hero(hero, 0.0, {"shoot": 0.8})
		"volee":
			AttackFx.draw_effect(self, {"id": "volee", "pos": c, "r": 50.0, "t": 0.12, "dur": 0.36, "element": "seve"})
			for i in 10:
				var d := Vector2.from_angle(i * TAU / 10.0)
				_shot("graine", c + d * 66.0, d, 4.5)
			_hero(c, 0.0, {"shoot": 0.6})
		"taille":
			_shot("graine", hero + Vector2(70, -30), aim, 6.0)
			_shot("graine", hero + Vector2(120, 30), aim, 10.0)
			_hero(hero, 0.0, {})
		"portee":
			draw_arc(hero, 150.0, -0.45, 0.45, 16, Color(Art.c("texte_doux"), 0.5), 1.5, true)
			draw_arc(hero, 210.0, -0.3, 0.3, 16, Color(Art.c("or"), 0.7), 2.0, true)
			_shot("graine", hero + Vector2(200, 0), aim, 6.0)
			_hero(hero, 0.0, {})
		"repetition":
			var at := hero + Vector2(10, 0)
			_fletri(at + Vector2(90, -20))
			AttackFx.draw_effect(self, {"id": "fouet", "pos": at, "dir": aim, "r": 115.0, "arc": 1.9, "t": 0.17, "dur": 0.22})
			AttackFx.draw_effect(self, {"id": "fouet", "pos": at, "dir": aim, "r": 115.0, "arc": 1.9, "t": 0.08, "dur": 0.22, "flip": true})
			_hero(at, 0.0, {"cast": 0.5, "cast_col": Art.ec("epine")})
		"elan":
			# Le héros file (traînée de feuilles) et sa lame part plus fort.
			for i in 3:
				draw_line(hero + Vector2(-8 - i * 10, -10 + i * 10), hero + Vector2(-30 - i * 10, -10 + i * 10), Color(Art.ec("vent", "clair"), 0.7), 2.0, true)
			_shot("lame", hero + Vector2(110, 0), aim, 8.5, true)
			_hero(hero, 0.0, {"walk": 1.0})
		"repousse":
			var at := c + Vector2(30, 0)
			_fletri(at)
			for i in 3:
				draw_arc(at - Vector2(26 + i * 9, 0), 14.0 + i * 5.0, -0.8, 0.8, 8, Color(Art.ec("vent", "clair"), 0.8 - 0.2 * i), 2.0, true)
			_shot("graine", at + Vector2(-40, 0), aim, 6.0)
			_hero(hero, 0.0, {"shoot": 0.5})


# --- Outils ---

func _cell(r: Rect2, label: String, seed_: int) -> void:
	draw_rect(r, Art.c("sol_mort"))
	var rng := RandomNumberGenerator.new()
	rng.seed = 3000 + seed_
	for i in 8:
		var q := r.position + Vector2(rng.randf_range(8, r.size.x - 8), rng.randf_range(34, r.size.y - 8))
		var s := rng.randf_range(1.5, 3.5)
		draw_colored_polygon(Art.ellipse(q, s * 1.3, s, 8), Color(Art.c("brume"), 0.3))
	draw_string(font, r.position + Vector2(10, 24), label, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 20, 16, Art.c("texte"))


func _hero(c: Vector2, facing: float, st: Dictionary) -> void:
	st["t"] = 0.4
	HeroArt.base = Transform2D(0.0, Vector2(1.6, 1.6), 0.0, c)
	HeroArt.draw(self, Vector2.ZERO, 14.0, facing, st)
	HeroArt.base = Transform2D.IDENTITY
	draw_set_transform_matrix(Transform2D.IDENTITY)


func _shot(style: String, at: Vector2, dir: Vector2, r: float, empowered := false) -> void:
	draw_set_transform(at, 0.0, Vector2.ONE)
	ProjectileScript.draw_shot(self, style, dir, r, empowered)
	draw_set_transform_matrix(Transform2D.IDENTITY)


func _fletri(p: Vector2) -> void:
	var pts := PackedVector2Array()
	var radii := [1.0, 0.72, 1.05, 0.8, 0.95, 0.68, 1.0, 0.85]
	for i in radii.size():
		pts.append(p + Vector2.from_angle(0.2 + i * TAU / radii.size()) * 18.0 * radii[i])
	Art.shadow(self, p, 18.0)
	Art.volume(self, pts, Art.c("ennemi"), 0.6)
	Art.outline(self, pts, Art.c("ennemi_contour"), Art.TRAIT)


func _text(pos: Vector2, s: String, size: int, col: Color) -> void:
	draw_string(font, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)
