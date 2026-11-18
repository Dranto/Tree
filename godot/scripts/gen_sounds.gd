## Génère tous les sons du jeu dans godot/assets/sounds/ et godot/assets/music/.
## Lancer : tools/gen-sounds.sh
## Les formules sont dans scripts/synth.gd : modifier un réglage, relancer, réécouter.
extends SceneTree

const Synth = preload("res://scripts/synth.gd")
const RegionAudio = preload("res://scripts/region_audio.gd")


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/sounds"))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/music"))
	var total := 0
	for name in Synth.SOUNDS:
		total += _save("res://assets/sounds/%s.wav" % name, Synth.render(name))
	total += _save("res://assets/music/sombre.wav", Synth.music_dark())
	total += _save("res://assets/music/lumineux.wav", Synth.music_bright())
	# Musique propre à chaque région qui en règle une (data/audio.json, section « audio » des régions).
	var styles: Dictionary = RegionAudio.all_music_styles()
	for id in styles:
		for file in RegionAudio.LAYERS:
			var samples: PackedFloat32Array = Synth.music_dark(styles[id]) if file == "sombre" else Synth.music_bright(styles[id])
			total += _save(RegionAudio.music_path(id, file), samples)
	print("GEN %d sons + %d pistes, %d Ko" % [Synth.SOUNDS.size(), 2 + 2 * styles.size(), total / 1024])
	quit()


func _save(path: String, samples: PackedFloat32Array) -> int:
	var bytes := Synth.to_wav(samples)
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		printerr("GEN impossible d'écrire ", path)
		return 0
	f.store_buffer(bytes)
	return bytes.size()
