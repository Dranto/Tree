## Test de la gamme de la zone (harmony.gd) : chaque région déclare une gamme qui colle à ses accords ; tout
## bruitage qui a des notes, joué dans n'importe quelle zone et sur n'importe lequel de ses huit accords (ou
## sur un morceau de boss fait à la main), n'a plus aucune note hors de la gamme ni de l'accord ; les variantes
## sont ramenées sur la note juste ; les nappes d'ambiance tintent dans la gamme ; la musique d'une région
## s'éteint avant que celle de la suivante monte, et une frontière longée ne fait pas hésiter la musique.
## Lancer : tools/godot.sh --headless -s res://tests/harmony_test.gd
extends SceneTree

const Synth = preload("res://scripts/synth.gd")
const MusicSynth = preload("res://scripts/music_synth.gd")
const RegionAudio = preload("res://scripts/region_audio.gd")
const Harmony = preload("res://scripts/harmony.gd")
const RegionsScript = preload("res://scripts/regions.gd")

## Plus grande transposition admise (demi-tons) : au-delà, le son change trop de durée et de timbre.
const MAX_SHIFT := 6
var failures := 0


func check(cond: bool, what: String) -> void:
	if cond:
		print("  ok   ", what)
	else:
		failures += 1
		print("  ÉCHEC ", what)


func _initialize() -> void:
	_run.call_deferred()


## Sons en faute, sans doublons.
func _names(cases: Array) -> Array:
	var out: Array = []
	for c in cases:
		var n := str(c).get_slice(" sur ", 0)
		if not n in out:
			out.append(n)
	return out


func _zones() -> Array:
	return [""] + RegionAudio.all_music_styles().keys()


