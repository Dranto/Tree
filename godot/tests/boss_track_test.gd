## Test des musiques de boss faites à la main (scripts/boss_track.gd, assets/music/hand/).
## Un morceau d'essai (tests/fixtures/boss_track/, 240 BPM : une mesure = 1 s, une note par section,
## préparé par tools/boss-track.sh) joue pour de vrai ; la sortie du mélangeur est enregistrée
## (AudioEffectCapture) et l'on retrouve, à l'échantillon près, où chaque section commence :
##   - intro puis boucle_1 sur le temps ; drop au début de la mesure qui suit la phase (±10 ms),
##     boucle suivante juste après le drop ; fin à la mort du boss, puis silence ;
##   - phase 2 pendant l'intro : le drop part quand même à la mesure suivante ;
##   - mort du héros : retour au calme (fondu d'une seconde, pas de section « defaite » ici) ;
##   - combat suivi de l'extérieur (follow) : phases lues sur boss.phase, victoire sur l'état de l'arène ;
##   - boss sans fichier : rien ne joue, la musique du code garde la main ;
##   - le morceau de la Flétrissure (finale) est complet : sections, mesures entières, raccords vérifiés.
## Instants des phases tirés au hasard (graine affichée). Lancer :
##   tools/godot.sh --headless -s res://tests/boss_track_test.gd
extends SceneTree

const BossTrack = preload("res://scripts/boss_track.gd")
const FIXTURES := "res://tests/fixtures/boss_track/"
const BUS := "EssaiBoss" # i18n: non (bus audio de test)
## Notes du morceau d'essai, par section.
const TONES := {"intro": 220.0, "boucle_1": 330.0, "drop_1": 440.0, "boucle_2": 550.0,
	"drop_2": 660.0, "boucle_3": 770.0, "fin": 880.0}
const RATE := 44100
const BAR := 1.0
## Tolérance sur un début de section (s).
const TOL := 0.010

var failures := 0
var rng := RandomNumberGenerator.new()
var capture: AudioEffectCapture
var recorded := PackedVector2Array()
var track


func check(cond: bool, what: String) -> void:
	if cond:
		print("  ok   ", what)
	else:
		failures += 1
		print("  ÉCHEC ", what)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	rng.seed = int(Time.get_unix_time_from_system()) % 100000
	print("Graine : ", rng.seed)
	AudioServer.add_bus()
	var bi := AudioServer.bus_count - 1
	AudioServer.set_bus_name(bi, BUS)
	capture = AudioEffectCapture.new()
	capture.buffer_length = 2.0
	AudioServer.add_bus_effect(bi, capture)
	AudioServer.set_bus_mute(bi, false)
	track = BossTrack.new()
	track.dir = FIXTURES
	root.add_child(track)
	track.player.bus = BUS

	_check_finale_data()
	_check_without_file()
	await _scenario_phases()
	await _scenario_phase_during_intro()
	await _scenario_defeat()
	await _scenario_follow()

	print("boss_track_test : ", "OK" if failures == 0 else "%d ÉCHEC(S)" % failures)
	quit(1 if failures > 0 else 0)


# --- Données ---

