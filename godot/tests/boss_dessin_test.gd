## Test des boss redessinés (refonte des personnages, vague 2, B2 : Amanite-Mère, Saule exsangue) :
##   - chaque boss se dessine sans erreur dans toutes ses poses (annonces, phases, coup reçu, mort,
##     retournement), endormi et guéri ;
##   - l'annonce, la phase 3, le coup reçu et la mort changent l'image ;
##   - le dessin couvre au moins la taille de l'ancien (≥ 140 px de haut dans le jeu 1600×900).
## Rendu réel : tools/godot.sh --xvfb -s res://tests/boss_dessin_test.gd
extends SceneTree

const Bake = preload("res://tests/bestiaire/bake.gd")

const ARTS := {
	"spore": ["res://scripts/creature_art/spore/_amanite_mere.gd", ["nuages", "salve", "onde", "spirale", "invocation", "mycelium"]],
	"seve": ["res://scripts/creature_art/seve/_saule_exsangue.gd", ["racines", "rideau", "graines", "siphon", "invocation"]],
}
const BOX := Vector2i(320, 320)
const MIN_DIFF := 40

var failures := 0
var b


func check(cond: bool, what: String) -> void:
	if not cond:
		failures += 1
		print("  ÉCHEC ", what)


func _initialize() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	_run.call_deferred()


func _img(art, o: Dictionary) -> Image:
	return await b.bake(BOX, func(ci): art.draw(ci, Vector2(160, 290), art.HEIGHT, o), 1)


static func _diff(a: Image, c: Image) -> int:
	var n := 0
	for y in range(0, a.get_height(), 2):
		for x in range(0, a.get_width(), 2):
			var p := a.get_pixel(x, y)
			var q := c.get_pixel(x, y)
			if absf(p.r - q.r) + absf(p.g - q.g) + absf(p.b - q.b) + absf(p.a - q.a) > 0.25:
				n += 1
	return n


func _run() -> void:
	b = Bake.new(self)
	for id in ARTS:
		var art = load(ARTS[id][0])
		var rest := await _img(art, {"t": 0.4})
		var used := rest.get_used_rect()
		check(used.size.y >= 140, "%s : hauteur %d px ≥ 140" % [id, used.size.y])
		for attack in ARTS[id][1]:
			var img := await _img(art, {"t": 0.4, "attack": attack, "k": 0.9, "phase": 2, "lift": 1.0})
			check(img.get_used_rect().size.y > 0, "%s : annonce %s dessinée" % [id, attack])
		var announce := await _img(art, {"t": 0.4, "attack": ARTS[id][1][0], "k": 0.9})
		check(_diff(rest, announce) >= MIN_DIFF, "%s : l'annonce change l'image" % id)
		var p3 := await _img(art, {"t": 0.4, "phase": 3, "lift": 1.0})
		check(_diff(rest, p3) >= MIN_DIFF, "%s : la phase 3 change l'image" % id)
		var hit := await _img(art, {"t": 0.4, "hit": 1.0})
		check(_diff(rest, hit) >= MIN_DIFF, "%s : le coup reçu change l'image" % id)
		var dead := await _img(art, {"t": 0.4, "die": 0.6, "ash": 0.7})
		check(_diff(rest, dead) >= MIN_DIFF, "%s : la mort change l'image" % id)
		var flip := await _img(art, {"t": 0.4, "flip": true})
		check(_diff(rest, flip) >= MIN_DIFF, "%s : le retournement change l'image" % id)
		var mono := await _img(art, {"t": 0.4, "mono": true})
		check(mono.get_used_rect().size.y >= 100, "%s : silhouette" % id)
		var sleep: Image = await b.bake(BOX, func(ci): art.draw_sleeper(ci, Vector2(160, 290), art.HEIGHT, 0.5, true), 1)
		check(sleep.get_used_rect().size.y > 30, "%s : endormi dessiné" % id)
		var healed: Image = await b.bake(BOX, func(ci): art.draw_healed(ci, Vector2(160, 200), 1.0, 0.5), 1)
		check(healed.get_used_rect().size.y > 20, "%s : guéri dessiné" % id)
		print("%s : %d px de haut" % [id, used.size.y])
	print("boss_dessin_test : %s" % ("OK" if failures == 0 else "%d échec(s)" % failures))
	quit(0 if failures == 0 else 1)
