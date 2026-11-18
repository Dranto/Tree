## Projectile du Porte-Graine : graine, échardes, ronce vive, éclat (attaque de base, attack.gd)
## ou épine de la Volée d'épines.
extends Node2D

const AttackScript = preload("res://scripts/attack.gd")

var main
var vel := Vector2.ZERO
var damage := 10.0
var pierce := 0
var life := 1.1
var radius := 6.0
var hit := {}
## Épine (Volée d'épines) : dessin et couleur propres, saignement posé à chaque ennemi touché.
var thorn := false
var color := Color("d8ffb0")
var bleed := 0.0
var bleed_duration := 0.0
## Attaque de base : dessin de la forme (« graine », « echarde », « ronce_vive », « eclat »),
## branche du coup (résistances), attaque renforcée, modificateurs emportés (attack.gd, vide pour
## une compétence), fourche déjà faite, rebonds faits, ronce vive à planter et dégâts de son piège.
var style := "graine"
var branch := ""
var empowered := false
var attack: Dictionary = {}
var forked := false
var bounces := 0
var plant := false
var trap_dmg := 0.0
## Spores lobées : durée totale du vol en cloche (0 : tir tendu). La spore ne touche rien en vol et
## éclate à l'arrivée (attack.gd › land). Sauts déjà faits (modificateur « saut »).
var lob := 0.0
var jumps := 0
## Traînée d'épines : distance parcourue depuis la dernière touffe semée.
var _trail := 0.0
## Âge (s) : la graine « éclot » à sa sortie (dessin seulement).
var age := 0.0
const SORTIE := 0.08


func _ready() -> void:
	queue_redraw()


## La sortie ne dure que quelques images : on redessine seulement pendant ce temps (et tout le vol
## d'une spore lobée, qui monte puis redescend).
func _process(delta: float) -> void:
	if age < SORTIE or lob > 0.0:
		age += delta
		queue_redraw()
	else:
		set_process(false)


## Éclat d'impact (skill_fx.gd), si le jeu a des signatures (pas dans les bancs sans dessin).
func _burst(at: Vector2) -> void:
	if main != null and "skill_fx" in main and main.skill_fx != null:
		var thorny := thorn or style == "echarde" or style == "eclat"
		main.skill_fx.play("epine_impact" if thorny else "graine_impact", {"pos": at, "dir": vel.normalized(), "r": radius})


## Logique à pas fixe ; seuls les Flétris des cases voisines sont testés (grille spatiale).
func _physics_process(delta: float) -> void:
	position += vel * delta
	life -= delta
	var mods_on := not attack.is_empty()
	if mods_on and attack.has("trainee"):
		_trail += vel.length() * delta
		var every := float(AttackScript.mods().get("trainee", {}).get("every", 44.0))
		if _trail >= every:
			_trail -= every
			AttackScript.trail(main, position, damage, float(attack["trainee"]))
	if life <= 0.0:
		if plant:
			AttackScript.plant(main, position, trap_dmg, attack)
		if lob > 0.0:
			AttackScript.land(self)
		queue_free()
		return
	if lob > 0.0:
		return   # en vol, au-dessus des ennemis
	for e in main.enemies_near(position, radius):
		if e.dead or hit.has(e.get_instance_id()):
			continue
		hit[e.get_instance_id()] = true
		_burst(position)
		main.player_hit_enemy(e, damage, true, "ronce" if thorn else branch)
		if bleed > 0.0 and not e.dead:
			e.apply_status("saignement", damage * bleed, bleed_duration)
		if mods_on:
			AttackScript.on_projectile_hit(self, e)
		if pierce <= 0:
			if mods_on and AttackScript.on_projectile_end(self, e):
				return
			queue_free()
			return
		pierce -= 1


