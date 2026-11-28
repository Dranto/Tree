## Scénario « textes » du banc visuel (runner.gd ; jalon 14.5 T) : les mots-clés colorés de la fiche de
## greffe de l'écran de l'arbre (dégâts, poison, vie, vitesse, critique, saignement, défense, recharge),
## en français (« textes ») et en anglais (« textes_en »), à 1280 x 720 et 3440 x 1440. Chaque écran est
## pris deux fois : couleurs seules, puis avec un mode daltonien (couleurs plus tranchées et glyphes).
## Le jeu est figé ; aucune sauvegarde n'est écrite.
extends RefCounted

const Content = preload("res://scripts/content.gd")

var r
var main


## Greffes choisies pour leurs effets : plusieurs catégories de mots-clés dans la même fiche.
const GRAFTS := ["greffe_soeurs", "greffe_seve_amere", "greffe_ecorce_dure"]


func run(runner) -> void:
	r = runner
	main = r.main
	var tag: String = r._res_tag()
	var lang := "en" if r.scenario == "textes_en" else "fr"
	main.autotest = false
	main.spawn_timer = 1.0e9
	main.spawn_paused = true
	main.player.set_physics_process(false)
	main.hud.glyphs.hide()
	Game.level = 12
	var ids: Array = []
	for g in GRAFTS:
		if Content.grafts().has(g):
			ids.append(g)
	# Complète avec des greffes dont les effets portent des statistiques, jusqu'à trois.
	var all: Array = Content.grafts().keys()
	all.sort()
	for g in all:
		if ids.size() >= 3:
			break
		if not ids.has(g) and not Content.grafts()[g].get("min_cycle", 0):
			ids.append(g)
	for g in ids:
		Game.give_graft(g)
	Game._fit_crown()
	main.tree_ui.toggle()
	await r._frames(10)
	var gp = main.tree_ui.grafts_panel
	# Fiche d'une greffe posée (survol de son emplacement) : effets puis statistiques retirées.
	Game.place_graft(0, ids[0])
	gp.set_hover_slot(0)
	await _settle()
	await r._shot("textes_%s_fiche_%s" % [lang, tag], "arbre")
	# Fiche d'une greffe de l'inventaire (survol de la grille) : effets puis statistiques une fois posée.
	gp.set_hover_slot(-1)
	gp.set_hover_graft(ids[2])
	await _settle()
	await r._shot("textes_%s_greffe_%s" % [lang, tag], "arbre")
	# Mode daltonien : glyphes dessinés devant chaque mot-clé, couleurs plus tranchées.
	Art.set_access("deutan", false)
	gp.set_hover_slot(0)
	gp.set_hover_graft("")
	gp._refresh_detail()
	await _settle()
	await r._shot("textes_%s_dalto_%s" % [lang, tag], "arbre")
	Art.set_access("aucun", false)
	main.tree_ui.toggle()
	await r._frames(2)


func _settle() -> void:
	await r._frames(6)
	main.tree_ui.queue_redraw()
	await r._frames(3)
