## Traduction (jalon 12 A) : accès aux catalogues gettext de godot/locale/ et nombres selon la langue.
##
## La langue source est le français : l'identifiant de chaque texte (msgid) est le texte français
## lui-même, si bien qu'un texte sans traduction s'affiche en français, exactement comme avant.
## Trois façons de rendre un texte traduisible :
##   - tr("…") / Loc.t("…") : traduit tout de suite (texte composé, dessiné par draw_string…) ;
##     tr_n / Loc.tn pour un pluriel ; "…" % [args] après la traduction, jamais avant.
##   - texte littéral posé directement dans un Control (`label.text = "…"`, `add_item("…")`) ou
##     marqué Loc.key("…") : le Control le traduit lui-même (auto_translate) et suit un changement
##     de langue à chaud.
##   - textes des données (data/*.json) : Loc.data(texte) au moment de l'afficher. Les nombres du
##     texte deviennent {0}, {1}… dans le catalogue (tools/i18n.sh), puis sont remis au format de
##     la langue : un nombre réglé dans un JSON ne rend pas sa traduction caduque.
## Un littéral jamais affiché porte le commentaire « # i18n: non » ; une ligne de constantes dont
## les textes sont traduits plus loin porte « # i18n ». Voir tools/i18n.sh (extraction, couverture,
## contrôle des textes oubliés).
class_name Loc
extends RefCounted

## Langues proposées dans les options, dans l'ordre du sélecteur. "" = langue du système.
const LOCALES := ["fr", "en"]
## Nom de chaque langue dans sa propre langue (jamais traduit).
const NAMES := {"fr": "Français", "en": "English", "xx": "Pseudo (xx)"} # i18n: non
## Langue de repli et langue source.
const SOURCE := "fr"
## Pseudo-langue de contrôle : textes allongés de 40 % et accentués, pour voir les débordements et
## les textes qui échappent à la traduction (restés en français simple).
const PSEUDO := "xx"
const CATALOG_DIR := "res://locale"
const GAME_NAME_CONTEXT := "nom du jeu" # i18n: non

static var _loaded := false
static var _known: Dictionary = {}       # msgid du catalogue -> true (pseudo-langue)
static var _data_cache: Dictionary = {}  # langue -> {texte français -> texte affiché}
static var _num_re: RegEx
## Traduction de la pseudo-langue, posée seulement pendant qu'elle sert : une Translation écrite en
## GDScript encore enregistrée à la fermeture fait planter Godot (code 134).
static var _pseudo: Translation


## Charge les catalogues (godot/locale/*.po) et la pseudo-langue. Appelé par Settings au lancement ;
## sans effet la seconde fois.
static func setup() -> void:
	if _loaded:
		return
	_loaded = true
	var loaded := TranslationServer.get_loaded_locales()
	for lang in LOCALES:
		if lang in loaded:
			continue
		var path := CATALOG_DIR.path_join(lang + ".po")
		if ResourceLoader.exists(path):
			var t: Translation = load(path)
			if t:
				TranslationServer.add_translation(t)
	# Pseudo-langue : tous les msgid du catalogue source.
	var src_path := CATALOG_DIR.path_join(SOURCE + ".po")
	if ResourceLoader.exists(src_path):
		var src: Translation = load(src_path)
		if src:
			for m in src.get_message_list():
				# Un texte avec contexte est listé « contexte\u0004texte ».
				_known[String(m).get_slice(char(4), String(m).get_slice_count(char(4)) - 1)] = true


## Langue réellement utilisée pour une préférence (Settings.locale) : "" = langue du système si elle
## est proposée, sinon le français.
static func resolve(pref: String) -> String:
	if pref == PSEUDO or pref in LOCALES:
		return pref
	var sys := OS.get_locale_language()
	return sys if sys in LOCALES else SOURCE


## Applique une langue (déjà résolue). Les Control se retraduisent d'eux-mêmes ; les textes
## dessinés à la main sont redessinés (queue_redraw sur tout l'arbre de scène).
static func apply(lang: String) -> void:
	setup()
	if TranslationServer.get_locale() == lang:
		return
	if lang == PSEUDO and _pseudo == null:
		_pseudo = PseudoTranslation.new()
		_pseudo.locale = PSEUDO
		TranslationServer.add_translation(_pseudo)
	TranslationServer.set_locale(lang)
	if lang != PSEUDO:
		shutdown()
	var loop := Engine.get_main_loop() as SceneTree
	if loop and loop.root:
		loop.root.propagate_call("queue_redraw")


## Retire la pseudo-langue (changement de langue, fermeture du jeu : Settings._exit_tree).
static func shutdown() -> void:
	if _pseudo != null:
		TranslationServer.remove_translation(_pseudo)
		_pseudo = null


## Langue en cours (deux lettres).
static func lang() -> String:
	return TranslationServer.get_locale().get_slice("_", 0)


static func is_source() -> bool:
	return lang() == SOURCE


## Traduit un texte du code (même chose que tr(), utilisable dans une fonction statique).
static func t(s: String) -> String:
	return String(TranslationServer.translate(s))


## Traduit un texte dans un contexte (msgctxt), quand le même mot français se traduit autrement
## selon l'endroit (« Sève » : le nom du jeu ou la branche).
static func tc(s: String, ctx: String) -> String:
	return String(TranslationServer.translate(s, ctx))


