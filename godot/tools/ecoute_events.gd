## Rend à part, pour la page d'écoute (tools/ecoute.sh), ce que les nappes d'ambiance mélangent :
## chaque événement d'ambiance seul (oiseau, goutte, grenouille…, 3 tirages) et chaque nappe continue
## sans ses événements (vent, ruisseau, vagues…). N'écrit rien dans le jeu : le dossier de sortie est
## donné après « -- », en chemin absolu. Lancer : tools/godot.sh --headless -s res://tools/ecoute_events.gd -- /chemin
extends SceneTree

const Synth = preload("res://scripts/synth.gd")
const MusicSynth = preload("res://scripts/music_synth.gd")
const Dsp = preload("res://scripts/synth_dsp.gd")
const RegionAudio = preload("res://scripts/region_audio.gd")

const TAKES := 3
const LENGTH := 4.0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		printerr("ECOUTE dossier de sortie manquant (après « -- »)")
		quit(1)
		return
	var dir: String = args[0]
	DirAccess.make_dir_recursive_absolute(dir)
	var n := 0
	for kind in MusicSynth.BED_EVENTS:
		for take in TAKES:
			var out := PackedFloat32Array()
			out.resize(int(LENGTH * Dsp.RATE))
			var rng := RandomNumberGenerator.new()
			rng.seed = hash(kind) + take * 7919
			MusicSynth._event(out, kind, 0.15, 0.6, rng)
			_write("%s/ev_%s_%d.wav" % [dir, kind, take + 1], Dsp.normalize(out, 0.7))
			n += 1
	var beds := {"ronce": {}}
	beds.merge(RegionAudio.all_beds())
	for id in beds:
		for file in RegionAudio.BED_STATES:
			var bed: Dictionary = beds[id].duplicate(true)
			var state: String = RegionAudio.BED_STATES[file]
			var sec = bed.get(state, {})
			if not (sec is Dictionary):
				sec = {}
			sec["events"] = []
			bed[state] = sec
			_write("%s/fond_%s_%s.wav" % [dir, id, file], MusicSynth.render_bed(state, bed))
			n += 1
	print("ECOUTE %d fichiers dans %s" % [n, dir])
	quit()


func _write(path: String, samples: PackedFloat32Array) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		printerr("ECOUTE impossible d'écrire ", path)
		return
	f.store_buffer(Synth.to_wav(samples))
