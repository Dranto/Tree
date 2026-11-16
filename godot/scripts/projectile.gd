## Graine lumineuse tirée par le Porte-Graine.
extends Node2D

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
## Âge (s) : la graine « éclot » à sa sortie (dessin seulement).
var age := 0.0
const SORTIE := 0.08


func _ready() -> void:
	queue_redraw()


## La sortie ne dure que quelques images : on redessine seulement pendant ce temps.
func _process(delta: float) -> void:
	if age < SORTIE:
		age += delta
		queue_redraw()
	else:
		set_process(false)


## Éclat d'impact (skill_fx.gd), si le jeu a des signatures (pas dans les bancs sans dessin).
func _burst(at: Vector2) -> void:
	if main != null and "skill_fx" in main and main.skill_fx != null:
		main.skill_fx.play("epine_impact" if thorn else "graine_impact", {"pos": at, "dir": vel.normalized(), "r": radius})


## Logique à pas fixe ; seuls les Flétris des cases voisines sont testés (grille spatiale).
func _physics_process(delta: float) -> void:
	position += vel * delta
	life -= delta
	if life <= 0.0:
		queue_free()
		return
	for e in main.enemies_near(position, radius):
		if e.dead or hit.has(e.get_instance_id()):
			continue
		hit[e.get_instance_id()] = true
		_burst(position)
		main.player_hit_enemy(e, damage, true, "ronce" if thorn else "")
		if bleed > 0.0 and not e.dead:
			e.apply_status("saignement", damage * bleed, bleed_duration)
		if pierce <= 0:
			queue_free()
			return
		pierce -= 1


func _draw() -> void:
	var dir := vel.normalized()
	var n := dir.orthogonal()
	# Sortie : la graine grossit en dépassant un peu sa taille (Anim.pop).
	var g := Anim.pop(clampf(age / SORTIE, 0.0, 1.0)) if age < SORTIE else 1.0
	var r := radius * maxf(g, 0.2)
	if thorn:
		# Épine d'os : pointe claire vers l'avant, une moitié dans l'ombre, base teintée de sang.
		var clair := Art.ec("epine", "clair")
		var col := Art.ec("epine")
		var tip := dir * r * 2.4
		var back := -dir * r * 1.3
		draw_line(-dir * r * 4.5, back, Color(clair, 0.18), r * 0.9)
		draw_line(-dir * r * 3.0, back, Color(clair, 0.35), r * 0.5)
		draw_colored_polygon(PackedVector2Array([tip, back + n * r * 0.6, back]), clair)
		draw_colored_polygon(PackedVector2Array([tip, back, back - n * r * 0.6]), col.darkened(0.2))
		draw_polyline(PackedVector2Array([back + n * r * 0.6, tip, back - n * r * 0.6]), Art.c("contour"), 1.0, true)
		draw_circle(back, r * 0.4, Art.ec("saignement", "clair"))
		return
	# Graine de sève : une amande lumineuse avec sa petite feuille, et une traînée qui s'effile.
	var seve := Art.ec("seve")
	var clair := Art.ec("seve", "clair")
	for i in 5:
		var k := 1.0 - i / 5.0
		draw_circle(-dir * r * 1.5 * (i + 1), r * 0.85 * k, Color(seve, 0.28 * k))
	draw_circle(Vector2.ZERO, r * 1.9, Color(seve, 0.16))
	draw_circle(Vector2.ZERO, r * 1.3, Color(seve, 0.28))
	var body := PackedVector2Array()
	for i in 12:
		var a := i * TAU / 12.0
		body.append(dir * cos(a) * r * 1.25 + n * sin(a) * r * 0.85)
	draw_colored_polygon(body, Art.ec("seve", "sombre").lightened(0.35))
	draw_circle(dir * r * 0.15 + Vector2(-r * 0.15, -r * 0.2), r * 0.55, clair)
	draw_colored_polygon(HeroArt.leaf_pts(-dir * r * 1.3 + n * r * 0.4, r * 0.55, dir.angle() + PI - 0.6), Art.c("accent"))
