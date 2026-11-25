## Réglages du joueur (volume, plein écran, aide, déplacement, visée, commandes de la barre de compétences) :
## chargés et enregistrés dans user://settings.cfg.
extends Node

signal changed
## La dernière entrée vient d'un autre appareil (clavier et souris, ou manette) : glyphes et textes
## des commandes basculent (voir last_device).
signal device_changed

const PATH := "user://settings.cfg"

## Langue (jalon 12 A) : "" = langue du système (repli français), "fr", "en" (voir Loc.LOCALES), ou
## la pseudo-langue "xx". Section « general » de settings.cfg. L'argument « --lang=<code> » ou la
## variable d'environnement TREE_LANG passent avant (tests : toujours en français).
var locale := ""

var volume := 0.8
## Réglages séparés de la musique et des bruitages, en plus du volume général.
var music_volume := 0.7
var sfx_volume := 0.9
## Ambiance sonore (vent, eau, oiseaux…), bus « Ambiance ».
var ambience_volume := 0.8
var fullscreen := false
var show_hints := true
## Chiffres de dégâts flottants : « aucun » (par défaut, choix d'Antoine au jalon 11 : le coup se
## lit à l'impact), « critiques » (coups critiques et dégâts reçus) ou « tous ».
## Clé à part (« gameplay/damage_numbers ») : l'ancien réglage, toujours enregistré à vrai, n'est pas repris.
const DAMAGE_NUMBERS := ["aucun", "critiques", "tous"]
const DAMAGE_NUMBERS_NAMES := {"aucun": "Aucun", "critiques": "Critiques et dégâts reçus", "tous": "Tous"} # i18n
var damage_numbers := "aucun"
## Commandes de la barre de compétences : six emplacements, alignés sur player.bar.
## - 0 et 1 : les deux compétences principales, sur les clics gauche et droit (actions
##   « skill_main_1 » et « skill_main_2 ») ;
## - 2 à 5 : les compétences secondaires (actions « slot_1 » à « slot_4 »), sur A E R F en
##   AZERTY, et sur les chiffres 1 à 4.
## Une liaison est un entier : un bouton de souris est codé en négatif (-MOUSE_BUTTON_LEFT…),
## sinon c'est une touche physique (QWERTY : KEY_Q devient A sur un clavier AZERTY).
const SLOT_COUNT := 6
const MOUSE_SLOTS := 2
const SLOT_ACTIONS := ["skill_main_1", "skill_main_2", "slot_1", "slot_2", "slot_3", "slot_4"]
const SLOT_DIGITS := [KEY_NONE, KEY_NONE, KEY_1, KEY_2, KEY_3, KEY_4]
const BINDING_DEFAULTS := [-MOUSE_BUTTON_LEFT, -MOUSE_BUTTON_RIGHT, KEY_Q, KEY_E, KEY_R, KEY_F]
## Boutons de souris acceptés pour une compétence (la molette n'en fait pas partie).
const MOUSE_BUTTONS := [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE, MOUSE_BUTTON_XBUTTON1, MOUSE_BUTTON_XBUTTON2]
var bindings: Array = BINDING_DEFAULTS.duplicate()
## Mode « moba » : le clic droit sert à marcher. La compétence liée au clic droit passe sur
## cette touche (Maj par défaut), et l'esquive ne garde qu'Espace.
const MOBA_MAIN_2_DEFAULT := KEY_SHIFT
var moba_main_2_key: int = MOBA_MAIN_2_DEFAULT
## Visée de l'attaque de base : « auto » (par défaut, l'ennemi à portée le plus proche du
## curseur, voir player.auto_target) ou « curseur » (toujours vers la souris, même sans ennemi).
const AIM_MODES := ["auto", "curseur"]
const AIM_MODE_NAMES := {"auto": "Automatique", "curseur": "Vers le curseur"} # i18n
var aim_mode := "auto"
## Secousse d'écran, de 0 (aucune) à 1 (pleine). Ancienne clé « gameplay/shake », reprise.
var shake_scale := 0.6
## Éclats lumineux (flash plein écran, blanchiment d'un impact), de 0 (aucun) à 1 (pleins).
var flash_scale := 1.0
## Durée des micro-pauses à l'impact, de 0 (aucune) à 1 (pleine).
var hitstop_scale := 1.0
## Vibration de la manette (Rumble) : 0 la coupe, 1 plein dosage. Réglage à part : « Réduire les
## effets » ne la coupe pas.
var rumble_scale := 0.7
## Accessibilité (jalon 11). Mode daltonien : palette adaptée des signaux de danger, d'élite et de
## butin (Art.c), et motifs ajoutés aux zones de danger annoncées. Voir COLORBLIND_MODES.
const COLORBLIND_MODES := ["aucun", "protanopie", "deuteranopie", "tritanopie"]
const COLORBLIND_NAMES := {"aucun": "Aucun", "protanopie": "Protanopie (rouge)", "deuteranopie": "Deutéranopie (vert)", "tritanopie": "Tritanopie (bleu)"} # i18n
var colorblind_mode := "aucun"
## Taille des textes de l'interface (menus, panneaux, bannières), en facteur du thème Herbier.
const TEXT_SCALES := [1.0, 1.15, 1.3]
const TEXT_SCALE_NAMES := ["Normale", "Grande", "Très grande"] # i18n
var text_scale := 1.0
## Taille de texte par défaut sur un Steam Deck (écran de 7 pouces), tant que le joueur n'a rien choisi.
const DECK_TEXT_SCALE := 1.15
## Contraste renforcé : textes secondaires en pleine encre, filets et panneaux plus marqués, zones de
## danger plus opaques.
var high_contrast := false
## Met le jeu en pause quand la fenêtre perd le focus (Alt-Tab, autre fenêtre au premier plan).
var pause_on_focus_loss := true
## Commandes du jeu hors barre de compétences : touche principale de chaque action, réassignable
## (touche physique, comme la barre). Les flèches restent toujours actives pour se déplacer, T pour
## l'arbre. La carte garde par défaut la lettre logique (M) quelle que soit la
## disposition du clavier ; réassignée, elle prend la touche physique pressée.
const GAME_ACTIONS := ["move_up", "move_left", "move_down", "move_right", "dash", "toggle_tree", "toggle_map"]
const GAME_ACTION_NAMES := {"move_up": "Avancer", "move_left": "Aller à gauche", "move_down": "Reculer", "move_right": "Aller à droite", # i18n
	"dash": "Esquive", "toggle_tree": "Arbre de vie", "toggle_map": "Carte"} # i18n
