## Scénario « paysages » du banc visuel (runner.gd) : la lisibilité du monde (refonte « Paysages d'herbier »,
## tâche Q). Les six régions, flétries puis ravivées, vues du vrai jeu avec le héros et trois Flétris :
## une seule capture, en montage 4 × 3 (ronce et marais, plateaux et vallée, falaises et forêt ; flétri puis
## ravivé côte à côte). Mêmes cadres que tests/paysages_test.gd (tests/paysages_banc/banc.gd), qui en mesure
## le contraste ; ici on regarde. À refaire avec --update à chaque tâche qui change l'allure du monde.
extends RefCounted

const Banc = preload("res://tests/paysages_banc/banc.gd")


func run(runner) -> void:
	var main = runner.main
	var banc = Banc.new(runner.get_tree(), main)
	banc.figer()
	var images := []
	for r in Banc.REGIONS:
		for etat in Banc.ETATS:
			await banc.poser(r, etat)
			images.append(await banc.image_pleine())
	await runner._shot_image("paysages", Banc.montage(images, 4, Vector2i(560, 315)))