## Nom du jeu : project.godot › application/config/name, le seul endroit où il est écrit, traduit dans
## le contexte « nom du jeu » (tools/i18n.py l'ajoute au catalogue).
static func game_name() -> String:
	return tc(str(ProjectSettings.get_setting("application/config/name")), GAME_NAME_CONTEXT)


## Pluriel : « s » au singulier, « plural » sinon (règle de la langue en cours, n > 1 en français).
static func tn(s: String, plural: String, n: int) -> String:
	if is_source():
		return s if n <= 1 else plural
	return String(TranslationServer.translate_plural(s, plural, n))


## Texte posé tel quel dans un Control qui le traduit lui-même (auto_translate) : ne fait rien, sert
## à l'extraction (tools/i18n.sh) et à dire que le texte est voulu.
static func key(s: String) -> String:
	return s


## Nombre selon la langue : virgule décimale en français, point en anglais, sans zéros inutiles.
static func num(v: float, decimals: int) -> String:
	var s := String.num(snappedf(v, pow(10.0, -decimals)), decimals)
	return s if lang() == "en" else s.replace(".", ",")


## Pourcentage entier (« 60 % » en français, « 60% » en anglais).
static func pct(n: int) -> String:
	return t("%d %%") % n


## Texte venu des données (data/*.json, écrit en français) dans la langue en cours. Les nombres du
## texte sont gardés tels quels et remis au format de la langue.
static func data(s: String) -> String:
	if s == "" or is_source():
		return s
	var l := lang()
	if not _data_cache.has(l):
		_data_cache[l] = {}
	var cache: Dictionary = _data_cache[l]
	if cache.has(s):
		return cache[s]
	var nums: Array = []
	var tpl := template(s, nums)
	var out := String(TranslationServer.translate(tpl))
	if out == tpl:
		out = s
	else:
		for i in nums.size():
			out = out.replace("{%d}" % i, _num_text(nums[i], l))
	cache[s] = out
	return out


## Gabarit d'un texte des données : chaque nombre (« 1,5 », « 30 ») devient {0}, {1}… ; « nums »
## reçoit les nombres d'origine. Même règle que tools/i18n.py.
static func template(s: String, nums: Array) -> String:
	if _num_re == null:
		_num_re = RegEx.create_from_string("(?<![\\p{L}\\d{])\\d+(?:,\\d+)?(?![\\p{L}\\d}])")
	var out := ""
	var at := 0
	for m in _num_re.search_all(s):
		out += s.substr(at, m.get_start() - at) + "{%d}" % nums.size()
		nums.append(m.get_string())
		at = m.get_end()
	return out + s.substr(at)


static func _num_text(fr: String, l: String) -> String:
	return fr.replace(",", ".") if l == "en" else fr


## Vide les caches (changement de catalogue en cours de partie, tests).
static func clear_cache() -> void:
	_data_cache.clear()


## Texte de la pseudo-langue : voyelles accentuées, 40 % plus long, entre crochets ; les
## paramètres (%d, %s, {0}, {min}, %%) et les retours à la ligne restent intacts.
static func pseudo(s: String) -> String:
	const ACCENTS := {"a": "á", "e": "é", "i": "í", "o": "ö", "u": "ü", "c": "ç", "n": "ñ", "y": "ý",
		"A": "Å", "E": "É", "I": "Î", "O": "Ø", "U": "Ü", "C": "Ç", "N": "Ñ", "Y": "Ý", "s": "š", "z": "ž"}
	var out := ""
	var i := 0
	var letters := 0
	while i < s.length():
		var ch := s[i]
		if ch == "%" and i + 1 < s.length():
			var j := i + 1
			while j < s.length() and "0123456789.-+ ".contains(s[j]):
				j += 1
			out += s.substr(i, j - i + 1)
			i = j + 1
			continue
		if ch == "{":
			var close := s.find("}", i)
			if close > i:
				out += s.substr(i, close - i + 1)
				i = close + 1
				continue
		out += ACCENTS.get(ch, ch)
		if ch.to_lower() != ch.to_upper():
			letters += 1
		i += 1
	var pad := ceili(letters * 0.4)
	var filler := ""
	const WORDS := "ŀőŕéḿ íþšüḿ ðöłöŕ šíţ åḿéţ " # i18n: non
	while filler.length() < pad:
		filler += WORDS
	filler = filler.substr(0, pad).strip_edges()
	return "[" + out + (" " + filler if filler != "" else "") + "]"


## Vrai si le texte vient de la pseudo-langue (tests : un texte visible qui ne l'est pas a
## échappé à la traduction).
static func is_pseudo(s: String) -> bool:
	return s.begins_with("[") and s.ends_with("]")


static func known(msgid: String) -> bool:
	setup()
	return _known.has(msgid)


## Pseudo-langue : traduit seulement les textes du catalogue, pour que les textes oubliés
## (absents du catalogue ou jamais passés par tr) restent visibles en français.
class PseudoTranslation extends Translation:
	func _get_message(src_message: StringName, _context: StringName) -> StringName:
		var s := String(src_message)
		if Loc._known.has(s):
			return StringName(Loc.pseudo(s))
		return StringName()

	func _get_plural_message(src_message: StringName, src_plural_message: StringName, n: int, _context: StringName) -> StringName:
		var s := String(src_message) if n <= 1 else String(src_plural_message)
		if Loc._known.has(String(src_message)):
			return StringName(Loc.pseudo(s))
		return StringName()