const ACTION_DEFAULTS := {"move_up": KEY_W, "move_left": KEY_A, "move_down": KEY_S, "move_right": KEY_D,
	"dash": KEY_SPACE, "toggle_tree": KEY_TAB, "toggle_map": KEY_M}
## Touches toujours actives en plus (non réassignables, ne gênent pas une réassignation).
const ACTION_EXTRAS := {"move_up": [KEY_UP], "move_left": [KEY_LEFT], "move_down": [KEY_DOWN], "move_right": [KEY_RIGHT], "toggle_tree": [KEY_T]}
## Actions dont la touche par défaut est une lettre logique (et non une position physique).
const LOGICAL_DEFAULTS := ["toggle_map"]
var action_keys: Dictionary = ACTION_DEFAULTS.duplicate()
## Manette (jalon 11). Une liaison de manette est un entier : un bouton (JOY_BUTTON_*), ou une
## gâchette codée PAD_AXIS + axe (JOY_AXIS_TRIGGER_LEFT ou JOY_AXIS_TRIGGER_RIGHT).
## Fixes : stick gauche (et croix directionnelle) pour marcher, stick droit pour viser, Start pour la
## pause, A pour valider et B pour revenir dans les menus.
const PAD_AXIS := 200
const PAD_LT := PAD_AXIS + JOY_AXIS_TRIGGER_LEFT
const PAD_RT := PAD_AXIS + JOY_AXIS_TRIGGER_RIGHT
## Pseudo-codes des glyphes (jamais liés) : sticks et croix directionnelle entière.
const PAD_STICK_L := 300
const PAD_STICK_R := 301
const PAD_DPAD := 302
## Barre de compétences : gâchettes droite et gauche pour les principales, X Y B et RB pour les secondaires.
const PAD_SLOT_DEFAULTS := [PAD_RT, PAD_LT, JOY_BUTTON_X, JOY_BUTTON_Y, JOY_BUTTON_B, JOY_BUTTON_RIGHT_SHOULDER]
var pad_bindings: Array = PAD_SLOT_DEFAULTS.duplicate()
## Commandes du jeu réassignables à la manette (mêmes noms que GAME_ACTIONS).
const PAD_ACTIONS := ["dash", "toggle_tree", "toggle_map"]
const PAD_ACTION_DEFAULTS := {"dash": JOY_BUTTON_A, "toggle_tree": JOY_BUTTON_BACK, "toggle_map": JOY_BUTTON_LEFT_SHOULDER}
var pad_actions: Dictionary = PAD_ACTION_DEFAULTS.duplicate()
## Boutons qu'on ne peut pas lier : Start ouvre toujours la pause.
const PAD_RESERVED := [JOY_BUTTON_START]
## Boutons et gâchettes acceptés pour une liaison.
const PAD_BUTTONS := [JOY_BUTTON_A, JOY_BUTTON_B, JOY_BUTTON_X, JOY_BUTTON_Y, JOY_BUTTON_LEFT_SHOULDER, JOY_BUTTON_RIGHT_SHOULDER,
	JOY_BUTTON_LEFT_STICK, JOY_BUTTON_RIGHT_STICK, JOY_BUTTON_BACK, JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_DOWN, JOY_BUTTON_DPAD_LEFT,
	JOY_BUTTON_DPAD_RIGHT, JOY_BUTTON_PADDLE1, JOY_BUTTON_PADDLE2, JOY_BUTTON_PADDLE3, JOY_BUTTON_PADDLE4, PAD_LT, PAD_RT] # i18n
## Glyphes de la manette : « auto » (selon le nom de la manette branchée), « xbox » ou « playstation ».
const PAD_STYLES := ["auto", "xbox", "playstation"]
const PAD_STYLE_NAMES := {"auto": "Automatique", "xbox": "Xbox (A B X Y)", "playstation": "PlayStation (croix, rond…)"} # i18n
var pad_style := "auto"
## Zone morte des sticks (part de la course) : marche, visée, curseur de l'arbre.
const STICK_DEADZONE := 0.22
## Appareil de la dernière entrée : « clavier » (clavier et souris) ou « manette ». Les glyphes des
## commandes (barre, tutoriel, arbre) suivent ; une partie démarre au clavier.
var last_device := "clavier"
## Nom de la dernière manette utilisée (Input.get_joy_name), pour le style automatique des glyphes.
var pad_name := ""
## Force des rafales de vent (région de Vent, wind.gd), de 0 (coupées) à 1 (pleine) : elles poussent
## le joueur et dévient les projectiles. Accessibilité : on peut les couper.
var wind := 1.0
## Difficulté : « facile », « normal » (par défaut) ou « difficile ». Multiplie la vie et les
## dégâts des ennemis (réglages dans res://data/difficulty.json, section « modes »).
const DIFFICULTIES := ["facile", "normal", "difficile"]
var difficulty := "normal"
## Déplacement du héros : « clavier » (par défaut, Z Q S D ou flèches), « curseur » (il marche
## vers la souris) ou « moba » (un clic droit fixe une destination). Dans les deux modes à la
## souris, le clavier reste utilisable et prend la main tant qu'une touche de direction est tenue.
## Un choix déjà enregistré dans user://settings.cfg est gardé.
const MOVE_MODES := ["clavier", "curseur", "moba"]
const MOVE_MODE_NAMES := {"clavier": "Clavier (Z Q S D)", "curseur": "Suivre le curseur", "moba": "Clic droit (MOBA)"} # i18n
const MOVE_MODE_DEFAULT := "clavier"
var move_mode := MOVE_MODE_DEFAULT
## Réduit les effets de jeu : plus de secousse ni de micro-pause, très peu de particules, ambiance coupée.
var reduce_effects := false


