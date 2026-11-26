## Enregistre les atlas cuits d'un boss (boss_bake.gd) : tools/godot.sh --xvfb -s res://tests/bestiaire/boss/atlas.gd -- DOSSIER ronce/_mere_ronce
extends SceneTree

const BossBake = preload("res://scripts/boss_bake.gd")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var art = load("res://scripts/creature_art/%s.gd" % args[1])
	var host := Node2D.new()
	root.add_child(host)
	var a = await BossBake.wait(host, art)
	for g in a.groups:
		var img: Image = a.groups[g].tex.get_image()
		img.save_png("%s/%s.png" % [args[0], g])
		print("ATLAS ", g, " ", img.get_size())
	quit(0)
