## Test des Flétris de Sève redessinés (scripts/creature_art/seve/, R4) :
##   - chaque sorte se dessine sans erreur dans toutes les poses que le moteur cuit (contrat moteur :
##     repos, marche 12 images, annonce, charge, retour, frappe, coup reçu, élite, poses propres) ;
##   - taille à l'écran 1080p ≥ minimum de son rôle (chargeur/bondisseur/piqueur 44 px, soutien 56) ;
##   - l'annonce, le coup reçu, l'élite et les poses propres changent l'image ;
##   - silhouettes distinctes deux à deux dans la région (contraste et couleurs : tests/bestiaire_test.gd).
## Rendu réel : tools/godot.sh --xvfb -s res://tests/seve_bestiaire_test.gd
extends SceneTree

const Bake = preload("res://tests/bestiaire/bake.gd")
const C = preload("res://tests/bestiaire/commun.gd")

const KINDS := {"sangsue_vase": 44.0, "crapaud": 44.0, "libellule": 44.0, "souche": 56.0}
const BOX := Vector2i(200, 200)
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


func _img(art, o: Dictionary) -> Image:
	return await b.bake(BOX, func(ci): art.draw(ci, Vector2(100, 175), 130.0, o), 1)


static func _diff(a: Image, c: Image) -> int:
	var n := 0
	for y in range(0, a.get_height(), 2):
		for x in range(0, a.get_width(), 2):
			var p := a.get_pixel(x, y)
			var q := c.get_pixel(x, y)
			if absf(p.r - q.r) + absf(p.g - q.g) + absf(p.b - q.b) + absf(p.a - q.a) > 0.25:
				n += 1
	return n


static func _mask(img: Image) -> PackedByteArray:
	var m := PackedByteArray()
	m.resize(img.get_width() * img.get_height())
	for y in img.get_height():
		for x in img.get_width():
			m[y * img.get_width() + x] = 1 if img.get_pixel(x, y).a > 0.6 else 0
	return m


func _run() -> void:
	b = Bake.new(self)
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/enemies.json"))
	var regions := {}
	for kd in data["kinds"]:
		regions[kd["id"]] = kd.get("region", "")
	var masks := {}
	for id: String in KINDS:
		print(id)
		check(regions.get(id, "") == "seve", "%s : sorte de Sève dans enemies.json" % id)
		var art = load("res://scripts/creature_art/seve/%s.gd" % id)
		check(art != null, "%s : script trouvé par son chemin" % id)
		if art == null:
			continue
		check(art.HEIGHT * C.S1080 >= KINDS[id], "%s : %.0f px à l'écran ≥ %.0f" % [id, art.HEIGHT * C.S1080, KINDS[id]])
		# Toutes les poses du moteur.
		var poses := []
		for look: float in [-0.45, 0.0, 0.45]:
			poses.append({"t": 0.3, "look": look})
			for i in 12:
				poses.append({"t": i / 12.0, "walk": TAU * i / 12.0, "moving": 1.0, "look": look})
			for kk: float in [0.0, 0.33, 0.66, 1.0]:
				poses.append({"t": 0.3, "state": "windup", "k": kk, "look": look})
		poses.append_array([{"t": 0.3, "state": "charge", "charge": 1.0, "moving": 1.0, "walk": 1.0}, {"t": 0.3, "state": "recover"}])
		for s: float in [0.0, 0.5, 1.0]:
			poses.append({"t": 0.3, "strike": s})
		for hh: float in [1.0, 0.5]:
			poses.append({"t": 0.3, "hit": hh})
		if "CUSTOM" in art:
			for key: String in art.CUSTOM:
				for v: float in [0.0, 0.5, 1.0]:
					poses.append({"t": 0.3, key: v})
		await b.bake(Vector2i(64, 64), func(ci):
			for o: Dictionary in poses:
				art.draw(ci, Vector2(32, 56), 40.0, o), 1)
		var rest: Image = await _img(art, {"t": 0.3})
		var wind: Image = await _img(art, {"t": 0.3, "state": "windup", "k": 1.0})
		var hit: Image = await _img(art, {"t": 0.3, "hit": 1.0})
		var elite: Image = await _img(art, {"t": 0.3, "elite": true, "region": "seve"})
		check(_diff(rest, wind) > MIN_DIFF, "%s : l'annonce se voit" % id)
		check(_diff(rest, hit) > MIN_DIFF, "%s : le coup reçu se voit" % id)
		check(not ("DRAWS_ELITE" in art) or _diff(rest, elite) > MIN_DIFF, "%s : l'élite se voit" % id)
		if "CUSTOM" in art:
			for key: String in art.CUSTOM:
				var cu: Image = await _img(art, {"t": 0.3, key: 1.0})
				check(_diff(rest, cu) > MIN_DIFF, "%s : la pose « %s » se voit" % [id, key])
		masks[id] = _mask(rest)
	# Silhouettes distinctes deux à deux (recouvrement des masques).
	var ids := masks.keys()
	for i in ids.size():
		for j in range(i + 1, ids.size()):
			var a: PackedByteArray = masks[ids[i]]
			var c: PackedByteArray = masks[ids[j]]
			var inter := 0
			var uni := 0
			for q in a.size():
				inter += a[q] & c[q]
				uni += a[q] | c[q]
			var iou := float(inter) / maxi(uni, 1)
			check(iou < 0.6, "%s / %s : silhouettes distinctes (recouvrement %.2f)" % [ids[i], ids[j], iou])
	print("Flétris de Sève : %s" % ("OK" if failures == 0 else "%d échec(s)" % failures))
	quit(1 if failures > 0 else 0)