func _exit_tree() -> void:
	Loc.shutdown()


func _ready() -> void:
	# Toujours à l'écoute (menus et arbre mettent le jeu en pause) : suit l'appareil utilisé.
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_settings()
	apply_locale()
	apply_bindings()
	apply()
	_apply_access.call_deferred()


func load_settings() -> void:
	# Sur un Steam Deck, texte plus grand par défaut (un choix enregistré l'emporte, lu plus bas).
	# Chargé ici et non nommé : steam_bridge.gd est un autoload.
	if load("res://scripts/steam_bridge.gd").detect_deck():
		text_scale = DECK_TEXT_SCALE
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	var loc := str(cfg.get_value("general", "locale", locale))
	locale = loc if loc == "" or loc == Loc.PSEUDO or loc in Loc.LOCALES else ""
	volume = clampf(float(cfg.get_value("audio", "volume", volume)), 0.0, 1.0)
	music_volume = clampf(float(cfg.get_value("audio", "music_volume", music_volume)), 0.0, 1.0)
	sfx_volume = clampf(float(cfg.get_value("audio", "sfx_volume", sfx_volume)), 0.0, 1.0)
	ambience_volume = clampf(float(cfg.get_value("audio", "ambience_volume", ambience_volume)), 0.0, 1.0)
	fullscreen = bool(cfg.get_value("video", "fullscreen", fullscreen))
	show_hints = bool(cfg.get_value("gameplay", "show_hints", show_hints))
	var dn := str(cfg.get_value("gameplay", "damage_numbers", damage_numbers))
	damage_numbers = dn if dn in DAMAGE_NUMBERS else "aucun"
	# Section « bindings » (jalon 6) : les anciennes touches « controls/slot_N » visaient une autre
	# disposition de la barre et ne sont plus lues.
	for i in SLOT_COUNT:
		var b := int(cfg.get_value("bindings", SLOT_ACTIONS[i], bindings[i]))
		bindings[i] = b if _valid_binding(b) else BINDING_DEFAULTS[i]
	var mk := int(cfg.get_value("bindings", "moba_main_2", moba_main_2_key))
	moba_main_2_key = mk if mk > 0 else MOBA_MAIN_2_DEFAULT
	var aim := str(cfg.get_value("controls", "aim_mode", aim_mode))
	aim_mode = aim if aim in AIM_MODES else "auto"
	shake_scale = clampf(float(cfg.get_value("gameplay", "shake_scale", cfg.get_value("gameplay", "shake", shake_scale))), 0.0, 1.0)
	flash_scale = clampf(float(cfg.get_value("gameplay", "flash_scale", flash_scale)), 0.0, 1.0)
	hitstop_scale = clampf(float(cfg.get_value("gameplay", "hitstop_scale", hitstop_scale)), 0.0, 1.0)
	rumble_scale = clampf(float(cfg.get_value("gameplay", "rumble_scale", rumble_scale)), 0.0, 1.0)
	var cb := str(cfg.get_value("access", "colorblind_mode", colorblind_mode))
	colorblind_mode = cb if cb in COLORBLIND_MODES else "aucun"
	text_scale = _nearest_text_scale(float(cfg.get_value("access", "text_scale", text_scale)))
	high_contrast = bool(cfg.get_value("access", "high_contrast", high_contrast))
	pause_on_focus_loss = bool(cfg.get_value("access", "pause_on_focus_loss", pause_on_focus_loss))
	for a in GAME_ACTIONS:
		var k := int(cfg.get_value("actions", a, action_keys[a]))
		action_keys[a] = k if k > 0 else ACTION_DEFAULTS[a]
	wind = clampf(float(cfg.get_value("gameplay", "wind", wind)), 0.0, 1.0)
	reduce_effects = bool(cfg.get_value("gameplay", "reduce_effects", reduce_effects))
	var diff := str(cfg.get_value("gameplay", "difficulty", difficulty))
	difficulty = diff if diff in DIFFICULTIES else "normal"
	var mode := str(cfg.get_value("controls", "move_mode", move_mode))
	move_mode = mode if mode in MOVE_MODES else MOVE_MODE_DEFAULT
	for i in SLOT_COUNT:
		var pb := int(cfg.get_value("pad", SLOT_ACTIONS[i], pad_bindings[i]))
		pad_bindings[i] = pb if pb == JOY_BUTTON_INVALID or pb in PAD_BUTTONS else PAD_SLOT_DEFAULTS[i]
	for a in PAD_ACTIONS:
		var pa := int(cfg.get_value("pad", a, pad_actions[a]))
		pad_actions[a] = pa if pa in PAD_BUTTONS else PAD_ACTION_DEFAULTS[a]
	var ps := str(cfg.get_value("pad", "style", pad_style))
	pad_style = ps if ps in PAD_STYLES else "auto"
	apply_bindings()


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("general", "locale", locale)
	cfg.set_value("audio", "volume", volume)
	cfg.set_value("audio", "music_volume", music_volume)
	cfg.set_value("audio", "sfx_volume", sfx_volume)
	cfg.set_value("audio", "ambience_volume", ambience_volume)
	cfg.set_value("video", "fullscreen", fullscreen)
	cfg.set_value("gameplay", "show_hints", show_hints)
	cfg.set_value("gameplay", "damage_numbers", damage_numbers)
	for i in SLOT_COUNT:
		cfg.set_value("bindings", SLOT_ACTIONS[i], bindings[i])
	cfg.set_value("bindings", "moba_main_2", moba_main_2_key)
	cfg.set_value("controls", "aim_mode", aim_mode)
	cfg.set_value("gameplay", "shake_scale", shake_scale)
	cfg.set_value("gameplay", "flash_scale", flash_scale)
	cfg.set_value("gameplay", "hitstop_scale", hitstop_scale)
	cfg.set_value("gameplay", "rumble_scale", rumble_scale)
	cfg.set_value("access", "colorblind_mode", colorblind_mode)
	cfg.set_value("access", "text_scale", text_scale)
	cfg.set_value("access", "high_contrast", high_contrast)
	cfg.set_value("access", "pause_on_focus_loss", pause_on_focus_loss)
	for a in GAME_ACTIONS:
		cfg.set_value("actions", a, action_keys[a])
	cfg.set_value("gameplay", "wind", wind)
	cfg.set_value("gameplay", "reduce_effects", reduce_effects)
	cfg.set_value("gameplay", "difficulty", difficulty)
	cfg.set_value("controls", "move_mode", move_mode)
	for i in SLOT_COUNT:
		cfg.set_value("pad", SLOT_ACTIONS[i], pad_bindings[i])
	for a in PAD_ACTIONS:
		cfg.set_value("pad", a, pad_actions[a])
	cfg.set_value("pad", "style", pad_style)
	if cfg.save(PATH) == OK:
		SteamBridge.cloud_push(PATH)


