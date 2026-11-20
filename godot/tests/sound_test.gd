## Test du son : synthèse (pas de silence, pas de saturation, extinction propre), boucle de musique sans
## coupure, fichiers .wav à jour, limite de sons identiques, mélange de la musique selon la vie du sol.
## Lancer : tools/godot.sh --headless -s res://tests/sound_test.gd
extends SceneTree

const Synth = preload("res://scripts/synth.gd")
const RegionAudio = preload("res://scripts/region_audio.gd")
const SoundRefs = preload("res://scripts/sound_refs.gd")
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


func _run() -> void:
	var sfx = root.get_node("Sfx")
	var music = root.get_node("Music")
	var settings = root.get_node("Settings")

	print("Synthèse")
	for name in Synth.SOUNDS:
		var a: PackedFloat32Array = Synth.render(name)
		var pr := _peak_rms(a)
		check(pr[0] > 0.03 and pr[0] <= 1.0, "%s : audible et sans saturation (crête %.2f)" % [name, pr[0]])
		check(absf(a[a.size() - 1]) < 0.02, "%s : s'éteint sans clic" % name)
		check(a.size() > 400, "%s : durée plausible" % name)
	for pair in [["sombre", Synth.music_dark()], ["lumineux", Synth.music_bright()]]:
		var a: PackedFloat32Array = pair[1]
		var pr := _peak_rms(a)
		check(pr[0] > 0.3 and pr[0] <= 0.81, "musique %s : niveau correct (crête %.2f)" % [pair[0], pr[0]])
		check(absf(a[0] - a[a.size() - 1]) < 0.05, "musique %s : le début raccorde la fin de la boucle" % pair[0])
		check(absi(a.size() - int(Synth.CHORD_TIME * Synth.ROOTS.size() * Synth.RATE)) <= 1, "musique %s : 12 s" % pair[0])

	print("Musique des régions")
	var styles: Dictionary = RegionAudio.all_music_styles()
	check(styles.has("spore") and styles.has("vent") and styles.has("seve") and styles.has("aube"), "Spore, Vent, Sève et Aube ont une musique propre (data/audio.json)")
	var seen_music: Array = []
	for id in styles:
		var dark := Synth.music_dark(styles[id])
		check(not dark in seen_music, "%s : une couche sombre qui n'est celle d'aucune autre région" % id)
		seen_music.append(dark)
	for id in ["spore", "vent", "seve", "aube", "racine", "finale"]:
		for key in RegionAudio.BOSS_KEYS:
			check(RegionAudio.boss_sound(id, key) != "", "%s : un son de boss « %s »" % [id, key])
	for id in styles:
		for pair in [["sombre", Synth.music_dark(styles[id])], ["lumineux", Synth.music_bright(styles[id])]]:
			var a: PackedFloat32Array = pair[1]
			var pr := _peak_rms(a)
			check(pr[0] > 0.3 and pr[0] <= 0.81, "%s %s : niveau correct (crête %.2f)" % [id, pair[0], pr[0]])
			check(absf(a[0] - a[a.size() - 1]) < 0.05, "%s %s : le début raccorde la fin de la boucle" % [id, pair[0]])
			check(absi(a.size() - int(Synth.CHORD_TIME * Synth.ROOTS.size() * Synth.RATE)) <= 1, "%s %s : 12 s" % [id, pair[0]])
			var f := FileAccess.open(RegionAudio.music_path(id, pair[0]), FileAccess.READ)
			check(f != null and f.get_buffer(f.get_length()) == Synth.to_wav(a), "%s_%s.wav à jour (relancer tools/gen-sounds.sh sinon)" % [id, pair[0]])
		check(Synth.music_dark(styles[id]) != Synth.music_dark(), "%s : une musique différente de celle de Ronce" % id)
	check(Synth.music_dark({}) == Synth.music_dark(), "sans réglage : la musique de Ronce")
	check(RegionAudio.validate().is_empty(), "réglages de son et d'ambiance valides : %s" % [RegionAudio.validate()])

	print("Fichiers du dépôt")
	for name in Synth.SOUNDS:
		var f := FileAccess.open("res://assets/sounds/%s.wav" % name, FileAccess.READ)
		check(f != null and f.get_buffer(f.get_length()) == Synth.to_wav(Synth.render(name)), "%s.wav à jour (relancer tools/gen-sounds.sh sinon)" % name)

	print("Sfx")
	check(not sfx.enabled and not music.enabled, "muet en test (sans écran)")
	sfx.enabled = true
	for name in ["impact", "mort", "clic"]:
		sfx.streams[name] = sfx.get_script().load_wav("res://assets/sounds/%s.wav" % name)
	for i in 6:
		sfx.play("impact")
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
	sfx.enabled = false

	print("Musique")
	music.enabled = true
	music.dark = AudioStreamPlayer.new()
	music.bright = AudioStreamPlayer.new()
	music.add_child(music.dark)
	music.add_child(music.bright)
	music.set_mood(0.0)
	check(music.target == 0.0, "terre morte : cible sombre")
	music.set_mood(0.9)
	check(music.target == 1.0, "prairie : cible lumineuse")
	for i in 5:
		music._process(1.0)
	check(is_equal_approx(music.mix, 1.0) and music.bright.volume_db > -1.0 and music.dark.volume_db <= -60.0, "fondu vers la couche lumineuse")
	music.set_mood(0.38)
	for i in 10:
		music._process(0.1)
	var d: float = db_to_linear(music.dark.volume_db)
	var b: float = db_to_linear(music.bright.volume_db)
	check(absf(d * d + b * b - 1.0) < 0.02, "mélange à puissance constante")
	music.enabled = false

	print("Musique : changement de région")
	music.enabled = true
	music.world_gain = 1.0
	music.mix = 0.0
	music.target = 0.0
	var fake := {"dark": AudioStreamPlayer.new(), "bright": AudioStreamPlayer.new(), "gain": 0.0}
	music.add_child(fake["dark"])
	music.add_child(fake["bright"])
	music.pairs["essai"] = fake
	music.set_mood(0.0, "essai")
	check(music.region == "essai", "la région du joueur est visée")
	for i in 5:
		music._process(1.0)
	check(is_equal_approx(fake["gain"], 1.0) and music.world_gain == 0.0, "fondu vers la musique de la région")
	check(fake["dark"].volume_db > -1.0 and music.dark.volume_db <= -60.0 and fake["bright"].volume_db <= -60.0, "région : couche sombre seule en terre morte, monde coupé")
	music.set_mood(0.0, "")
	for i in 5:
		music._process(1.0)
	check(music.world_gain == 1.0 and fake["dark"].volume_db <= -60.0 and music.dark.volume_db > -1.0, "retour à la musique du monde hors région")
	music.set_mood(0.0, "inconnue")
	check(music.region == "", "région sans piste : musique du monde")
	music.set_mood(0.0, "")
	music.pairs.erase("essai")
	music.enabled = false

	print("Sons : références des données")
	check(SoundRefs.validate().is_empty(), "chaque son nommé dans les données existe : %s" % [SoundRefs.validate()])
	var refs_ok := true
	for id in styles:
		if id == "generique":
			continue  # le générique n'a pas de boss
		for key in RegionAudio.BOSS_KEYS:
			var snd := RegionAudio.boss_sound(id, key)
			refs_ok = refs_ok and snd != "" and Synth.SOUNDS.has(snd)
	check(refs_ok, "Spore et Vent : un son d'éveil, de phase et de mort pour le boss")
	var all_loaded := true
	sfx.enabled = true
	sfx.streams.clear()
	for name in Synth.SOUNDS:
		var st = sfx.get_script().load_wav("res://assets/sounds/%s.wav" % name)
		all_loaded = all_loaded and st != null and st.get_length() > 0.015
	sfx.enabled = false
	check(all_loaded, "tous les sons de synth.gd ont un fichier lisible")

	print("Réglages")
	settings.set_music_volume(0.5)
	settings.set_sfx_volume(0.0)
	var im := AudioServer.get_bus_index("Musique")
	var ie := AudioServer.get_bus_index("Effets")
	check(im >= 0 and ie >= 0, "bus Musique et Effets créés")
	check(absf(AudioServer.get_bus_volume_db(im) - linear_to_db(0.5)) < 0.01, "volume de la musique appliqué")
	check(AudioServer.is_bus_mute(ie), "effets à zéro : bus coupé")
	settings.set_music_volume(0.7)
	settings.set_sfx_volume(0.9)

	print("ÉCHECS : %d" % failures if failures > 0 else "Tout est bon.")
	quit(1 if failures > 0 else 0)