func _check_finale_data() -> void:
	print("Morceau de la Flétrissure")
	var d := BossTrack.track_data("finale")
	check(not d.is_empty(), "assets/music/hand/finale.json lu")
	if d.is_empty():
		return
	check(is_equal_approx(float(d["bpm"]), 180.0) and int(d["bar_beats"]) == 4, "180 BPM, 4/4")
	var names := BossTrack.clip_names(d)
	check(names == ["intro", "drop_1", "drop_2", "fin"], "clips : %s" % [names])
	check(d["sections"].keys() == ["intro", "boucle_1", "drop_1", "boucle_2", "drop_2", "boucle_3", "fin"],
		"sections de la fiche : %s" % [d["sections"].keys()])
	var bar_frames := RATE * BossTrack.bar_time(d)
	for n in names:
		var info: Dictionary = d["clips"][n]
		var path := BossTrack.DIR + str(info["fichier"])
		check(ResourceLoader.exists(path), "%s présent" % path)
		if bool(info.get("boucle", false)):
			check(int(info.get("echantillons", -1)) == int(round(int(info["mesures"]) * bar_frames)),
				"%s : %d mesures entières (%d échantillons)" % [n, int(info["mesures"]), int(info.get("echantillons", -1))])
		check(int(info.get("decalage_ech", 1)) == 0, "%s calé sur la source (décalage 0)" % n)
	for n in d["sections"]:
		var info: Dictionary = d["sections"][n]
		if info.has("saut_apres"):
			# Le bouclage ne saute pas plus que le même passage dans l'original (+10 % de marge).
			check(float(info["saut_apres"]) <= float(info["saut_naturel"]) * 1.1 + 0.005,
				"%s se raccorde sans clic (saut %.3f, original %.3f)" % [n, info["saut_apres"], info["saut_naturel"]])
	# Le drop couvre la pause et la transformation du boss (1,5 + 3,6 s) à une mesure près.
	check(BossTrack.section_length(d, "drop_2") >= 5.1 - BossTrack.bar_time(d), "drop_2 assez long pour la transformation")
	var s := BossTrack.build_stream(d)
	check(s != null and s.clip_count == names.size(), "flux interactif construit (%d sections)" % names.size())
	if s != null:
		var ogg: AudioStreamOggVorbis = s.get_clip_stream(0)
		check(ogg.loop and ogg.beat_count == 32 * 4 and is_equal_approx(ogg.bpm, 180.0)
			and is_equal_approx(ogg.loop_offset, 16 * 4 / 3.0), "intro : 128 temps, boucle_1 boucle depuis la mesure 17")


func _check_without_file() -> void:
	print("Boss sans morceau")
	check(not BossTrack.has_track("ronce"), "Ronce n'a pas de morceau (musique du code)")
	check(not track.begin("ronce"), "begin(\"ronce\") ne lance rien")
	check(not track.active(), "le lecteur reste inactif")


# --- Lecture réelle ---

## Lance le morceau d'essai et enregistre la sortie ; renvoie l'échantillon où il commence.
func _start() -> void:
	track.stop()
	await process_frame
	await _drain(0.15)
	capture.clear_buffer()
	recorded = PackedVector2Array()
	track.begin("test")


## Enregistre la sortie pendant « secs » secondes.
func _drain(secs: float) -> void:
	var until := Time.get_ticks_msec() + int(secs * 1000.0)
	while Time.get_ticks_msec() < until:
		await process_frame
		_pull()


func _pull() -> void:
	var n := capture.get_frames_available()
	if n > 0:
		recorded.append_array(capture.get_buffer(n))


## Échantillon enregistré « maintenant » (ce qui est déjà mélangé).
func _now() -> int:
	_pull()
	return recorded.size()


## Énergie d'une note (Goertzel) sur une fenêtre.
func _power(start: int, n: int, f: float) -> float:
	var k := 2.0 * cos(TAU * f / RATE)
	var s1 := 0.0
	var s2 := 0.0
	for i in n:
		var s0: float = recorded[start + i].x + k * s1 - s2
		s2 = s1
		s1 = s0
	return s1 * s1 + s2 * s2 - k * s1 * s2


## Section qui sonne autour d'un échantillon ("" : silence).
func _label(start: int, n := 220) -> String:
	if start < 0 or start + n > recorded.size():
		return "?"
	var best := ""
	var best_p := 0.5
	for name in TONES:
		var p := _power(start, n, TONES[name])
		if p > best_p:
			best_p = p
			best = name
	return best


## Début (échantillon) de la section « name » cherché entre « from » et « to ».
func _onset(name: String, from: int, to: int) -> int:
	var i := maxi(0, from)
	var step := 110
	while i + 220 < mini(to, recorded.size()):
		if _label(i) == name:
			# Affinage à 10 échantillons : premier point où la note domine.
			var j := maxi(0, i - step)
			while j < i and _label(j, 220) != name:
				j += 10
			return j + 110
		i += step
	return -1