## Crée ou remet à jour les actions de la barre (« skill_main_1 », « skill_main_2 », « slot_1 » à
## « slot_4 »), les commandes du jeu (GAME_ACTIONS : déplacement, esquive, arbre, carte) et
## l'esquive (sa touche, plus Maj hors du mode « moba »).
func apply_bindings() -> void:
	for a in GAME_ACTIONS:
		if a == "dash":
			continue
		if InputMap.has_action(a):
			InputMap.action_erase_events(a)
		else:
			InputMap.add_action(a)
		InputMap.action_add_event(a, _action_event(a))
		for k in ACTION_EXTRAS.get(a, []):
			if k != action_keys[a]:
				InputMap.action_add_event(a, _event(k))
		for ev in _pad_events(a):
			InputMap.action_add_event(a, ev)
		if a in MOVE_PAD:
			InputMap.action_set_deadzone(a, STICK_DEADZONE)
	for i in SLOT_COUNT:
		var action: String = SLOT_ACTIONS[i]
		if InputMap.has_action(action):
			InputMap.action_erase_events(action)
		else:
			InputMap.add_action(action)
		for code in [SLOT_DIGITS[i], effective_binding(i)]:
			var ev := _event(code)
			if ev != null:
				InputMap.action_add_event(action, ev)
		var pev := pad_event(pad_bindings[i])
		if pev != null:
			InputMap.action_add_event(action, pev)
	if InputMap.has_action("dash"):
		InputMap.action_erase_events("dash")
	else:
		InputMap.add_action("dash")
	var dash_keys := [action_keys["dash"]] if move_mode == "moba" else [action_keys["dash"], KEY_SHIFT]
	for k in dash_keys:
		if not _bound(k) and InputMap.action_get_events("dash").all(func(e): return (e as InputEventKey).physical_keycode != k):
			InputMap.action_add_event("dash", _event(k))
	for ev in _pad_events("dash"):
		InputMap.action_add_event("dash", ev)
	_apply_pad_ui()


## Actions de marche et de visée au stick : axe et sens de chaque action.
const MOVE_PAD := {"move_up": [JOY_AXIS_LEFT_Y, -1.0, JOY_BUTTON_DPAD_UP], "move_down": [JOY_AXIS_LEFT_Y, 1.0, JOY_BUTTON_DPAD_DOWN],
	"move_left": [JOY_AXIS_LEFT_X, -1.0, JOY_BUTTON_DPAD_LEFT], "move_right": [JOY_AXIS_LEFT_X, 1.0, JOY_BUTTON_DPAD_RIGHT]}
const AIM_PAD := {"aim_up": [JOY_AXIS_RIGHT_Y, -1.0], "aim_down": [JOY_AXIS_RIGHT_Y, 1.0],
	"aim_left": [JOY_AXIS_RIGHT_X, -1.0], "aim_right": [JOY_AXIS_RIGHT_X, 1.0]}


## Évènements de manette d'une commande du jeu : stick gauche et croix pour marcher, bouton lié pour
## l'esquive, l'arbre et la carte.
func _pad_events(a: String) -> Array:
	var out: Array = []
	if MOVE_PAD.has(a):
		out.append(_axis_event(MOVE_PAD[a][0], MOVE_PAD[a][1]))
		var b := InputEventJoypadButton.new()
		b.device = -1
		b.button_index = MOVE_PAD[a][2]
		out.append(b)
	elif pad_actions.has(a):
		var ev := pad_event(pad_actions[a])
		if ev != null:
			out.append(ev)
	return out


static func _axis_event(axis: int, value: float) -> InputEventJoypadMotion:
	var m := InputEventJoypadMotion.new()
	m.device = -1
	m.axis = axis
	m.axis_value = value
	return m


## Évènement d'une liaison de manette (bouton, ou gâchette au-delà de PAD_AXIS), sur toutes les manettes.
static func pad_event(code: int) -> InputEvent:
	if code >= PAD_AXIS and code < PAD_AXIS + JOY_AXIS_MAX:
		return _axis_event(code - PAD_AXIS, 1.0)
	if code < 0 or code >= JOY_BUTTON_MAX:
		return null
	var b := InputEventJoypadButton.new()
	b.device = -1
	b.button_index = code
	return b


