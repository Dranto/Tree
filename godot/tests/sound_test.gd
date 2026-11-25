## Test du son : bruitages (pas de silence, pas de saturation, extinction propre, fichiers à jour, variantes),
## musique en couches et ambiances (boucles qui raccordent, pistes à jour d'après leurs empreintes,
## couches de chaque région), limite de sons identiques, mélange dynamique de la musique (exploration,
## combat, Cœur, boss, régions), volumes par catégorie.
## Lancer : tools/godot.sh --headless -s res://tests/sound_test.gd
extends SceneTree

const Synth = preload("res://scripts/synth.gd")
const MusicSynth = preload("res://scripts/music_synth.gd")
const RegionAudio = preload("res://scripts/region_audio.gd")
const SoundRefs = preload("res://scripts/sound_refs.gd")
const MANIFEST := "res://assets/music/empreintes.json"
var failures := 0


func check(cond: bool, what: String) -> void:
	if cond:
		print("  ok   ", what)
	else:
		failures += 1
		print("  ÉCHEC ", what)


func _initialize() -> void:
	_run.call_deferred()


func _peak_rms(a: PackedFloat32Array) -> Array:
	var pk := 0.0
	var sq := 0.0
	for v in a:
		pk = maxf(pk, absf(v))
		sq += v * v
	return [pk, sqrt(sq / maxf(1.0, a.size()))]


## Échantillons d'un .wav écrit par synth.gd (mono, 16 bits).
func _read_wav(path: String) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return out
	var b := f.get_buffer(f.get_length())
	out.resize((b.size() - 44) / 2)
	for i in out.size():
		out[i] = b.decode_s16(44 + i * 2) / 32768.0
	return out


## Une boucle raccorde si le saut entre la fin et le début n'est pas plus grand que les sauts ordinaires
## de la piste (aucun clic à la reprise).
func _seamless(a: PackedFloat32Array) -> bool:
	if a.size() < 1000:
		return false
	var steps := PackedFloat32Array()
	for i in range(1, a.size(), 7):
		steps.append(absf(a[i] - a[i - 1]))
	steps.sort()
	var big: float = steps[int(steps.size() * 0.999)]
	return absf(a[0] - a[a.size() - 1]) <= maxf(big, 0.02)


