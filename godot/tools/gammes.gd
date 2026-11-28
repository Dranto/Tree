## Inventaire des gammes : gamme et accords de chaque région, morceaux de boss faits à la main, bruitages qui
## ont des notes (et leur transposition dans chaque région), notes des nappes d'ambiance.
## Lancer : tools/godot.sh --headless -s res://tools/gammes.gd  (ou tools/gammes.sh)
extends SceneTree

const Synth = preload("res://scripts/synth.gd")
const MusicSynth = preload("res://scripts/music_synth.gd")
const RegionAudio = preload("res://scripts/region_audio.gd")
const Harmony = preload("res://scripts/harmony.gd")


func _initialize() -> void:
	var zones := [""] + RegionAudio.all_music_styles().keys()
	print("# Gammes des zones\n")
	for id in zones:
		var h := Harmony.region(id)
		var chords := []
		for ch in h["chords"]:
			chords.append(_names(ch))
		print("- %s : %s %s (%s) ; accords : %s" % [_zone(id), Harmony.pc_name(h["tonic"]), h["mode"],
			_names(h["scale"]), " | ".join(chords)])
		var hand := Harmony.hand_track(id if id != "" else "ronce")
		if not hand.is_empty():
			print("    morceau fait à la main : %s %s (%s)" % [Harmony.pc_name(hand["tonic"]), hand["mode"], _names(hand["scale"])])
	print("\n# Bruitages avec des notes\n")
	var tonal := 0
	for name in Synth.SOUNDS:
		var notes := Harmony.notes_of(name)
		if notes.is_empty():
			continue
		tonal += 1
		var pcs := []
		for n in notes:
			pcs.append(posmod(int(roundf(float(n[0]))), 12))
		var line := "- %s : %s (écart %+d cents)" % [name, _names(pcs), int(roundf(Harmony.detune_of(notes) * 100.0))]
		var shifts := []
		for id in zones:
			var h := Harmony.region(id)
			var raw := Harmony.out_of_scale(notes, 0, h["scale"])
			var s := Harmony.best_shift(notes, Harmony.context(h, 0.0))
			shifts.append("%s %s%+d%s" % [_zone(id), "✗%d " % raw if raw > 0 else "", s,
				" ✗%d" % Harmony.out_of_scale(notes, s, h["scale"]) if Harmony.out_of_scale(notes, s, h["scale"]) > 0 else ""])
		print(line)
		print("    " + ", ".join(shifts))
	print("\n%d bruitages sur %d ont des notes ; les autres (bruits, peaux, glissés) ne sont pas transposés." % [tonal, Synth.SOUNDS.size()])
	print("\n# Notes des nappes d'ambiance\n")
	var beds := RegionAudio.all_beds()
	beds[""] = MusicSynth.BED_DEFAULTS
	for id in beds:
		var h := Harmony.region(id if RegionAudio.music_style(id).size() > 0 else "")
		for state in ["dead", "alive"]:
			for ev in beds[id].get(state, {}).get("events", []):
				if str(ev.get("kind", "")) in ["note", "chime"]:
					var pcs := []
					for n in ev.get("notes", []):
						pcs.append(posmod(int(roundf(Harmony.midi(float(ev.get("f0", 220.0))))) + int(n), 12))
					var bad := pcs.filter(func(p): return not p in h["scale"])
					print("- %s › %s › %s : %s%s" % [_zone(id), state, ev["kind"], _names(pcs) if not pcs.is_empty() else "hauteur au hasard",
						"  ✗ hors gamme : " + _names(bad) if not bad.is_empty() else ""])
	quit(0)


func _zone(id: String) -> String:
	return "ronce" if id == "" else id


func _names(pcs: Array) -> String:
	var out := []
	for p in pcs:
		out.append(Harmony.pc_name(int(p)))
	return " ".join(out)