## Actions de l'interface à la manette : A valide, B revient, Start (ou Échap) met en pause, stick
## droit pour viser (et déplacer le curseur de l'arbre).
func _apply_pad_ui() -> void:
	for pair in [["ui_accept", JOY_BUTTON_A], ["ui_cancel", JOY_BUTTON_B]]:
		var has := InputMap.action_get_events(pair[0]).any(func(e): return e is InputEventJoypadButton and e.button_index == pair[1])
		if not has:
			InputMap.action_add_event(pair[0], pad_event(pair[1]))
	if not InputMap.has_action("pause"):
		InputMap.add_action("pause")
		InputMap.action_add_event("pause", _event(KEY_ESCAPE))
		InputMap.action_add_event("pause", pad_event(JOY_BUTTON_START))
	# Gâchettes lues en continu dans l'arbre (zoom), sans être des commandes réassignables.
	for pair in [["pad_zoom_in", JOY_AXIS_TRIGGER_RIGHT], ["pad_zoom_out", JOY_AXIS_TRIGGER_LEFT]]:
		if not InputMap.has_action(pair[0]):
			InputMap.add_action(pair[0], 0.1)
			InputMap.action_add_event(pair[0], _axis_event(pair[1], 1.0))
	for a in AIM_PAD:
		if not InputMap.has_action(a):
			InputMap.add_action(a, STICK_DEADZONE)
			InputMap.action_add_event(a, _axis_event(AIM_PAD[a][0], AIM_PAD[a][1]))


## Évènement principal d'une commande du jeu : touche physique, sauf la lettre logique par défaut
## de la carte.
func _action_event(a: String) -> InputEvent:
	var k: int = action_keys[a]
	if a in LOGICAL_DEFAULTS and k == ACTION_DEFAULTS[a]:
		var ev := InputEventKey.new()
		ev.keycode = k
		return ev
	return _event(k)


## Nom affiché de la touche d'une commande du jeu.
func action_key_name(a: String) -> String:
	var k: int = action_keys.get(a, KEY_NONE)
	if a in LOGICAL_DEFAULTS and k == ACTION_DEFAULTS[a]:
		return OS.get_keycode_string(k)
	return key_name(k)


## Commande du jeu ou emplacement de la barre qui utilise déjà cette touche (hors `except`), ou "".
func key_user(code: int, except := "") -> String:
	for a in GAME_ACTIONS:
		if a != except and action_keys[a] == code:
			return tr(GAME_ACTION_NAMES[a])
	for i in SLOT_COUNT:
		if SLOT_ACTIONS[i] != except and effective_binding(i) == code:
			return tr("compétence %d") % (i + 1)
	if move_mode == "moba" and except != "moba_main_2" and moba_main_2_key == code:
		return tr("compétence principale 2 (MOBA)")
	return ""


## Réassigne la touche principale d'une commande du jeu. Refusé (renvoie le nom de la commande qui
## l'utilise) si la touche est déjà prise ; Échap reste réservé au menu.
func set_action_key(a: String, code: int) -> String:
	if not a in GAME_ACTIONS or code <= 0:
		return "?"
	if code == KEY_ESCAPE:
		return tr("le menu")
	var user := key_user(code, a)
	if user != "":
		return user
	action_keys[a] = code
	apply_bindings()
	changed.emit()
	return ""


## Remet toutes les commandes (barre et jeu) à leurs touches par défaut.
func reset_bindings() -> void:
	bindings = BINDING_DEFAULTS.duplicate()
	moba_main_2_key = MOBA_MAIN_2_DEFAULT
	action_keys = ACTION_DEFAULTS.duplicate()
	pad_bindings = PAD_SLOT_DEFAULTS.duplicate()
	pad_actions = PAD_ACTION_DEFAULTS.duplicate()
	apply_bindings()
	changed.emit()


## Une touche déjà prise par la barre (la touche du clic droit en mode « moba », par exemple).
func _bound(code: int) -> bool:
	for i in SLOT_COUNT:
		if effective_binding(i) == code:
			return true
	return false


static func _event(code: int) -> InputEvent:
	if code < 0:
		var mb := InputEventMouseButton.new()
		mb.button_index = -code
		return mb
	if code == KEY_NONE:
		return null
	var ev := InputEventKey.new()
	ev.physical_keycode = code
	return ev


static func _valid_binding(code: int) -> bool:
	return code >= 0 or -code in MOUSE_BUTTONS


## Action de l'emplacement i de la barre (0 = clic gauche, 1 = clic droit, 2 à 5 = secondaires).
static func slot_action(i: int) -> String:
	return SLOT_ACTIONS[i] if i >= 0 and i < SLOT_COUNT else ""


## Liaison réellement en service : en mode « moba », la compétence du clic droit passe sur
## moba_main_2_key, puisque le clic droit y sert à marcher.
func effective_binding(i: int) -> int:
	var b: int = bindings[i]
	if move_mode == "moba" and b == -MOUSE_BUTTON_RIGHT:
		return moba_main_2_key
	return b


func binding_is_mouse(i: int) -> bool:
	return effective_binding(i) < 0


## Nom affiché de la liaison de l'emplacement i (« Clic gauche », « A »…).
func binding_name(i: int) -> String:
	return code_name(effective_binding(i))


## Nom court de la liaison de l'emplacement i, pour la barre (« Clic G », « A »).
func binding_short(i: int) -> String:
	var code := effective_binding(i)
	if code < 0:
		match -code:
			MOUSE_BUTTON_LEFT: return tr("Clic G")
			MOUSE_BUTTON_RIGHT: return tr("Clic D")
			MOUSE_BUTTON_MIDDLE: return tr("Clic M")
			MOUSE_BUTTON_XBUTTON1: return "B4"
			MOUSE_BUTTON_XBUTTON2: return "B5"
	return code_name(code)


