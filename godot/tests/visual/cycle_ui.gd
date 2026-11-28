## Scénario « cycle_ui » du banc visuel (runner.gd ; New Game+, jalon 14 S) : lisibilité de l'interface du
## New Game+ en anglais (les textes les plus longs), à 1280 x 800 (Steam Deck : texte « Grande », manette) et
## 3440 x 1440. Le fruit de la graine (anneau à moitié rempli), l'annonce « Exaltation » d'un boss au cycle 3,
## la couronne ouverte à ses 20 emplacements dans l'arbre, puis le titre : « niveau N · cycle C » sous « Continuer ».
## Le jeu est figé ; la sauvegarde écrite pour le titre est supprimée ensuite.
extends RefCounted

const TitleScene = preload("res://scenes/title.tscn")
const Content = preload("res://scripts/content.gd")

var r
var main


func run(runner) -> void:
	r = runner
	main = r.main
	var tag: String = r._res_tag()
	var deck := tag == "1280x800"
	if deck:
		Settings.set_text_scale(Settings.DECK_TEXT_SCALE)
		Settings.set_pad_style("xbox")
		Settings.set_device("manette")
	main.autotest = false
	main.spawn_timer = 1.0e9
	main.spawn_paused = true
	main.player.set_physics_process(false)
	main.hud.glyphs.hide()
	# Troisième cycle, aventure finie, couronne pleine (plafond de data/crown.json).
	Game.cycle = 3
	Game.level = 31
	Game.crown_kept = int(Content.crown().get("max", 20))
	Game._fit_crown()
	Game.flags[Objectives.ENDING_SEEN] = true
	Game.flags["finale_vaincue"] = true
	await r._frames(60)
	main.hud.banner_time = 0.0
	# Le fruit, tenu à moitié.
	var fruit = main.cycle_fruit
	await r._place_player(fruit.position + Vector2(-30, 40))
	fruit.grown = 1.0
	fruit.progress = fruit.HOLD * 0.5
	fruit.queue_redraw()
	await r._frames(20)
	await r._shot("cycle_ui_fruit_" + tag, "jeu")
	# Annonce de la phase exaltée d'un boss : le texte flottant et la bannière du jeu.
	var at: Vector2 = main.player.position + Vector2(0, -160)
	main.fx.text(at, Loc.t("Exaltation"), Art.ec("saignement", "clair"), 26, 4.0)
	main.fx.ring(at, 40.0, 260.0, 4.0, Color(Art.ec("saignement", "clair"), 0.9), 10.0)
	await r._frames(25)
	await r._shot("cycle_ui_exaltation_" + tag, "jeu")
	# Couronne à 20 emplacements.
	var ids: Array = Content.grafts().keys()
	ids.sort()
	for g in ids.slice(0, 20):
		Game.give_graft(g)
	for i in 20:
		Game.place_graft(i, ids[i % ids.size()])
	main.tree_ui.toggle()
	if deck:
		main.tree_ui.pad.set_zone("couronne")
		main.tree_ui.pad.crown_index = 19
		main.tree_ui.pad._crown_show()
	await r._frames(10)
	main.tree_ui.queue_redraw()
	await r._frames(2)
	main.tree_ui.queue_redraw()
	await r._frames(2)
	await r._shot("cycle_ui_couronne_" + tag, "arbre")
	main.tree_ui.toggle()
	await r._frames(2)
	# Titre : « niveau N · cycle C » (· fin) sous « Continuer ».
	SaveGame.save_now(main)
	main.queue_free()
	get_tree_unpause()
	await r._frames(2)
	var title = TitleScene.instantiate()
	r.add_child(title)
	await r._frames(30)
	UiAudit.scan_controls("titre", title)
	await r._shot("cycle_ui_titre_" + tag, "titre")
	SaveGame.delete_save()


func get_tree_unpause() -> void:
	r.get_tree().paused = false