func _run() -> void:
	var sfx = root.get_node("Sfx")
	var music = root.get_node("Music")
	var settings = root.get_node("Settings")

	print("Bruitages")
	for name in Synth.SOUNDS:
		var a: PackedFloat32Array = Synth.render(name)
		var pr := _peak_rms(a)
		check(pr[0] > 0.03 and pr[0] <= 1.0, "%s : audible et sans saturation (crête %.2f)" % [name, pr[0]])
		check(absf(a[a.size() - 1]) < 0.02, "%s : s'éteint sans clic" % name)
		check(a.size() > 400, "%s : durée plausible" % name)
	for name in ["impact_lourd", "critique", "mort_elite", "annonce"]:
		check(Synth.SOUNDS.has(name), "son demandé par le ressenti du combat : %s" % name)
	check(Synth.variant_names("impact").size() == 3 and Synth.render("impact", 1) != Synth.render("impact"), "impact : trois variantes différentes")
	check(float(Synth.SOUNDS["critique"]["peak"]) > float(Synth.SOUNDS["impact"]["peak"]), "un critique sonne plus fort qu'un coup")

	print("Fichiers du dépôt")
	for name in Synth.SOUNDS:
		var names := Synth.variant_names(name)
		for v in names.size():
			var f := FileAccess.open("res://assets/sounds/%s.wav" % names[v], FileAccess.READ)
			check(f != null and f.get_buffer(f.get_length()) == Synth.to_wav(Synth.render(name, v)), "%s.wav à jour (relancer tools/gen-sounds.sh sinon)" % names[v])

	print("Musique et ambiances")
	var manifest = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	check(manifest is Dictionary and int(manifest.get("version", 0)) == MusicSynth.VERSION, "empreintes.json à jour (relancer tools/gen-sounds.sh sinon)")
	if not manifest is Dictionary:
		manifest = {"music": {}, "beds": {}}
	var styles := {"": {}}
	styles.merge(RegionAudio.all_music_styles())
	check(styles.has("spore") and styles.has("vent") and styles.has("seve") and styles.has("aube") and styles.has("racine") and styles.has("finale"), "chaque région a sa musique (data/audio.json)")
	var seen_fp: Array = []
	for id in styles:
		var layers := RegionAudio.music_layers(styles[id])
		if id != "generique":
			check(layers.size() == 5, "%s : cinq couches (exploration sombre et lumineuse, combat, Cœur, boss)" % (id if id != "" else "monde"))
		for layer in layers:
			var path := RegionAudio.music_path(id, layer)
			var fp := MusicSynth.fingerprint(layer, styles[id])
			check(int(manifest["music"].get(path, 0)) == fp, "%s : piste à jour d'après son empreinte" % path.get_file())
			if layer in ["lumineux", "boss"]:
				check(not fp in seen_fp, "%s : un thème qui n'est celui d'aucune autre région" % path.get_file())
				seen_fp.append(fp)
			var a := _read_wav(path)
			var pr := _peak_rms(a)
			check(absi(a.size() - int(MusicSynth.LOOP * Synth.RATE)) <= 1, "%s : 24 s" % path.get_file())
			check(pr[0] > 0.3 and pr[0] <= 0.81 and pr[1] > 0.03, "%s : niveau correct (crête %.2f, efficace %.3f)" % [path.get_file(), pr[0], pr[1]])
			check(_seamless(a), "%s : la fin raccorde le début de la boucle" % path.get_file())
	var beds := {"": {}}
	beds.merge(RegionAudio.all_beds())
	check(beds.size() >= 7, "nappes d'ambiance : le monde et chaque région")
	for id in beds:
		for file in RegionAudio.BED_STATES:
			var path := RegionAudio.bed_path(id, file)
			check(int(manifest["beds"].get(path, 0)) == MusicSynth.bed_fingerprint(RegionAudio.BED_STATES[file], beds[id]), "%s : nappe à jour d'après son empreinte" % path.get_file())
			var a := _read_wav(path)
			check(absi(a.size() - int(MusicSynth.BED_LOOP * Synth.RATE)) <= 1 and _peak_rms(a)[1] > 0.01, "%s : 12 s, audible" % path.get_file())
	# Un rendu complet sur deux couches, pour vérifier les formules elles-mêmes (le reste par empreintes).
	var combat := Synth.music_layer("combat", styles.get("vent", {}))
	check(Synth.to_wav(combat) == FileAccess.get_file_as_bytes(RegionAudio.music_path("vent", "combat")), "vent_combat.wav identique à un nouveau rendu")
	check(_seamless(combat), "rendu en anneau : la boucle raccorde")
	check(MusicSynth.fingerprint("sombre", {}) == MusicSynth.fingerprint("sombre", {"dark": {}}), "sans réglage : la musique de Ronce")
	for id in ["ronce", "spore", "vent", "seve", "aube", "racine", "finale"]:
		for key in RegionAudio.BOSS_KEYS:
			check(Synth.SOUNDS.has(RegionAudio.boss_sound(id, key)), "%s : un son de boss « %s »" % [id, key])
	check(RegionAudio.validate().is_empty(), "réglages de son et d'ambiance valides : %s" % [RegionAudio.validate()])

	print("Sfx")
	check(not sfx.enabled and not music.enabled, "muet en test (sans écran)")
	sfx.enabled = true
	for name in ["impact", "mort", "clic"]:
		sfx.streams[name] = [sfx.get_script().load_wav("res://assets/sounds/%s.wav" % name)]
	for i in sfx.POOL:
		var p := AudioStreamPlayer.new()
		p.bus = "Effets"
		sfx.add_child(p)
		sfx.players.append(p)
	sfx.played = 0
	sfx.recent.clear()
	for i in 6:
		sfx.play("impact")
	check(sfx.played == 3, "3 impacts identiques au plus par 50 ms (obtenu %d)" % sfx.played)
	sfx.play("mort")
	check(sfx.played == 4, "un autre son n'est pas limité")
	sfx.play("inconnu")
	check(sfx.played == 4, "son inconnu ignoré")
	var far := Node2D.new()
	root.add_child(far)
	sfx.listener = far
	far.global_position = Vector2.ZERO
	sfx.recent.clear()
	sfx.play("impact", Vector2(5000, 0))
	check(sfx.played == 4, "son trop lointain non joué")
	sfx.play("impact", Vector2(100, 0))
	check(sfx.played == 5, "son proche joué")
	# Versions régionales : un coup dans le marais prend la voix du marais, dans l'oasis la voix commune.
	sfx.streams["impact@spore"] = sfx.streams["impact"]
	var Regions = load("res://scripts/regions.gd")
	check(sfx.regional("impact", Regions.center("spore")) == "impact@spore", "un coup dans Spore prend sa version régionale")
	check(sfx.regional("impact", Vector2.ZERO) == "impact", "dans l'oasis, la version commune")
	check(sfx.regional("mort", Regions.center("spore")) == "mort", "sans version régionale, le son commun")
	for reg in ["spore", "vent", "seve", "aube", "racine"]:
		for base in ["impact", "critique", "impact_lourd", "mort", "mort_elite", "coeur"]:
			check(Synth.SOUNDS.has(base + "@" + reg), "%s : une version régionale de « %s »" % [reg, base])
	var all_loaded := true
	for name in Synth.SOUNDS:
		for file in Synth.variant_names(name):
			var st = sfx.get_script().load_wav("res://assets/sounds/%s.wav" % file)
			all_loaded = all_loaded and st != null and st.get_length() > 0.015
	check(all_loaded, "tous les sons de synth.gd (et leurs variantes) ont un fichier lisible")
	sfx.enabled = false

	print("Musique : couches")
	music.enabled = true
	var fake := {}
	for layer in RegionAudio.LAYERS:
		fake[layer] = AudioStreamPlayer.new()
		music.add_child(fake[layer])
	music.groups = {"": {"players": fake, "gain": 1.0}}
	music.beds = {}
	music.region = ""
	music.mix = 0.0
	music.combat = 0.0
	music.heart = 0.0
	music.boss = 0.0
	music.duck_gain = 1.0
	music.set_mood(0.0)
	check(music.target == 0.0, "terre morte : cible sombre")
	music.set_mood(0.9)
	check(music.target == 1.0, "prairie : cible lumineuse")
	for i in 5:
		music._process(1.0)
	check(fake["lumineux"].volume_db > -1.0 and fake["sombre"].volume_db <= -60.0, "fondu vers la couche lumineuse")
	music.set_mood(0.38)
	for i in 10:
		music._process(0.1)
	var d: float = db_to_linear(fake["sombre"].volume_db)
	var b: float = db_to_linear(fake["lumineux"].volume_db)
	check(absf(d * d + b * b - 1.0) < 0.02, "mélange à puissance constante")
	check(fake["combat"].volume_db <= -60.0 and fake["boss"].volume_db <= -60.0 and fake["coeur"].volume_db <= -60.0, "au calme : ni combat, ni Cœur, ni boss")
	music.set_combat(1.0)
	for i in 4:
		music._process(0.5)
	check(fake["combat"].volume_db > -1.0, "Flétris proches : la couche de combat monte")
	check(db_to_linear(fake["lumineux"].volume_db) > 0.3, "l'exploration continue sous le combat (pas de coupure)")
	music.set_combat(0.0)
	music._process(1.0)
	check(fake["combat"].volume_db > -3.0, "le combat tient encore un moment après le dernier Flétri")
	for i in 10:
		music._process(1.0)
	check(fake["combat"].volume_db <= -60.0, "puis retombe")
	music.set_heart(1.0)
	for i in 4:
		music._process(1.0)
	check(fake["coeur"].volume_db > -1.0, "siège d'un Cœur : la couche du Cœur monte")
	music.set_heart(0.0)
	music.set_boss(true)
	for i in 4:
		music._process(1.0)
	check(fake["boss"].volume_db > -1.0 and fake["sombre"].volume_db <= -60.0 and fake["lumineux"].volume_db <= -60.0 and fake["coeur"].volume_db <= -60.0, "combat de boss : son thème seul")
	music.set_boss(false)
	for i in 4:
		music._process(1.0)
	check(fake["boss"].volume_db <= -60.0, "boss vaincu : retour à l'exploration")
	music.duck(1.0)
	var before: float = db_to_linear(fake["lumineux"].volume_db)
	music._apply()
	check(db_to_linear(fake["lumineux"].volume_db) < before * 0.5, "un grand bruitage baisse la musique un instant")
	for i in 3:
		music._process(1.0)
	check(is_equal_approx(music.duck_gain, 1.0), "puis elle remonte")

	print("Musique : changement de région")
	var other := {}
	for layer in ["sombre", "lumineux"]:
		other[layer] = AudioStreamPlayer.new()
		music.add_child(other[layer])
	music.groups["essai"] = {"players": other, "gain": 0.0}
	music.set_mood(0.0, "essai")
	check(music.region == "essai", "la région du joueur est visée")
	for i in 5:
		music._process(1.0)
	check(is_equal_approx(music.groups["essai"]["gain"], 1.0) and music.groups[""]["gain"] == 0.0, "fondu vers la musique de la région")
	check(other["sombre"].volume_db > -1.0 and fake["sombre"].volume_db <= -60.0, "région : sa couche sombre seule, monde coupé")
	music.set_boss(true)
	for i in 4:
		music._process(1.0)
	check(other["sombre"].volume_db <= -60.0 or db_to_linear(other["sombre"].volume_db) < 0.7, "région sans thème de boss : l'exploration cède la place au combat")
	music.set_boss(false)
	music.set_mood(0.0, "")
	for i in 5:
		music._process(1.0)
	check(music.groups[""]["gain"] == 1.0 and other["sombre"].volume_db <= -60.0, "retour à la musique du monde hors région")
	music.set_mood(0.0, "inconnue")
	check(music.region == "", "région sans piste : musique du monde")
	music.groups = {}
	music.enabled = false

	print("Sons : références des données")
	check(SoundRefs.validate().is_empty(), "chaque son nommé dans les données existe : %s" % [SoundRefs.validate()])
	var missing: Array = []
	for f in DirAccess.get_files_at("res://scripts/skills"):
		var src := FileAccess.get_file_as_string("res://scripts/skills/" + f)
		var rx := RegEx.create_from_string("Sfx\\.play\\(\"([a-z_]+)\"")
		for m in rx.search_all(src):
			if not Synth.SOUNDS.has(m.get_string(1)):
				missing.append("%s : %s" % [f, m.get_string(1)])
	check(missing.is_empty(), "chaque son joué par une compétence existe : %s" % [missing])

	print("Réglages")
	settings.set_music_volume(0.5)
	settings.set_sfx_volume(0.0)
	settings.set_ambience_volume(0.25)
	var im := AudioServer.get_bus_index("Musique")
	var ie := AudioServer.get_bus_index("Effets")
	var ia := AudioServer.get_bus_index("Ambiance")
	check(im >= 0 and ie >= 0 and ia >= 0, "bus Musique, Effets et Ambiance créés")
	check(absf(AudioServer.get_bus_volume_db(im) - linear_to_db(0.5)) < 0.01, "volume de la musique appliqué")
	check(absf(AudioServer.get_bus_volume_db(ia) - linear_to_db(0.25)) < 0.01, "volume de l'ambiance appliqué")
	check(AudioServer.is_bus_mute(ie), "effets à zéro : bus coupé")
	settings.set_music_volume(0.7)
	settings.set_sfx_volume(0.9)
	settings.set_ambience_volume(0.8)

	print("ÉCHECS : %d" % failures if failures > 0 else "Tout est bon.")
	quit(1 if failures > 0 else 0)