## Nom affiché d'une liaison : bouton de souris, ou touche selon la disposition du clavier.
func code_name(code: int) -> String:
	if code < 0:
		match -code:
			MOUSE_BUTTON_LEFT: return tr("Clic gauche")
			MOUSE_BUTTON_RIGHT: return tr("Clic droit")
			MOUSE_BUTTON_MIDDLE: return tr("Clic milieu")
			MOUSE_BUTTON_XBUTTON1: return tr("Bouton 4")
			MOUSE_BUTTON_XBUTTON2: return tr("Bouton 5")
		return tr("Souris %d") % -code
	return key_name(code)


## Réassigne l'emplacement i (KEY_NONE pour l'enlever). Une liaison déjà prise par un autre
## emplacement lui est retirée, pour qu'une touche ne lance jamais deux compétences.
func set_binding(i: int, code: int) -> void:
	if not _valid_binding(code):
		return
	for j in SLOT_COUNT:
		if j != i and bindings[j] == code:
			bindings[j] = KEY_NONE
	bindings[i] = code
	apply_bindings()
	changed.emit()


## Touche de la compétence du clic droit en mode « moba ».
func set_moba_main_2_key(code: int) -> void:
	if code <= 0:
		return
	for j in SLOT_COUNT:
		if bindings[j] == code:
			bindings[j] = KEY_NONE
	moba_main_2_key = code
	apply_bindings()
	changed.emit()


## Nom affiché d'une touche physique selon la disposition du clavier (A sur AZERTY pour KEY_Q).
func key_name(physical_keycode: int) -> String:
	if physical_keycode == KEY_NONE:
		return "—"
	if KEY_FR.has(physical_keycode):
		return tr(KEY_FR[physical_keycode])
	var kc := physical_keycode
	if DisplayServer.get_name() != "headless":
		kc = DisplayServer.keyboard_get_keycode_from_physical(kc)
	return OS.get_keycode_string(kc)


## Noms français des touches que Godot nomme en anglais.
const KEY_FR := {KEY_UP: "Flèche haut", KEY_DOWN: "Flèche bas", KEY_LEFT: "Flèche gauche", KEY_RIGHT: "Flèche droite", # i18n
	KEY_SPACE: "Espace", KEY_SHIFT: "Maj", KEY_TAB: "Tab", KEY_ENTER: "Entrée", KEY_CTRL: "Ctrl", KEY_BACKSPACE: "Retour arrière"} # i18n


## Action du jeu (hors barre de compétences) qui utilise déjà cette liaison, ou "".
## L'esquive n'est pas comptée pour Maj, que la barre peut reprendre (mode « moba »).
func key_owner(code: int) -> String:
	if code == KEY_SHIFT:
		return ""
	for action in InputMap.get_actions():
		if str(action) in SLOT_ACTIONS or str(action).begins_with("ui_"):
			continue
		for ev in InputMap.action_get_events(action):
			var k := ev as InputEventKey
			if k and k.physical_keycode == code:
				return str(action)
			var m := ev as InputEventMouseButton
			if m and -m.button_index == code:
				return str(action)
	return ""


func apply() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(volume, 0.0001)))
	AudioServer.set_bus_mute(0, volume <= 0.001)
	_set_bus("Musique", music_volume) # i18n: non (bus audio)
	_set_bus("Effets", sfx_volume) # i18n: non
	_set_bus("Ambiance", ambience_volume) # i18n: non
	if DisplayServer.get_name() != "headless":
		var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
		if DisplayServer.window_get_mode() != mode:
			DisplayServer.window_set_mode(mode)
	changed.emit()


## Volume d'un bus (s'il existe : Sfx et Music le créent à leur démarrage et rappellent apply()).
func _set_bus(bus: String, v: float) -> void:
	var i := AudioServer.get_bus_index(bus)
	if i >= 0:
		AudioServer.set_bus_volume_db(i, linear_to_db(maxf(v, 0.0001)))
		AudioServer.set_bus_mute(i, v <= 0.001)


func set_music_volume(v: float) -> void:
	music_volume = clampf(v, 0.0, 1.0)
	apply()


func set_sfx_volume(v: float) -> void:
	sfx_volume = clampf(v, 0.0, 1.0)
	apply()


func set_ambience_volume(v: float) -> void:
	ambience_volume = clampf(v, 0.0, 1.0)
	apply()


func set_volume(v: float) -> void:
	volume = clampf(v, 0.0, 1.0)
	apply()


func set_fullscreen(on: bool) -> void:
	fullscreen = on
	apply()


func set_show_hints(on: bool) -> void:
	show_hints = on
	apply()


func set_damage_numbers(id: String) -> void:
	damage_numbers = id if id in DAMAGE_NUMBERS else "aucun"
	changed.emit()


## Vrai si un chiffre doit s'afficher : crit (ou dégât reçu) vaut pour « critiques ».
func shows_number(crit: bool) -> bool:
	return damage_numbers == "tous" or (crit and damage_numbers == "critiques")


func set_shake(v: float) -> void:
	shake_scale = clampf(v, 0.0, 1.0)
	changed.emit()


func set_rumble(v: float) -> void:
	rumble_scale = clampf(v, 0.0, 1.0)
	changed.emit()


func set_flash(v: float) -> void:
	flash_scale = clampf(v, 0.0, 1.0)
	changed.emit()


func set_colorblind_mode(id: String) -> void:
	colorblind_mode = id if id in COLORBLIND_MODES else "aucun"
	_apply_access()
	changed.emit()


func set_text_scale(v: float) -> void:
	text_scale = _nearest_text_scale(v)
	changed.emit()


func set_high_contrast(on: bool) -> void:
	high_contrast = on
	_apply_access()
	changed.emit()


func set_pause_on_focus_loss(on: bool) -> void:
	pause_on_focus_loss = on
	changed.emit()


