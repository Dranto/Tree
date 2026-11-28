## Textes à mots-clés colorés (jalon 14.5 T) : « dégâts » en garance, « poison » en violet, « vie » en
## vert, « vitesse » en bleu, « critique » en or, « saignement » en pourpre, « armure » en brun,
## « recharge » en gris-bleu. Les mots (français et anglais) sont dans data/keywords.json.
##
## Un texte devient une suite de segments « runs » : [texte, couleur, glyphe]. Le glyphe (« » hors
## mot-clé) est un petit dessin de la catégorie, montré seulement quand un mode d'accessibilité est
## actif (daltonisme ou contraste renforcé) : la couleur ne porte jamais seule l'information, et les
## couleurs de ces modes sont plus tranchées.
##
## Pour dessiner dans un _draw, sans RichTextLabel (infobulles dessinées de l'arbre) :
##   var runs := RichText.split(texte, couleur_de_base)
##   RichText.draw_runs(self, font, position_de_la_ligne_de_base, runs, taille)
##   RichText.measure(font, runs, taille)                  # largeur, glyphes compris
##   RichText.wrap(runs, font, taille, largeur_max)        # lignes de segments, jamais un mot coupé
## Un texte de l'arbre à colorer se marque en ajoutant true à sa ligne [texte, taille, couleur].
class_name RichText
extends RefCounted

const PATH := "res://data/keywords.json"
const CACHE_MAX := 3000

## Segment : indices du tableau [texte, couleur, glyphe].
const T := 0
const C := 1
const G := 2

## Vrai pour forcer les glyphes sans mode d'accessibilité (tests), faux pour suivre Art.motifs.
static var force_glyphs := false
static var _loaded := false
static var _cats: Dictionary = {}       # catégorie -> {color, color_access, glyph}
static var _words: Dictionary = {}      # première lettre -> [{pat, star, cat}], le plus long d'abord
static var _cache: Dictionary = {}


static func _load() -> void:
	if _loaded:
		return
	_loaded = true
	var data: Dictionary = {}
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f != null:
		var parsed = JSON.parse_string(f.get_as_text())
		if parsed is Dictionary:
			data = parsed
	_cats = data.get("categories", {})
	var entries: Array = []
	for ig in data.get("ignore", []):
		entries.append({"pat": str(ig).to_lower(), "star": false, "cat": ""})
	for cat in _cats:
		for lang in ["fr", "en"]:
			for w in _cats[cat].get(lang, []):
				var pat := str(w).to_lower()
				var star := pat.ends_with("*")
				entries.append({"pat": pat.trim_suffix("*"), "star": star, "cat": cat})
	entries.sort_custom(func(a, b): return a["pat"].length() > b["pat"].length())
	_words = {}
	for e in entries:
		var k: String = e["pat"].substr(0, 1)
		if not _words.has(k):
			_words[k] = []
		_words[k].append(e)


## Catégories connues (identifiants), dans l'ordre du fichier.
static func categories() -> Array:
	_load()
	return _cats.keys()


static func glyphs_on() -> bool:
	return force_glyphs or Art.motifs


## Couleur d'une catégorie, selon le mode d'accessibilité.
static func color_of(cat: String) -> Color:
	_load()
	var d: Dictionary = _cats.get(cat, {})
	var key := "color_access" if glyphs_on() else "color"
	return Color(str(d.get(key, d.get("color", "#ffffff"))))


static func glyph_of(cat: String) -> String:
	_load()
	return str(_cats.get(cat, {}).get("glyph", ""))


static func _is_letter(code: int) -> bool:
	return (code >= 65 and code <= 90) or (code >= 97 and code <= 122) \
		or (code >= 0xC0 and code <= 0x24F and code != 0xD7 and code != 0xF7)


## Catégorie du mot-clé qui commence à l'indice i de low (texte en minuscules), et sa fin :
## [catégorie, fin] ; ["", i] si aucun. Une catégorie vide est une expression ignorée.
static func _match(low: String, i: int) -> Array:
	var list: Array = _words.get(low.substr(i, 1), [])
	for e in list:
		var pat: String = e["pat"]
		var end := i + pat.length()
		if end > low.length() or low.substr(i, pat.length()) != pat:
			continue
		if e["star"]:
			while end < low.length() and _is_letter(low.unicode_at(end)):
				end += 1
		elif end < low.length() and _is_letter(low.unicode_at(end)):
			continue
		return [e["cat"], end]
	return ["", i]


