## Lisibilité (jalon 12 J) : taille minimale des textes à l'écran réel (12 px, Steam Deck compris) et
## contrôle de l'audit de l'interface qui la vérifie. Les débordements en pseudo-langue et à toutes les
## tailles d'écran sont couverts par le scénario visuel « langue » (tests/visual/runner.gd).
## Lancer : tools/godot.sh --headless -s res://tests/legibility_test.gd
extends SceneTree

var failures := 0


func check(cond: bool, what: String) -> void:
	if cond:
		print("  ok   ", what)
	else:
		failures += 1
		print("  ÉCHEC ", what)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var UiTheme = load("res://scripts/ui_theme.gd")
	var UiAudit = root.get_node("UiAudit")
	print("Taille minimale")
	check(UiTheme.legible_at(14, 1.0) == 14 and UiTheme.legible_at(13, 1.0) == 13, "à 1600 x 900 : tailles inchangées")
	check(UiTheme.legible_at(14, 1.2) == 14, "à 1920 x 1080 : tailles inchangées")
	check(UiTheme.legible_at(14, 0.8) == 15 and UiTheme.legible_at(13, 0.8) == 15, "à 1280 x 800 : 13 et 14 relevés à 15 (12 px)")
	check(UiTheme.legible_at(20, 0.8) == 20, "à 1280 x 800 : un grand texte ne change pas")
	check(UiTheme.legible_at(15, 0.8) * 0.8 >= UiTheme.MIN_TEXT_PX - 0.001, "15 à l'échelle 0,8 : 12 px à l'écran")
	print("Audit de la taille")
	UiAudit.enabled = true
	UiAudit.screens.clear()
	UiAudit.text("essai", Rect2(0, 0, 100, 20), "trop petit", "", false, Color(0, 0, 0, 0), false, 14)
	UiAudit.text("essai", Rect2(0, 30, 100, 20), "assez grand", "", false, Color(0, 0, 0, 0), false, 15)
	UiAudit.text("essai", Rect2(0, 60, 100, 20), "taille inconnue")
	var view := Vector2(1600, 1000)
	var small: Array = UiAudit.check_size("essai", view, Vector2(1280, 800))
	check(small.size() == 1 and "trop petit" in str(small[0]["key"]), "à 1280 x 800, un texte de 14 est signalé (%d défaut)" % small.size())
	check(UiAudit.check_size("essai", view, Vector2(1600, 1000)).is_empty(), "à 1600 x 1000, rien n'est signalé")
	UiAudit.screens.clear()
	UiAudit.enabled = false
	print("RÉSULTAT ", "ok" if failures == 0 else "%d échec(s)" % failures)
	quit(1 if failures > 0 else 0)