func _draw() -> void:
	# Sortie : la graine grossit en dépassant un peu sa taille (Anim.pop).
	var g := Anim.pop(clampf(age / SORTIE, 0.0, 1.0)) if age < SORTIE else 1.0
	if lob > 0.0:
		# Vol en cloche : l'ombre reste au sol, la spore monte puis redescend (hauteur ∝ durée du vol).
		var k := clampf(1.0 - life / lob, 0.0, 1.0)
		var h := sin(PI * k) * minf(90.0, 70.0 * lob)
		draw_colored_polygon(Art.ellipse(Vector2.ZERO, radius * (1.2 - 0.4 * sin(PI * k)), radius * 0.5, 12), Color(Art.c("ombre"), 0.45))
		draw_set_transform(Vector2(0, -h))
		draw_shot(self, style, vel.normalized(), radius * maxf(g, 0.2), empowered)
		draw_set_transform(Vector2.ZERO)
		return
	draw_shot(self, "epine" if thorn else style, vel.normalized(), radius * maxf(g, 0.2), empowered)


## Dessine un projectile centré sur l'origine, dans la direction dir, de rayon r (galerie comprise).
## style : « graine », « epine » (Volée d'épines), « echarde », « ronce_vive », « eclat »,
## « spore_lobee » ou « dard » (Spore).
## empowered : halo de l'attaque renforcée.
static func draw_shot(ci: CanvasItem, style: String, dir: Vector2, r: float, empowered := false) -> void:
	var n := dir.orthogonal()
	if empowered:
		# Attaque renforcée : un halo doré et une couronne claire, lisibles au milieu des autres tirs.
		ci.draw_circle(Vector2.ZERO, r * 2.6, Color(Art.c("or"), 0.16))
		ci.draw_arc(Vector2.ZERO, r * 2.1, 0.0, TAU, 16, Color(Art.c("or"), 0.7), maxf(1.5, r * 0.25), true)
	match style:
		"spore_lobee":
			# Spore lobée : une boule de spores violette, cerclée de sombre, avec trois pores clairs
			# et un halo de poussière. Elle tourne sur elle-même en vol (sens de la direction).
			var col := Art.ec("poison")
			var clair := Art.ec("poison", "clair")
			ci.draw_circle(Vector2.ZERO, r * 1.9, Color(col, 0.16))
			ci.draw_circle(Vector2.ZERO, r * 1.25, Art.c("contour"))
			ci.draw_circle(Vector2.ZERO, r * 1.1, col)
			ci.draw_circle(-n * r * 0.25 - dir * r * 0.15, r * 0.7, Art.ec("poison", "sombre"))
			for i in 3:
				var q := Vector2.from_angle(dir.angle() + i * TAU / 3.0) * r * 0.55
				ci.draw_circle(q, r * 0.22, clair)
			ci.draw_circle(n * r * 0.4 + dir * r * 0.3, r * 0.2, Color(1, 1, 1, 0.55))
		"dard":
			# Dard fongique : une aiguille fine et sombre, pointe claire, avec une goutte de poison à
			# l'arrière et un sillage court.
			var col := Art.ec("poison")
			var clair := Art.ec("poison", "clair")
			var tip := dir * r * 3.6
			var back := -dir * r * 1.6
			ci.draw_line(-dir * r * 5.5, back, Color(clair, 0.22), r * 0.7)
			var body := PackedVector2Array([tip, n * r * 0.45, back, -n * r * 0.45])
			var edge := body.duplicate()
			edge.append(tip)
			ci.draw_polyline(edge, Art.c("contour"), 1.5, true)
			ci.draw_colored_polygon(body, Art.ec("poison", "sombre"))
			ci.draw_colored_polygon(PackedVector2Array([tip, n * r * 0.45, dir * r * 0.4]), clair)
			ci.draw_circle(back, r * 0.55, col)
			ci.draw_circle(back - n * r * 0.15, r * 0.2, clair)
		"epine", "eclat":
			# Épine d'os : pointe claire vers l'avant, une moitié dans l'ombre, base teintée de sang.
			var clair := Art.ec("epine", "clair")
			var col := Art.ec("epine")
			var tip := dir * r * 2.4
			var back := -dir * r * 1.3
			if style == "epine":
				ci.draw_line(-dir * r * 4.5, back, Color(clair, 0.18), r * 0.9)
			ci.draw_line(-dir * r * 3.0, back, Color(clair, 0.35), r * 0.5)
			ci.draw_colored_polygon(PackedVector2Array([tip, back + n * r * 0.6, back]), clair)
			ci.draw_colored_polygon(PackedVector2Array([tip, back, back - n * r * 0.6]), col.darkened(0.2))
			ci.draw_polyline(PackedVector2Array([back + n * r * 0.6, tip, back - n * r * 0.6]), Art.c("contour"), 1.0, true)
			ci.draw_circle(back, r * 0.4, Art.ec("saignement", "clair"))
		"echarde":
			# Écharde : un éclat de bois long, fendu d'un trait clair, avec un sillage bref et tendu.
			var clair := Art.ec("epine", "clair")
			var col := Art.ec("epine")
			var tip := dir * r * 3.4
			var back := -dir * r * 1.8
			ci.draw_line(-dir * r * 6.5, back, Color(clair, 0.25), r * 0.8)
			var body := PackedVector2Array([tip, dir * r * 0.5 + n * r * 0.7, back + n * r * 0.35, back - n * r * 0.35, dir * r * 0.5 - n * r * 0.7])
			var edge := body.duplicate()
			edge.append(tip)
			ci.draw_polyline(edge, Art.c("contour"), 2.0, true)
			ci.draw_colored_polygon(body, col)
			ci.draw_colored_polygon(PackedVector2Array([tip, dir * r * 0.5 + n * r * 0.7, back + n * r * 0.35, -dir * r * 0.3]), clair)
			ci.draw_line(-dir * r * 0.8, tip * 0.85, Art.ec("epine", "sombre"), 1.0, true)
		"ronce_vive":
			# Ronce vive : une graine sombre veinée de sang, d'où pointent trois épines recourbées.
			var col := Art.ec("saignement")
			var clair := Art.ec("saignement", "clair")
			for i in 4:
				var k := 1.0 - i / 4.0
				ci.draw_circle(-dir * r * 1.5 * (i + 1), r * 0.8 * k, Color(clair, 0.25 * k))
			ci.draw_circle(Vector2.ZERO, r * 2.0, Color(clair, 0.16))
			for i in 3:
				var a := dir.angle() + PI * 0.35 + i * TAU / 3.0
				var base := Vector2.from_angle(a) * r * 1.1
				Art._thorn(ci, base, Vector2.from_angle(a + 0.5), r * 1.0, Art.ec("epine", "clair"))
			var pts := PackedVector2Array()
			for i in 12:
				var a := i * TAU / 12.0
				pts.append(dir * cos(a) * r * 1.4 + n * sin(a) * r * 1.1)
			var edge := pts.duplicate()
			edge.append(pts[0])
			ci.draw_polyline(edge, Art.c("contour"), 2.0, true)
			ci.draw_colored_polygon(pts, col)
			ci.draw_line(-dir * r * 0.9, dir * r * 0.9, clair, maxf(1.0, r * 0.25), true)
			ci.draw_circle(dir * r * 0.3 - n * r * 0.35, r * 0.3, Color(1, 1, 1, 0.6))
		_:
			# Graine de sève : une amande lumineuse avec sa petite feuille, et une traînée qui s'effile.
			var seve := Art.ec("seve")
			var clair := Art.ec("seve", "clair")
			for i in 5:
				var k := 1.0 - i / 5.0
				ci.draw_circle(-dir * r * 1.5 * (i + 1), r * 0.85 * k, Color(seve, 0.28 * k))
			ci.draw_circle(Vector2.ZERO, r * 1.9, Color(seve, 0.16))
			ci.draw_circle(Vector2.ZERO, r * 1.3, Color(seve, 0.28))
			var body := PackedVector2Array()
			for i in 12:
				var a := i * TAU / 12.0
				body.append(dir * cos(a) * r * 1.25 + n * sin(a) * r * 0.85)
			ci.draw_colored_polygon(body, Art.ec("seve", "sombre").lightened(0.35))
			ci.draw_circle(dir * r * 0.15 + Vector2(-r * 0.15, -r * 0.2), r * 0.55, clair)
			ci.draw_colored_polygon(HeroArt.leaf_pts(-dir * r * 1.3 + n * r * 0.4, r * 0.55, dir.angle() + PI - 0.6), Art.c("accent"))
