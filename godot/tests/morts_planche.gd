## Planche animée des morts de Flétris (jalon Éclat B) : chaque mort élémentaire, la surpuissance
## et l'élite, image par image, pour assembler un GIF (tools/eclat-morts.sh). Rien n'est comparé.
## --avant : toutes les morts en « cendre » (la mort d'avant le jalon Éclat B).
## Lancer : tools/godot.sh --xvfb --audio-driver Dummy --resolution 1280x720 -s res://tests/morts_planche.gd -- --out=DOSSIER [--avant]
extends SceneTree

## Chargé à l'exécution : un script -s ne précharge pas un script qui nomme un autoload.
var Remains
const FRAMES := 54
const STEP := 1.0 / 30.0

## [façon, sorte, élite, surpuissance, région]
const CASES := [
	["venin", "fletri", false, 0.0, ""], ["sang", "fletri", false, 0.0, ""], ["tranche", "fletri", false, 0.0, ""],
	["vent", "fletri", false, 0.0, ""], ["aube", "fletri", false, 0.0, ""], ["racine", "fletri", false, 0.0, ""],
	["seve", "fletri", false, 0.0, ""], ["sang", "colosse", false, 1.0, ""], ["tranche", "chargeur", false, 1.0, ""],
	["sang", "gardien", true, 0.0, "ronce"], ["venin", "boursoufle", true, 0.0, "spore"], ["racine", "colosse", true, 0.0, "racine"],
]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	Remains = load("res://scripts/enemy_remains.gd")
	var out := "user://morts"
	var before := false
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.get_slice("=", 1)
		elif a == "--avant":
			before = true
	DirAccess.make_dir_recursive_absolute(out)
	var bg := ColorRect.new()
	bg.color = Color("5d6b45")
	bg.size = Vector2(4000, 3000)
	root.add_child(bg)
	var holder := Node2D.new()
	root.add_child(holder)
	var list: Array = []
	for i in CASES.size():
		var c: Array = CASES[i]
		var r = Remains.new()
		r.style = "cendre" if before else c[0]
		r.kind_id = c[1]
		r.elite = c[2]
		r.power = c[3]
		r.region = c[4]
		r.radius = 22.0 if c[1] in ["colosse", "gardien", "boursoufle"] else 15.0
		r.dir = Vector2(1, -0.25).normalized()
		r.color = Remains.FletriArt.body_color(c[1])
		r.position = Vector2(200 + (i % 4) * 400, 150 + int(i / 4) * 300)
		r.scale = Vector2(2.2, 2.2)
		holder.add_child(r)
		r.set_process(false)
		list.append(r)
	for f in FRAMES:
		var time := f * STEP - 0.1   # quelques images avant la mort : le Flétri entier
		for r in list:
			r.t = maxf(time, 0.0)
			r.visible = true
			r.queue_redraw()
		if time < 0.0:
			for r in list:
				r.visible = false
		await process_frame
		await process_frame
		var img := root.get_texture().get_image()
		img.save_png("%s/%03d.png" % [out, f])
	quit(0)
