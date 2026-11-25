## Test du moteur de créatures (sprite_bake.gd) : toutes les sortes se cuisent sans erreur, chaque
## animation a ses images (et ses regards pour les sortes dessinées), l'image cuite couvre le dessin
## (pixels opaques, coins transparents), le choix de l'image suit la pose, la mémoire des 30 sortes
## reste sous MEMORY_MAX, le cache disque sert au second passage et se périme quand un script de
## dessin change. Rendu réel : lancer avec
##   tools/godot.sh --xvfb --audio-driver Dummy -s res://tests/sprite_bake_test.gd
extends SceneTree

const Sprites = preload("res://scripts/sprite_bake.gd")

## Mémoire gardée en jeu (octets, mipmaps comprises), élites comprises (atlas réutilisé) : le budget
## du moteur (atlas oubliés rendus au-delà), et le plus gros atlas permis pour une sorte.
const MEMORY_MAX := 70 * 1024 * 1024
const KIND_MAX := 5 * 1024 * 1024

var failures := 0


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("SPRITES ÉCHEC : ", what)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	Sprites.clear_disk_cache()
	var kinds := Sprites.all_kinds()
	var t0 := Time.get_ticks_msec()
	await Sprites.bake(root, kinds)
	var first_ms := Time.get_ticks_msec() - t0
	var scripted := 0
	for kr in kinds:
		var a = Sprites.atlases.get(kr[0])
		_check(a != null, "%s : pas d'atlas" % kr[0])
		if a == null:
			continue
		if a.scripted:
			scripted += 1
		for anim in Sprites._anims_wanted(kr[0]):
			_check(a.anims.has(anim) and not a.anims[anim][0].is_empty(), "%s : animation %s absente" % [kr[0], anim])
		if a.scripted:
			for anim in ["idle"] + (["windup"] if a.anims.has("windup") else []):
				_check(a.anims[anim].size() == (Sprites.LOOKS.size() if Sprites._const(Sprites.script_of(kr[0]), "LOOKS", true) else 1), "%s : regards de %s absents" % [kr[0], anim])
			_check(a.anims.has("hit"), "%s : coup reçu absent" % kr[0])
			_check(a.shadow_r.x > 2.0, "%s : ombre non relevée" % kr[0])
			_check(a.top < -float(Sprites.script_of(kr[0]).HEIGHT) * 0.25, "%s : haut du dessin trop bas (%.1f)" % [kr[0], a.top])
		_check(a.unique >= 1 and a.unique <= a.total, "%s : %d images uniques sur %d" % [kr[0], a.unique, a.total])
		var img: Image = a.tex.get_image()
		var src: Rect2 = a.src(a.anims["idle"][0][0])
		var used := img.get_region(Rect2i(src)).get_used_rect()
		_check(used.size.x > src.size.x * 0.5 and used.size.y > src.size.y * 0.5, "%s : image presque vide (%s dans %s)" % [kr[0], used, src.size])
		var corner := img.get_pixelv(Vector2i(src.position) + Vector2i.ONE)
		_check(corner.a < 0.05, "%s : coin de l'image opaque (%s)" % [kr[0], corner])
		# Choix de l'image selon la pose.
		if a.anims.has("windup"):
			_check(Sprites.frame_of(a, {"state": "windup", "k": 0.99}, 0.0) == a.anims["windup"][mini(1, a.anims["windup"].size() - 1)][-1], "%s : fin de l'annonce" % kr[0])
		_check(Sprites.frame_of(a, {"moving": 1.0, "walk": 0.0}, 0.0) == a.anims["walk"][mini(1, a.anims["walk"].size() - 1)][0], "%s : début de la marche" % kr[0])
		_check(Sprites.frame_of(a, {"strike": 0.1}, 0.0) == a.anims["strike"][0][0], "%s : frappe" % kr[0])
		if a.scripted:
			_check(Sprites.frame_of(a, {}, 0.0, 0) == a.anims["idle"][0][0], "%s : regard vers le haut" % kr[0])
			_check(Sprites.frame_of(a, {"flash": 0.9}, 0.0) == a.anims["hit"][0][0], "%s : coup reçu" % kr[0])
		# Image pour les autres systèmes (morts, impact frames).
		var fr := Sprites.frame(kr[0], {"moving": 1.0, "walk": 1.0})
		_check(fr.has("tex") and fr["rect"].size.x > 0.0 and fr["r"] == kr[1], "%s : frame() incomplet" % kr[0])
		_check(not Sprites.mono(kr[0]).is_empty(), "%s : mono() vide" % kr[0])
	_check(scripted >= 3, "sortes dessinées cuites : %d (tireur, scarabée, menhir attendus)" % scripted)
	var mem := Sprites.total_bytes()
	print("SPRITES cuisson de %d sortes (%d dessinées) ×%.0f : %d ms, %.1f Mo" % [kinds.size(), scripted, Sprites.scale, first_ms, mem / 1048576.0])
	for kr in kinds:
		var a = Sprites.atlases.get(kr[0])
		if a != null:
			print("SPRITES   %-14s %s %3d images (%3d uniques), case %4dx%-4d %5.2f Mo" % [kr[0], "dessin " if a.scripted else "ancien ", a.total, a.unique, a.cell.x, a.cell.y, a.bytes / 1048576.0])
	for kr in kinds:
		var a = Sprites.atlases.get(kr[0])
		if a != null:
			_check(a.bytes <= KIND_MAX, "%s : atlas de %.1f Mo (au plus %d)" % [kr[0], a.bytes / 1048576.0, KIND_MAX / 1048576])
	_check(Sprites.budget <= MEMORY_MAX, "budget du moteur au-dessus de %d Mo" % (MEMORY_MAX / 1048576))
	# Budget : au-delà, les atlas qui n'ont pas servi depuis un moment sont rendus (relus du cache).
	var keep: int = Sprites.budget
	Sprites.budget = mem / 2
	for a in Sprites.atlases.values():
		a.last_used -= Sprites.UNUSED_MSEC + 10
	Sprites.atlases["tireur"].last_used = Time.get_ticks_msec()
	var freed := Sprites.trim()
	_check(freed > 0 and Sprites.total_bytes() <= mem / 2, "budget non tenu (%d rendus, %.1f Mo)" % [freed, Sprites.total_bytes() / 1048576.0])
	_check(Sprites.atlases.has("tireur"), "un atlas utilisé à l'instant a été rendu")
	Sprites.budget = keep
	_check(not Sprites.usable({"live": true}), "pose « live » de l'ancien dessin prise pour cuite")
	_check(Sprites.usable({"live": true}, Sprites.atlases.get("tireur")), "pose « live » d'une sorte dessinée refusée")
	_check(not Sprites.usable({"state": "leap"}), "état inconnu pris pour cuit")
	# Retournement : côté gardé près de la verticale, inclinaison bornée, regard.
	_check(Sprites.facing(Vector2(-1, 0.1).normalized(), 1.0)[0] == -1.0, "retournement vers la gauche")
	_check(Sprites.facing(Vector2(0.05, 1.0).normalized(), -1.0)[0] == -1.0, "hystérésis du retournement")
	_check(absf(Sprites.facing(Vector2(1, 1).normalized(), 1.0)[1]) <= Sprites.TILT + 0.001, "inclinaison bornée")
	_check(Sprites.facing(Vector2(1, -0.8).normalized(), 1.0)[2] == 0, "regard vers le haut (à droite)")
	_check(Sprites.facing(Vector2(-1, -0.8).normalized(), -1.0)[2] == 0, "regard vers le haut (à gauche)")
	_check(Sprites.facing(Vector2(-1, 0.8).normalized(), -1.0)[2] == 2, "regard vers le bas (à gauche)")
	# Cache disque : le second passage lit tout depuis user://sprites/.
	_check(Sprites.cache_writes == kinds.size(), "cache : %d écrits sur %d" % [Sprites.cache_writes, kinds.size()])
	Sprites.clear()
	t0 = Time.get_ticks_msec()
	await Sprites.bake(root, kinds)
	print("SPRITES relecture du cache : %d ms, %d sortes" % [Time.get_ticks_msec() - t0, Sprites.cache_hits])
	_check(Sprites.cache_hits == kinds.size(), "cache : %d relus sur %d" % [Sprites.cache_hits, kinds.size()])
	_check(Sprites.atlases.has("tireur") and Sprites.atlases["tireur"].from_cache and Sprites.atlases["tireur"].scripted, "tireur relu du cache")
	# Un script de dessin qui change périme son cache (copie des scripts dans user://).
	var dir := "user://creature_art_test/"
	for sub in ["ronce"]:
		DirAccess.make_dir_recursive_absolute(dir + sub)
		for f in DirAccess.get_files_at("res://scripts/creature_art/" + sub):
			if f.ends_with(".gd"):
				DirAccess.copy_absolute("res://scripts/creature_art/%s/%s" % [sub, f], dir + sub + "/" + f)
	Sprites.creature_dir = dir
	Sprites.forget_signatures()
	var before := Sprites.fingerprint("tireur", 13.0)
	var f := FileAccess.open(dir + "ronce/tireur.gd", FileAccess.READ_WRITE)
	f.seek_end()
	f.store_string("\n# changé par sprite_bake_test\n")
	f.close()
	Sprites.forget_signatures()
	var after := Sprites.fingerprint("tireur", 13.0)
	_check(before != after, "empreinte inchangée après une modification du script")
	_check(Sprites._load_cached("tireur", 13.0) == null, "cache encore servi après une modification du script")
	Sprites.creature_dir = Sprites.CREATURE_DIR
	Sprites.forget_signatures()
	_check(Sprites._load_cached("tireur", 13.0) != null, "cache perdu sans modification")
	print("SPRITES %s" % ("réussi" if failures == 0 else "%d échecs" % failures))
	quit(1 if failures > 0 else 0)
