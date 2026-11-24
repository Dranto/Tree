## Génère tous les sons du jeu : bruitages (godot/assets/sounds/), musique en couches (godot/assets/music/)
## et nappes d'ambiance (godot/assets/ambience/). Lancer : tools/gen-sounds.sh
## Les formules sont dans scripts/synth.gd (bruitages) et scripts/music_synth.gd (musique, ambiance) ; les
## réglages des régions dans data/audio.json. Modifier, relancer, réécouter.
## Les pistes sont calculées en parallèle (une par cœur) ; empreintes.json garde l'empreinte de chaque
## piste, que sound_test compare aux réglages (pour savoir sans tout recalculer si une piste est périmée).
extends SceneTree

const Synth = preload("res://scripts/synth.gd")
const MusicSynth = preload("res://scripts/music_synth.gd")
const RegionAudio = preload("res://scripts/region_audio.gd")
const MANIFEST := "res://assets/music/empreintes.json"

var jobs: Array = []
var sizes := PackedInt64Array()


func _initialize() -> void:
	for dir in ["res://assets/sounds", "res://assets/music", "res://assets/ambience"]:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	for name in Synth.SOUNDS:
		var names := Synth.variant_names(name)
		for v in names.size():
			jobs.append({"kind": "sfx", "name": name, "variant": v, "path": "res://assets/sounds/%s.wav" % names[v]})
	var manifest := {"version": MusicSynth.VERSION, "music": {}, "beds": {}}
	var styles := {"": {}}
	styles.merge(RegionAudio.all_music_styles())
	for id in styles:
		for layer in RegionAudio.music_layers(styles[id]):
			var path := RegionAudio.music_path(id, layer)
			jobs.append({"kind": "music", "layer": layer, "style": styles[id], "path": path})
			manifest["music"][path] = MusicSynth.fingerprint(layer, styles[id])
	var beds := {"": {}}
	beds.merge(RegionAudio.all_beds())
	for id in beds:
		for file in RegionAudio.BED_STATES:
			var path := RegionAudio.bed_path(id, file)
			jobs.append({"kind": "bed", "state": RegionAudio.BED_STATES[file], "bed": beds[id], "path": path})
			manifest["beds"][path] = MusicSynth.bed_fingerprint(RegionAudio.BED_STATES[file], beds[id])
	sizes.resize(jobs.size())
	var t0 := Time.get_ticks_msec()
	var task := WorkerThreadPool.add_group_task(_run_job, jobs.size(), -1, true)
	WorkerThreadPool.wait_for_group_task_completion(task)
	# Fichiers d'une génération précédente qui ne servent plus (son renommé, couche retirée) : supprimés.
	var written := {}
	for j in jobs:
		written[j["path"]] = true
	var removed := 0
	for dir in ["res://assets/sounds/", "res://assets/music/", "res://assets/ambience/"]:
		for file in DirAccess.get_files_at(dir):
			if file.ends_with(".wav") and not written.has(dir + file):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(dir + file))
				removed += 1
	if removed > 0:
		print("GEN %d fichiers périmés supprimés" % removed)
	var f := FileAccess.open(MANIFEST, FileAccess.WRITE)
	f.store_string(JSON.stringify(manifest, "\t", true) + "\n")
	var total := 0
	for s in sizes:
		total += s
	print("GEN %d fichiers (%d bruitages, %d pistes, %d nappes), %d Ko, %.1f s" % [jobs.size(), jobs.filter(func(j): return j["kind"] == "sfx").size(),
		manifest["music"].size(), manifest["beds"].size(), total / 1024, (Time.get_ticks_msec() - t0) / 1000.0])
	quit()


func _run_job(i: int) -> void:
	var j: Dictionary = jobs[i]
	var samples: PackedFloat32Array
	match j["kind"]:
		"sfx":
			samples = Synth.render(j["name"], j["variant"])
		"music":
			samples = Synth.music_layer(j["layer"], j["style"])
		_:
			samples = Synth.ambience_bed(j["state"], j["bed"])
	var bytes := Synth.to_wav(samples)
	var f := FileAccess.open(j["path"], FileAccess.WRITE)
	if f == null:
		printerr("GEN impossible d'écrire ", j["path"])
		return
	f.store_buffer(bytes)
	sizes[i] = bytes.size()