## Découpe un texte en segments [texte, couleur, glyphe]. Les mots hors mot-clé gardent base. Les
## segments se recollent exactement en le texte (plain). Un mot n'est jamais coupé.
static func split(text: String, base: Color) -> Array:
	_load()
	var key := "%s|%s|%d" % [text, base.to_html(true), int(glyphs_on())]
	if _cache.has(key):
		return _cache[key]
	var runs: Array = []
	var low := text.to_lower()
	var n := text.length()
	var plain_from := 0
	var i := 0
	while i < n:
		if _is_letter(text.unicode_at(i)) and (i == 0 or not _is_letter(text.unicode_at(i - 1))):
			var m := _match(low, i)
			var end: int = m[1]
			if end > i:
				if m[0] != "":
					if plain_from < i:
						runs.append([text.substr(plain_from, i - plain_from), base, ""])
					runs.append([text.substr(i, end - i), color_of(m[0]), glyph_of(m[0])])
					plain_from = end
				i = end
				continue
			# Mot ordinaire : on le saute en entier.
			while i < n and _is_letter(text.unicode_at(i)):
				i += 1
			continue
		i += 1
	if plain_from < n:
		runs.append([text.substr(plain_from), base, ""])
	if _cache.size() > CACHE_MAX:
		_cache.clear()
	_cache[key] = runs
	return runs


## Le texte brut des segments.
static func plain(runs: Array) -> String:
	var s := ""
	for r in runs:
		s += r[T]
	return s


## Largeur d'un glyphe de catégorie, espace compris.
static func glyph_width(fs: int) -> float:
	return fs * 0.62 + 3.0