func _run() -> void:
	print("Gammes des zones")
	var hands := 0
	for id in _zones():
		var h := Harmony.region(id)
		var name := "ronce" if id == "" else str(id)
		check(Harmony.MODES.has(h["mode"]), "%s : mode connu (%s)" % [name, h["mode"]])
		check(int(h["chords"][0][0]) == int(h["tonic"]), "%s : le premier accord est sur la tonique (%s)" % [name, Harmony.pc_name(h["tonic"])])
		var inside := 0
		var total := 0
		for ch in h["chords"]:
			for k in 3:
				total += 1
				if int(ch[k]) in h["scale"]:
					inside += 1
		check(inside >= int(total * 0.85), "%s : la gamme colle aux accords (%d notes sur %d)" % [name, inside, total])
		var ht := Harmony.hand_track("ronce" if id == "" else id)
		if not RegionAudio.of("ronce" if id == "" else id).get("hand_track", {}).is_empty():
			hands += 1
			check(not ht.is_empty(), "%s : gamme du morceau fait à la main lisible" % name)
	check(hands >= 2, "les morceaux faits à la main (Mère-Ronce, Flétrissure) ont une gamme")
	var bc := Harmony.hand_track("finale")
	check(bc.get("scale", []).size() == 7 and not 10 in bc["scale"], "breakcore : notes blanches, pas de si bémol")
	var mr := Harmony.hand_track("ronce")
	check(mr.get("tonic", -1) == 9 and mr.get("mode", "") == "eolien", "Mère-Ronce : la mineur")

	print("Bruitages accordés")
	var tonal := 0
	var worst := 0
	var bad: Array = []
	var contexts: Array = []
	for id in _zones():
		var h := Harmony.region(id)
		for c in MusicSynth.CHORDS:
			contexts.append([("ronce" if id == "" else id) + " accord %d" % (c + 1), Harmony.context(h, c * MusicSynth.CHORD_TIME + 0.1)])
	for id in ["ronce", "finale"]:
		contexts.append([id + " (morceau fait à la main)", Harmony.context(Harmony.hand_track(id))])
	for name in Synth.SOUNDS:
		var notes := Harmony.notes_of(name)
		if notes.is_empty():
			continue
		tonal += 1
		for ctx in contexts:
			var s := Harmony.best_shift(notes, ctx[1])
			worst = maxi(worst, absi(s))
			for n in notes:
				var pc := posmod(int(roundf(float(n[0]))) + s, 12)
				if not pc in ctx[1]["scale"] and not pc in ctx[1]["chord"]:
					bad.append("%s sur %s (%s)" % [name, ctx[0], Harmony.pc_name(pc)])
					if OS.has_environment("HARMONY_DEBUG"): print("    ", name, " ", ctx[0], " décalage ", s, " ", Harmony.pc_name(pc))
					break
	check(tonal >= 60, "les bruitages qui ont des notes sont repérés (%d)" % tonal)
	check(not Harmony.is_tonal("tir") and not Harmony.is_tonal("esquive"), "bruits et peaux : aucune note, pas de transposition")
	check(Harmony.is_tonal("critique") and Harmony.is_tonal("fouet") and Harmony.is_tonal("niveau"), "pizz, marimba, cordes : des notes")
	check(bad.is_empty(), "aucune note hors de la gamme ni de l'accord, dans toutes les zones et sur tous les accords" +
		("" if bad.is_empty() else " : %d cas, sons %s" % [bad.size(), ", ".join(_names(bad))]))
	check(worst <= MAX_SHIFT, "transposition d'au plus %d demi-tons (%d)" % [MAX_SHIFT, worst])

	var ronce := Harmony.context(Harmony.region(""), 0.1)
	check(absf(Harmony.pitch_for("critique", ronce) - 1.0) < 0.001, "un son en ré mineur dans Ronce, sur ré mineur : joué tel quel")
	var p1 := Harmony.pitch_for("critique", ronce, 1)
	check(absf(p1 * (1.0 + Harmony.VARIANT_PITCH[1]) - Harmony.pitch_for("critique", ronce)) < 0.0001, "une variante rendue plus grave est ramenée sur la note juste")
	var aube := Harmony.context(Harmony.region("aube"), 0.1)
	var pa := Harmony.pitch_for("critique", aube)
	var shift := 12.0 * log(pa) / log(2.0)
	check(absf(shift - roundf(shift)) < 0.01 and roundi(shift) != 0, "le même son dans l'Aube (la lydien) : transposé d'un nombre entier de demi-tons (%+d)" % roundi(shift))
	check(Harmony.pitch_for("tir", aube, 0, 1.2) == 1.2, "un son sans note garde la hauteur demandée")
	var prev := 0.0
	var climbs := true
	for k in 11:
		var p := Harmony.pitch_for("ramasse", ronce, 0, 1.0 + 0.045 * k)
		climbs = climbs and p >= prev - 0.0001
		prev = p
		var n := posmod(int(roundf(Harmony.midi(146.8) + 12.0 * log(p) / log(2.0))), 12)
		climbs = climbs and (n in ronce["scale"] or n in ronce["chord"])
	check(climbs, "ramassages enchaînés : la hauteur monte, note après note, dans la gamme")

	print("Nappes d'ambiance")
	var beds := RegionAudio.all_beds()
	beds[""] = MusicSynth.BED_DEFAULTS
	var bed_bad: Array = []
	for id in beds:
		var h := Harmony.region(id if RegionAudio.music_style(id).size() > 0 else "")
		for state in ["dead", "alive"]:
			for ev in beds[id].get(state, {}).get("events", []):
				var kind := str(ev.get("kind", ""))
				if kind == "chime" and not ev.has("f0"):
					bed_bad.append("%s › %s : carillon au hasard" % [id, state])
				if kind in ["note", "chime"] and ev.has("f0"):
					for n in ev.get("notes", [0]):
						if not posmod(roundi(Harmony.midi(float(ev["f0"]))) + int(n), 12) in h["scale"]:
							bed_bad.append("%s › %s › %s" % [id, state, kind])
	check(bed_bad.is_empty(), "notes et carillons des nappes dans la gamme de leur zone" + ("" if bed_bad.is_empty() else " : " + ", ".join(bed_bad)))

	print("Musique : changement de région et frontières")
	var music = root.get_node("Music")
	var sfx = root.get_node("Sfx")
	var was_enabled: bool = music.enabled
	music.enabled = true
	music.started = true
	music.groups = {"": {"players": {}, "gain": 1.0}, "spore": {"players": {}, "gain": 0.0}}
	music.beds = {}
	music.region = ""
	music._pending = ""
	music.region = "spore"
	var overlap := 0.0
	for i in 60:
		music._process(0.05)
		overlap = maxf(overlap, minf(sin(music.groups[""]["gain"] * PI / 2.0), sin(music.groups["spore"]["gain"] * PI / 2.0)))
	check(music.groups["spore"]["gain"] >= 0.99 and music.groups[""]["gain"] == 0.0, "vers la région : la nouvelle musique finit seule")
	check(overlap < 0.2, "les deux gammes ne s'entendent presque jamais ensemble (au plus %.2f)" % overlap)
	check(music.heard_region() == "spore", "on entend la région où l'on est")
	var ctx: Dictionary = music.harmony()
	check(ctx["scale"] == Harmony.region("spore")["scale"], "les bruitages suivent la gamme de la musique entendue")
	var sp: float = sfx.pitch_of("critique")
	var sn := posmod(roundi(Harmony.midi(146.8) + 12.0 * log(sp) / log(2.0)), 12)
	check(sn in ctx["scale"] or sn in ctx["chord"], "Sfx : un critique joué dans le marais tombe dans fa# phrygien")
	# Une frontière longée : le jeu dit tour à tour une région et l'autre, la musique ne bouge pas.
	music._pending = "spore"
	var flips := 0
	for i in 40:
		music.set_mood(0.0, "" if i % 6 < 3 else "spore")
		if music.region != "spore":
			flips += 1
		music._process(0.05)
	check(flips == 0, "frontière longée : la musique reste sur sa région (aucun va-et-vient)")
	# Combat de boss : l'ambiance sonore se tait tout à fait.
	var bed_players := {}
	for st in ["mort", "vif"]:
		bed_players[st] = AudioStreamPlayer.new()
		music.add_child(bed_players[st])
	music.beds = {"": {"players": bed_players, "gain": 1.0}}
	music.bed_region = ""
	music.set_boss(true)
	for i in 30:
		music._process(0.1)
	check(bed_players["mort"].volume_db <= -60.0 and bed_players["vif"].volume_db <= -60.0, "combat de boss : plus aucune ambiance, la musique du boss et les bruitages seuls")
	music.set_boss(false)
	for i in 30:
		music._process(0.1)
	check(bed_players["mort"].volume_db > -60.0 or bed_players["vif"].volume_db > -60.0, "après le combat, l'ambiance revient")
	music.beds = {}
	for st in bed_players:
		bed_players[st].free()
	# Approche de la Mère-Ronce (la mineur) dans Ronce (ré mineur) : le monde se tait vite, puis les
	# bruitages passent sur la gamme du morceau.
	var stub := GDScript.new()
	stub.source_code = "extends Node\nvar boss_id := \"ronce\"\nvar lvl := 0.0\nfunc active() -> bool:\n\treturn true\nfunc level() -> float:\n\treturn lvl\nfunc stop() -> void:\n\tpass\nfunc follow(_a) -> void:\n\tpass\n"
	stub.reload()
	var fake_hand: Node = stub.new()
	var old_hand = music.hand
	music.hand = fake_hand
	music.region = ""
	music.groups = {"": {"players": {}, "gain": 1.0}}
	check(not music.hand_in_key(), "Mère-Ronce (la mineur) dans Ronce (ré mineur) : gammes différentes")
	music.hand_k = 0.2
	var world_k: float = cos(clampf(music.hand_k / music._world_out(), 0.0, 1.0) * PI / 2.0)
	check(world_k < 0.01, "à l'approche, la musique du monde s'est tue dès que le morceau monte (%.2f)" % world_k)
	check(music.harmony()["scale"] == Harmony.hand_track("ronce")["scale"], "à l'approche : les bruitages suivent la gamme du morceau")
	music.hand_k = 0.02
	check(music.harmony()["scale"] == Harmony.region("")["scale"], "morceau encore à peine audible : la gamme de la région")
	music.hand = old_hand
	fake_hand.free()
	music.hand_k = 0.0
	music.groups = {}
	music.region = ""
	music.started = false
	music.enabled = was_enabled

	print("")
	if failures == 0:
		print("HARMONY OK")
	else:
		print("HARMONY ÉCHEC : %d" % failures)
	quit(1 if failures > 0 else 0)