func _track_start() -> int:
	for i in recorded.size():
		if absf(recorded[i].x) > 0.002:
			return i
	return -1


## Vérifie qu'une section commence sur la mesure attendue (comptée depuis le début du morceau).
func _expect_bar(name: String, start: int, bar: int, what: String) -> void:
	var want := start + bar * RATE * BAR
	var got := _onset(name, int(want - 0.3 * RATE), int(want + 0.6 * RATE))
	var err := (got - want) / float(RATE) if got >= 0 else 99.0
	check(absf(err) <= TOL, "%s : %s commence à la mesure %d (écart %.1f ms)" % [what, name, bar + 1, err * 1000.0])


## Première mesure entière (comptée depuis le début) après l'échantillon « at ».
func _next_bar(start: int, at: int) -> int:
	return int(ceil(float(at - start) / (RATE * BAR) + 0.0001))


func _scenario_phases() -> void:
	print("Combat : phases au hasard, puis mort du boss")
	await _start()
	var p2 := rng.randf_range(2.2, 4.8)
	await _drain(p2)
	var at2 := _now()
	track.set_phase(2)
	var p3 := rng.randf_range(2.2, 3.8)
	await _drain(p3)
	var at3 := _now()
	track.set_phase(3)
	await _drain(rng.randf_range(2.2, 3.5))
	var atw := _now()
	track.win()
	check(track.state == "fin", "mort du boss : la fin est demandée")
	await _drain(3.2)
	var start := _track_start()
	check(start >= 0, "le morceau joue (sortie enregistrée)")
	if start < 0:
		return
	_expect_bar("intro", start, 0, "éveil")
	_expect_bar("boucle_1", start, 2, "après l'intro")
	# La demande est prise à la mesure qui suit l'instant où elle arrive au mélangeur ; la sortie
	# enregistrée au moment de la demande peut avoir un tampon d'avance : on tolère cette mesure-là.
	var b2 := _next_bar(start, at2)
	var d1 := _onset("drop_1", int(start + (b2 - 1) * RATE - 0.3 * RATE), int(start + (b2 + 1.5) * RATE))
	var bar_d1 := roundi(float(d1 - start) / RATE)
	var err1 := (d1 - start - bar_d1 * RATE) / float(RATE)
	check(d1 >= 0 and absf(err1) <= TOL and bar_d1 >= b2 - 1 and bar_d1 <= b2 + 1 and d1 >= at2 - 0.05 * RATE,
		"phase 2 à %.2f s : drop_1 au début de la mesure %d (écart %.1f ms)" % [float(at2 - start) / RATE, bar_d1 + 1, err1 * 1000.0])
	if d1 >= 0:
		_expect_bar("boucle_2", start, bar_d1 + 1, "après drop_1")
	var b3 := _next_bar(start, at3)
	var d2 := _onset("drop_2", int(start + (b3 - 1) * RATE - 0.3 * RATE), int(start + (b3 + 1.5) * RATE))
	var bar_d2 := roundi(float(d2 - start) / RATE)
	var err2 := (d2 - start - bar_d2 * RATE) / float(RATE)
	check(d2 >= 0 and absf(err2) <= TOL and bar_d2 >= b3 - 1 and bar_d2 <= b3 + 1,
		"phase 3 à %.2f s : drop_2 au début de la mesure %d (écart %.1f ms)" % [float(at3 - start) / RATE, bar_d2 + 1, err2 * 1000.0])
	if d2 >= 0:
		_expect_bar("boucle_3", start, bar_d2 + 1, "après drop_2")
	var bw := _next_bar(start, atw)
	var f := _onset("fin", int(start + (bw - 1) * RATE - 0.3 * RATE), int(start + (bw + 1.5) * RATE))
	var bar_f := roundi(float(f - start) / RATE)
	var errf := (f - start - bar_f * RATE) / float(RATE)
	check(f >= 0 and absf(errf) <= TOL, "mort du boss : fin au début de la mesure %d (écart %.1f ms)" % [bar_f + 1, errf * 1000.0])
	# Après la fin (1 mesure), le morceau se tait.
	if f >= 0:
		var after := f + int(1.2 * RATE)
		check(after + 2000 < recorded.size() and _label(after, 2000) == "", "silence après la fin")
	await _drain(1.2)
	check(not track.active(), "le lecteur rend la main après la fin")
	if "--dump" in OS.get_cmdline_user_args():
		var fd := FileAccess.open("user://boss_track_dump.f32", FileAccess.WRITE)
		for v in recorded:
			fd.store_float(v.x)
		print("dump: ", ProjectSettings.globalize_path("user://boss_track_dump.f32"), " start=", start, " at2=", at2, " at3=", at3, " atw=", atw)


