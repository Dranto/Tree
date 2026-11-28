## Étiquette à mots-clés colorés (jalon 14.5 T) : comme un Label qui coupe ses lignes, mais le texte
## passe par RichText (data/keywords.json) : « dégâts », « poison », « vie »… prennent leur couleur
## (et leur glyphe en mode d'accessibilité). Pour les fiches faites de Controls (fiche de greffe).
## Taille de police : thème « font_size » (add_theme_font_size_override), comme un Label.
class_name RichLabel
extends Control


var text := "":
	set(v):
		text = v
		_relayout()
var color := Color.WHITE:
	set(v):
		color = v
		_relayout()
var bold := false:
	set(v):
		bold = v
		_relayout()
## Largeur de coupe des lignes (pixels).
var wrap_width := 300.0:
	set(v):
		wrap_width = v
		_relayout()
var _lines: Array = []


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _fs() -> int:
	return get_theme_font_size("font_size")


func _font() -> Font:
	# Chargé ici et non préchargé : ui_theme.gd nomme des autoloads, absents quand une classe globale se compile.
	return load("res://scripts/ui_theme.gd").font(bold)


func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED:
		_relayout()


## Lignes de segments, après coupe à wrap_width.
func lines() -> Array:
	return _lines


func _relayout() -> void:
	var fs := _fs()
	_lines = RichText.wrap(RichText.split(text, color), _font(), fs, wrap_width)
	custom_minimum_size = Vector2(wrap_width, ceilf(_font().get_height(fs)) * _lines.size())
	queue_redraw()


func _draw() -> void:
	var fs := _fs()
	var f := _font()
	var lh := ceilf(f.get_height(fs))
	for i in _lines.size():
		RichText.draw_runs(self, f, Vector2(0, i * lh + f.get_ascent(fs)), _lines[i], fs)