static func _nearest_text_scale(v: float) -> float:
	var best: float = TEXT_SCALES[0]
	for t in TEXT_SCALES:
		if absf(t - v) < absf(best - v):
			best = t
	return best


## Transmet le mode daltonien et le contraste à la charte (Art.c) et au thème de l'interface.
func _apply_access() -> void:
	Art.set_access(colorblind_mode, high_contrast)
	# Chargé ici et non préchargé : ui_theme.gd nomme des autoloads créés après celui-ci.
	load("res://scripts/ui_theme.gd").refresh_access(high_contrast)


## Couleur de danger adaptée au mode daltonien (zones annoncées, signaux d'attaque).
func danger_color() -> Color:
	return Art.c("danger")


func set_wind(v: float) -> void:
	wind = clampf(v, 0.0, 1.0)
	changed.emit()


func set_reduce_effects(on: bool) -> void:
	reduce_effects = on
	changed.emit()


## Langue forcée par « --lang=<code> » (arguments après --) ou TREE_LANG, sinon "".
static func forced_locale() -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--lang="):
			return a.substr(7)
	return OS.get_environment("TREE_LANG")


## Langue affichée : celle forcée par les tests, sinon le choix du joueur (ou celle du système).
func effective_locale() -> String:
	var f := forced_locale()
	return Loc.resolve(f if f != "" else locale)


## Applique la langue : changement à chaud, sans redémarrer.
func apply_locale() -> void:
	Loc.apply(effective_locale())


## Change la langue ("" = langue du système) et l'applique aussitôt.
func set_locale(id: String) -> void:
	locale = id if id == "" or id == Loc.PSEUDO or id in Loc.LOCALES else ""
	apply_locale()
	changed.emit()


## Change la difficulté : vaut pour les ennemis qui naissent ensuite.
func set_difficulty(id: String) -> void:
	difficulty = id if id in DIFFICULTIES else "normal"
	changed.emit()


## Change le mode de déplacement (voir MOVE_MODES).
func set_move_mode(id: String) -> void:
	move_mode = id if id in MOVE_MODES else MOVE_MODE_DEFAULT
	apply_bindings()
	changed.emit()


## Change la visée de l'attaque de base (voir AIM_MODES).
func set_aim_mode(id: String) -> void:
	aim_mode = id if id in AIM_MODES else "auto"
	changed.emit()


## Explication d'une visée, affichée sous le choix dans les options.
static func aim_mode_text(id: String) -> String:
	if id == "curseur":
		return Loc.t("L'attaque de base part toute seule vers la souris, même sans ennemi.")
	return Loc.t("L'attaque de base part toute seule sur l'ennemi à portée le plus proche du curseur. Sans ennemi à portée, elle ne part pas.")


## Explication d'un mode de déplacement, affichée sous le choix dans les options.
func move_mode_text(id: String) -> String:
	match id:
		"moba":
			var key := code_name(moba_main_2_key)
			return tr("Clic droit : le héros marche jusqu'à l'endroit cliqué (un repère s'affiche au sol) ; clic droit tenu : il suit le curseur. La compétence du clic droit passe sur %s ; Espace reste l'esquive, vers le curseur.") % key
		"curseur":
			return tr("Le héros marche vers la souris et s'arrête quand elle est tout près de lui. L'attaque part toute seule ; clic gauche et clic droit lancent les compétences vers le curseur. L'esquive part vers le curseur.")
	return tr("Z Q S D (W A S D en QWERTY) ou les flèches. L'attaque part toute seule ; clic gauche et clic droit lancent les compétences vers le curseur.")


## Force réellement appliquée de la secousse d'écran (0 si les effets sont réduits).
func shake_strength() -> float:
	return 0.0 if reduce_effects else shake_scale


## Force réellement appliquée des éclats lumineux (0 si les effets sont réduits).
func flash_strength() -> float:
	return 0.0 if reduce_effects else flash_scale


## Part réellement appliquée de la durée des arrêts sur image (0 si les effets sont réduits).
func hitstop_strength() -> float:
	return 0.0 if reduce_effects else hitstop_scale


# --- Manette ---

## Suit l'appareil de la dernière entrée (voir last_device) : un bouton ou un stick franchement
## poussé passe à la manette, une touche, un clic ou un vrai mouvement de souris au clavier.
func _input(event: InputEvent) -> void:
	var dev := ""
	if event is InputEventJoypadButton and event.pressed:
		dev = "manette"
	elif event is InputEventJoypadMotion and absf(event.axis_value) > 0.5:
		dev = "manette"
	elif (event is InputEventKey or event is InputEventMouseButton) and event.pressed:
		dev = "clavier"
	elif event is InputEventMouseMotion and event.relative.length() > 6.0:
		dev = "clavier"
	if dev == "manette":
		var n := Input.get_joy_name(event.device)
		if n != pad_name:
			pad_name = n
			if dev == last_device:
				device_changed.emit()
	if dev != "" and dev != last_device:
		set_device(dev)


## Change l'appareil courant (aussi pour les tests et les captures). À la manette, le pointeur de
## la souris se cache ; il revient au premier mouvement de souris.
func set_device(dev: String) -> void:
	last_device = "manette" if dev == "manette" else "clavier"
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_HIDDEN if last_device == "manette" else Input.MOUSE_MODE_VISIBLE
	device_changed.emit()


func pad_active() -> bool:
	return last_device == "manette"


## Style des glyphes réellement utilisé : « xbox » ou « playstation ».
func pad_layout() -> String:
	if pad_style != "auto":
		return pad_style
	var n := pad_name.to_lower()
	for w in ["playstation", "dualsense", "dualshock", "ps3", "ps4", "ps5", "sony"]:
		if w in n:
			return "playstation"
	return "xbox"


func set_pad_style(id: String) -> void:
	pad_style = id if id in PAD_STYLES else "auto"
	changed.emit()
	device_changed.emit()