func _scenario_phase_during_intro() -> void:
	print("Phase 2 pendant l'intro")
	await _start()
	await _drain(rng.randf_range(0.2, 1.7))
	var at := _now()
	track.set_phase(2)
	await _drain(2.6)
	var start := _track_start()
	var b := _next_bar(start, at)
	var d := _onset("drop_1", int(start + (b - 1) * RATE - 0.3 * RATE), int(start + (b + 1.5) * RATE))
	var bar_d := roundi(float(d - start) / RATE)
	var err := (d - start - bar_d * RATE) / float(RATE)
	check(d >= 0 and absf(err) <= TOL and bar_d <= 2,
		"demande à %.2f s : drop_1 à la mesure %d, sans attendre la fin de l'intro (écart %.1f ms)" % [float(at - start) / RATE, bar_d + 1, err * 1000.0])
	if d >= 0:
		_expect_bar("boucle_2", start, bar_d + 1, "après drop_1")


func _scenario_defeat() -> void:
	print("Mort du héros : retour au calme")
	await _start()
	await _drain(2.5)
	track.lose()
	check(track.state == "fondu", "sans « defaite » : fondu de sortie")
	await _drain(1.4)
	check(not track.active() and not track.player.playing, "le morceau s'est tu en une seconde")
	var tail := recorded.size() - 4000
	check(tail > 0 and _label(tail, 2000) == "", "silence ensuite")


## Arène et boss factices : le lecteur ne lit que region, state, in_combat(), boss.phase et boss.dead.
class FakeBoss:
	extends RefCounted
	var phase := 1
	var dead := false


class FakeArena:
	extends Node
	var region := "test"
	var state := "combat"
	var boss = FakeBoss.new()

	func in_combat() -> bool:
		return state == "combat"


func _scenario_follow() -> void:
	print("Combat suivi de l'extérieur (follow)")
	track.stop()
	await _drain(0.2)
	var a := FakeArena.new()
	root.add_child(a)
	track.follow(a)
	check(track.active() and track.boss_id == "test", "arène en combat : le morceau démarre")
	a.boss.phase = 2
	track.follow(a)
	check(track.phase == 2 and track.requests.back()["clip"] == "drop_1", "boss.phase 2 : drop_1 demandé")
	a.boss.phase = 3
	track.follow(a)
	check(track.requests.back()["clip"] == "drop_2", "boss.phase 3 : drop_2 demandé")
	a.boss.dead = true
	a.state = "vaincue"
	track.follow(null)
	check(track.state == "fin", "arène vaincue : la fin")
	# Combat perdu (l'arène se rouvre) : fondu.
	track.stop()
	a.state = "combat"
	a.boss = FakeBoss.new()
	track.follow(a)
	a.state = "ouverte"
	track.follow(null)
	check(track.state == "fondu", "arène rouverte (héros mort) : fondu")
	# Retour au menu : l'arène disparaît avec la scène.
	track.stop()
	a.state = "combat"
	track.follow(a)
	a.free()
	await _drain(0.1)
	check(track.state == "fondu", "arène libérée (retour au menu) : fondu")
	await _drain(1.2)
	check(not track.active(), "puis plus rien ne joue")
