## Génère tous les sons du jeu dans godot/assets/sounds/ et godot/assets/music/.
## Lancer : tools/gen-sounds.sh
## Les formules sont dans scripts/synth.gd : modifier un réglage, relancer, réécouter.
extends SceneTree

const Synth = preload("res://scripts/synth.gd")


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/sounds"))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/music"))
	var total := 0
	for name in Synth.SOUNDS:
		total += _save("res://assets/sounds/%s.wav" % name, Synth.render(name))
	total += _save("res://assets/music/sombre.wav", Synth.music_dark())
	total += _save("res://assets/music/lumineux.wav", Synth.music_bright())
	print("GEN %d sons + 2 pistes, %d Ko" % [Synth.SOUNDS.size(), total / 1024])
	quit()


func _save(path: String, samples: PackedFloat32Array) -> int:
	var bytes := Synth.to_wav(samples)
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		printerr("GEN impossible d'écrire ", path)
		return 0
	f.store_buffer(bytes)
	return bytes.size()
