## Scénario « frontieres » du banc visuel (runner.gd ; refonte du monde, vague 3 B) : chaque frontière
## entre deux régions voisines, centrée sur son premier élément de passage, dans les trois états :
## deux régions flétries (les six paires), une seule purifiée (trois paires : le bord de vie traverse la
## bande), les deux purifiées (une paire). Jeu figé.
extends RefCounted

const Regions = preload("res://scripts/regions.gd")
const Frontieres = preload("res://scripts/world_art/frontieres.gd")
const DecorCompose = preload("res://scripts/world_bake/decor_compose.gd")

var r
var main


func run(runner) -> void:
	r = runner
	main = r.main
	main.autotest = false
	main.spawn_timer = 1.0e9
	main.player.set_physics_process(false)
	main.hud.glyphs.hide()
	var spots := {}
	for pr in Frontieres.pairs():
		var key: String = pr[0] + "-" + pr[1]
		spots[key] = [pr[0], pr[1], spot_of(key, pr[2])]
		await _look("frontiere_" + key, spots[key][2])
	# Une seule région purifiée : sa vie déborde sur la bande et chez la voisine (le front suit les îlots).
	for key in ["ronce-spore", "seve-vent", "aube-racine"]:
		if not spots.has(key):
			continue
		var a: String = spots[key][0]
		var p: Vector2 = spots[key][2]
		Game.flags[Regions.heart_flag(a)] = true
		var into_a := _toward(a, p)
		main.ground.paint(p + into_a * 260.0, 420.0, 1.0)
		await r._frames(90)
		await _look("frontiere_" + key + "_une", p)
	# Les deux purifiées.
	if spots.has("ronce-spore"):
		var p: Vector2 = spots["ronce-spore"][2]
		Game.flags[Regions.heart_flag("spore")] = true
		main.ground.paint(p, 900.0, 1.0)
		await r._frames(90)
		await _look("frontiere_ronce-spore_deux", p)


## Premier élément de passage de la paire, sinon un point de la demi-droite à 1500 px de la graine.
static func spot_of(key: String, angle: float) -> Vector2:
	for e in DecorCompose.passages:
		if e["pair"] == key:
			return e["pos"]
	return Vector2.from_angle(angle) * 1500.0


## Direction (unité) du point p vers l'intérieur de la région id (normale du bord le plus proche).
func _toward(id: String, p: Vector2) -> Vector2:
	var n := Regions.edge_normals(id)
	return n[0] if absf(p.dot(n[0])) < absf(p.dot(n[1])) else n[1]


func _look(shot: String, pos: Vector2) -> void:
	await r._place_player(pos + Vector2(170, 110))
	main.hud.banner_time = 0.0
	await r._frames(40)
	await r._shot(shot, "jeu")