const PAD_NAMES_XBOX := {JOY_BUTTON_A: "A", JOY_BUTTON_B: "B", JOY_BUTTON_X: "X", JOY_BUTTON_Y: "Y", # i18n
	JOY_BUTTON_LEFT_SHOULDER: "LB", JOY_BUTTON_RIGHT_SHOULDER: "RB", JOY_BUTTON_BACK: "Affichage", JOY_BUTTON_START: "Menu", # i18n
	JOY_BUTTON_LEFT_STICK: "Stick G", JOY_BUTTON_RIGHT_STICK: "Stick D", PAD_LT: "LT", PAD_RT: "RT"} # i18n
const PAD_NAMES_PS := {JOY_BUTTON_A: "Croix", JOY_BUTTON_B: "Rond", JOY_BUTTON_X: "Carré", JOY_BUTTON_Y: "Triangle", # i18n
	JOY_BUTTON_LEFT_SHOULDER: "L1", JOY_BUTTON_RIGHT_SHOULDER: "R1", JOY_BUTTON_BACK: "Partage", JOY_BUTTON_START: "Options", # i18n
	JOY_BUTTON_LEFT_STICK: "L3", JOY_BUTTON_RIGHT_STICK: "R3", PAD_LT: "L2", PAD_RT: "R2"}
const PAD_NAMES_COMMON := {JOY_BUTTON_DPAD_UP: "Croix haut", JOY_BUTTON_DPAD_DOWN: "Croix bas", JOY_BUTTON_DPAD_LEFT: "Croix gauche", # i18n
	JOY_BUTTON_DPAD_RIGHT: "Croix droite", JOY_BUTTON_PADDLE1: "Palette 1", JOY_BUTTON_PADDLE2: "Palette 2", # i18n
	JOY_BUTTON_PADDLE3: "Palette 3", JOY_BUTTON_PADDLE4: "Palette 4", PAD_STICK_L: "Stick gauche", PAD_STICK_R: "Stick droit", # i18n
	PAD_DPAD: "Croix directionnelle"} # i18n


## Nom affiché d'une liaison de manette, selon le style des glyphes (« RT » ou « R2 »).
func pad_name_of(code: int) -> String:
	if code == JOY_BUTTON_INVALID:
		return "—"
	var names: Dictionary = PAD_NAMES_PS if pad_layout() == "playstation" else PAD_NAMES_XBOX
	if names.has(code):
		return tr(names[code])
	return tr(PAD_NAMES_COMMON[code]) if PAD_NAMES_COMMON.has(code) else tr("Bouton %d") % code


## Liaison de manette d'une commande : emplacement de la barre (« skill_main_1 »…) ou commande du jeu.
func pad_code(action: String) -> int:
	var i := SLOT_ACTIONS.find(action)
	if i >= 0:
		return pad_bindings[i]
	if action in ["move_up", "move_left", "move_down", "move_right"]:
		return PAD_STICK_L
	if action == "pause":
		return JOY_BUTTON_START
	return pad_actions.get(action, JOY_BUTTON_INVALID)


## Commande (barre ou jeu) qui utilise déjà ce bouton de manette, hors `except`, ou "".
func pad_user(code: int, except := "") -> String:
	for a in PAD_ACTIONS:
		if a != except and pad_actions[a] == code:
			return tr(GAME_ACTION_NAMES[a])
	for i in SLOT_COUNT:
		if SLOT_ACTIONS[i] != except and pad_bindings[i] == code:
			return tr("compétence %d") % (i + 1)
	return ""


## Réassigne la manette d'un emplacement de la barre (JOY_BUTTON_INVALID pour l'enlever). Renvoie ""
## ou le nom de la commande du jeu qui tient déjà ce bouton ; un autre emplacement le perd.
func set_pad_binding(i: int, code: int) -> String:
	if i < 0 or i >= SLOT_COUNT or (code != JOY_BUTTON_INVALID and not code in PAD_BUTTONS):
		return "?"
	for a in PAD_ACTIONS:
		if pad_actions[a] == code:
			return tr(GAME_ACTION_NAMES[a])
	for j in SLOT_COUNT:
		if j != i and pad_bindings[j] == code:
			pad_bindings[j] = JOY_BUTTON_INVALID
	pad_bindings[i] = code
	apply_bindings()
	changed.emit()
	return ""


## Réassigne le bouton de manette d'une commande du jeu (esquive, arbre, carte). Refusé (renvoie le
## nom de la commande qui l'utilise) si le bouton est déjà pris.
func set_pad_action(a: String, code: int) -> String:
	if not a in PAD_ACTIONS or not code in PAD_BUTTONS:
		return "?"
	var user := pad_user(code, a)
	if user != "":
		return user
	pad_actions[a] = code
	apply_bindings()
	changed.emit()
	return ""


## Liaison de manette lue dans un évènement (bouton pressé, ou gâchette enfoncée), ou JOY_BUTTON_INVALID.
static func pad_code_of(event: InputEvent) -> int:
	var b := event as InputEventJoypadButton
	if b != null and b.pressed:
		return b.button_index
	var m := event as InputEventJoypadMotion
	if m != null and (m.axis == JOY_AXIS_TRIGGER_LEFT or m.axis == JOY_AXIS_TRIGGER_RIGHT) and m.axis_value > 0.6:
		return PAD_AXIS + m.axis
	return JOY_BUTTON_INVALID


## Vecteur d'un stick (« move » ou « aim »), zone morte comprise (0 sous STICK_DEADZONE).
static func stick(which: String) -> Vector2:
	if which == "aim":
		return Input.get_vector("aim_left", "aim_right", "aim_up", "aim_down") if InputMap.has_action("aim_left") else Vector2.ZERO
	return Input.get_vector("move_left", "move_right", "move_up", "move_down")
