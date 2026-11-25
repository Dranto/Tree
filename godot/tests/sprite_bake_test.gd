## Test du prototype des sprites cuits (sprite_bake.gd) : la cuisson donne un atlas par sorte, chaque
## animation a ses images, l'image cuite couvre la silhouette (pixels opaques au centre, bords
## transparents), et le choix de l'image suit la pose. Rendu réel : lancer avec
##   tools/godot.sh --xvfb --audio-driver Dummy -s res://tests/sprite_bake_test.gd
extends SceneTree

const Sprites = preload("res://scripts/sprite_bake.gd")

var failures := 0


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("SPRITES ÉCHEC : ", what)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	Sprites.scale = 2.0
	var kinds := [["fletri", 14.0], ["tireur", 13.0], ["scarabee", 16.0]]
	await Sprites.bake(root, kinds)
	for kr in kinds:
		var a = Sprites.atlases.get(kr[0])
		_check(a != null, "%s : pas d'atlas" % kr[0])
		if a == null:
			continue
		for anim in ["idle", "walk", "windup", "charge", "recover", "strike"]:
			_check(a.anims.has(anim) and not a.anims[anim].is_empty(), "%s : animation %s absente" % [kr[0], anim])
		_check(a.unique >= 2 and a.unique <= a.total, "%s : %d images uniques sur %d" % [kr[0], a.unique, a.total])
		var img: Image = a.tex.get_image()
		var src: Rect2 = a.src(a.anims["idle"][0])
		var c := img.get_pixelv(Vector2i(src.position + a.anchor))
		_check(c.a > 0.9, "%s : centre de l'image transparent (%s)" % [kr[0], c])
		var corner := img.get_pixelv(Vector2i(src.position) + Vector2i.ONE)
		_check(corner.a < 0.05, "%s : coin de l'image opaque (%s)" % [kr[0], corner])
		# Choix de l'image selon la pose.
		_check(Sprites.frame_of(a, {"state": "windup", "k": 0.99}, 0.0) == a.anims["windup"][-1], "%s : fin de l'annonce" % kr[0])
		_check(Sprites.frame_of(a, {"moving": 1.0, "walk": 0.0}, 0.0) == a.anims["walk"][0], "%s : début de la marche" % kr[0])
		_check(Sprites.frame_of(a, {"strike": 0.1}, 0.0) == a.anims["strike"][0], "%s : frappe" % kr[0])
	_check(not Sprites.usable({"live": true}), "pose « live » prise pour cuite")
	_check(not Sprites.usable({"state": "leap"}), "état inconnu pris pour cuit")
	# Retournement : côté gardé près de la verticale, inclinaison bornée.
	_check(Sprites.facing(Vector2(-1, 0.1).normalized(), 1.0)[0] == -1.0, "retournement vers la gauche")
	_check(Sprites.facing(Vector2(0.05, 1.0).normalized(), -1.0)[0] == -1.0, "hystérésis du retournement")
	_check(absf(Sprites.facing(Vector2(1, 1).normalized(), 1.0)[1]) <= Sprites.TILT + 0.001, "inclinaison bornée")
	print("SPRITES %s" % ("réussi" if failures == 0 else "%d échecs" % failures))
	quit(1 if failures > 0 else 0)