## Largeur d'un segment : son texte, plus son glyphe s'il est affiché.
static func _run_width(font: Font, r: Array, fs: int) -> float:
	var w := font.get_string_size(r[T], HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	if r[G] != "" and glyphs_on():
		w += glyph_width(fs)
	return w


## Largeur d'une ligne de segments.
static func measure(font: Font, runs: Array, fs: int) -> float:
	var w := 0.0
	for r in runs:
		w += _run_width(font, r, fs)
	return w


## Coupe des segments en lignes de largeur max_w au plus, aux espaces (jamais au milieu d'un mot).
## Les lignes suivantes reprennent le retrait des puces (« • », « ◆ »). Un mot-clé coupé entre deux
## lignes perd son glyphe sur la seconde, mais garde sa couleur.
static func wrap(runs: Array, font: Font, fs: int, max_w: float) -> Array:
	var text := plain(runs)
	var indent := "   " if text.begins_with("• ") or text.begins_with("◆ ") else ""
	var space := font.get_string_size(" ", HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var indent_w := font.get_string_size(indent, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x if indent != "" else 0.0
	var base_col: Color = runs[0][C] if not runs.is_empty() else Color.WHITE
	# Mots : listes de segments collés (« (dégâts) » = « ( », « dégâts », « ) » sans espace entre eux).
	var words: Array = []
	var pending_space := true
	for r in runs:
		var parts: PackedStringArray = r[T].split(" ")
		for k in parts.size():
			if k > 0:
				pending_space = true
			if parts[k] == "":
				continue
			var seg := [parts[k], r[C], r[G] if k == 0 else ""]
			if pending_space or words.is_empty():
				words.append([seg])
			else:
				words[-1].append(seg)
			pending_space = false
	var lines: Array = []
	var cur: Array = []
	var lw := 0.0
	for w in words:
		var ww := 0.0
		for seg in w:
			ww += _run_width(font, seg, fs)
		if not cur.is_empty() and lw + space + ww > max_w:
			lines.append(_join(cur))
			cur = []
			lw = 0.0
			if indent != "":
				cur.append([indent, base_col, ""])
				lw = indent_w
		elif not cur.is_empty():
			cur.append([" ", w[0][C], ""])
			lw += space
		cur.append_array(w)
		lw += ww
	if not cur.is_empty() or lines.is_empty():
		lines.append(_join(cur))
	return lines


## Recolle les segments voisins de même couleur et même glyphe (un mot-clé de plusieurs mots redevient
## un seul segment, les espaces entre deux mots de la couleur de base aussi).
static func _join(parts: Array) -> Array:
	var out: Array = []
	for p in parts:
		if not out.is_empty() and out[-1][C] == p[C] and p[G] == "":
			out[-1] = [out[-1][T] + p[T], p[C], out[-1][G]]
		else:
			out.append(p.duplicate())
	return out


## Dessine une ligne de segments dont la ligne de base commence à pos. Renvoie la largeur dessinée.
## halo : contour sombre des textes posés sur le jeu (UiTheme.draw_text).
static func draw_runs(ci: CanvasItem, font: Font, pos: Vector2, runs: Array, fs: int, halo := false) -> float:
	var x := pos.x
	var glyphs := glyphs_on()
	for r in runs:
		var col: Color = r[C]
		if r[G] != "" and glyphs:
			var gr := fs * 0.27
			draw_glyph(ci, r[G], Vector2(x + gr + 1.0, pos.y - fs * 0.3), gr, col)
			x += glyph_width(fs)
		if halo:
			ci.draw_string_outline(font, Vector2(x, pos.y), r[T], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, Color(0.055, 0.04, 0.025, 0.85 * col.a))
		ci.draw_string(font, Vector2(x, pos.y), r[T], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
		x += font.get_string_size(r[T], HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	return x - pos.x


## Petits dessins des catégories, centrés en c, de rayon r : pointe (dégâts), goutte pleine (poison),
## croix (vie), chevrons (vitesse), étoile (critique), goutte creuse (saignement), écu (défense),
## flèche en cercle (recharge).
static func draw_glyph(ci: CanvasItem, glyph: String, c: Vector2, r: float, col: Color) -> void:
	var w := maxf(1.2, r * 0.38)
	match glyph:
		"pointe":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r), c + Vector2(r * 0.8, r * 0.85), c + Vector2(-r * 0.8, r * 0.85)]), col)
		"goutte":
			ci.draw_circle(c + Vector2(0, r * 0.3), r * 0.7, col)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r), c + Vector2(r * 0.62, r * 0.1), c + Vector2(-r * 0.62, r * 0.1)]), col)
		"goutte_creuse":
			var pts := PackedVector2Array([c + Vector2(0, -r)])
			for k in range(0, 13):
				var a := lerpf(-0.45, PI + 0.45, k / 12.0)
				pts.append(c + Vector2(0, r * 0.3) + Vector2(cos(a), sin(a)) * r * 0.7)
			pts.append(c + Vector2(0, -r))
			ci.draw_polyline(pts, col, w, true)
		"croix":
			ci.draw_line(c + Vector2(-r * 0.85, 0), c + Vector2(r * 0.85, 0), col, w * 1.2)
			ci.draw_line(c + Vector2(0, -r * 0.85), c + Vector2(0, r * 0.85), col, w * 1.2)
		"chevrons":
			for off in [-0.45, 0.35]:
				ci.draw_polyline(PackedVector2Array([c + Vector2(r * (off - 0.4), -r * 0.8), c + Vector2(r * (off + 0.4), 0), c + Vector2(r * (off - 0.4), r * 0.8)]), col, w, true)
		"etoile":
			var star := PackedVector2Array()
			for k in 8:
				var a := -PI / 2.0 + k * PI / 4.0
				star.append(c + Vector2(cos(a), sin(a)) * (r if k % 2 == 0 else r * 0.38))
			ci.draw_colored_polygon(star, col)
		"ecu":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.8, -r * 0.8), c + Vector2(r * 0.8, -r * 0.8), c + Vector2(r * 0.8, r * 0.1), c + Vector2(0, r), c + Vector2(-r * 0.8, r * 0.1)]), col)
		"cycle":
			ci.draw_arc(c, r * 0.8, 0.5, TAU - 0.5, 16, col, w, true)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(r * 0.95, -r * 0.55), c + Vector2(r * 0.55, r * 0.05), c + Vector2(r * 1.2, r * 0.05)]), col)
		_:
			ci.draw_circle(c, r * 0.5, col)
