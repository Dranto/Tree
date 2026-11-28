## Textes des commandes : un seul endroit qui dit « quelle touche fait quoi », lu par l'aide de départ,
## le journal, l'écran titre, les options et la barre de compétences. Les noms viennent de la carte
## des entrées (InputMap) et des réglages (Settings) : changer une touche change tous les textes.
extends RefCounted

const MOUSE_NAMES := {
	MOUSE_BUTTON_LEFT: "Clic gauche", # i18n
	MOUSE_BUTTON_RIGHT: "Clic droit", # i18n
	MOUSE_BUTTON_MIDDLE: "Clic molette", # i18n
}

## Touches par défaut des actions que main.gd crée au lancement de la partie : l'écran titre n'a pas
## encore leurs évènements, mais doit déjà les annoncer.
const DEFAULT_KEYS := {
	"move_up": KEY_W, "move_left": KEY_A, "move_down": KEY_S, "move_right": KEY_D,
	"toggle_tree": KEY_TAB, "dash": KEY_SPACE, "show_stats": KEY_C,
}
## Noms français des touches que Godot nomme en anglais.
const KEY_FR := {KEY_SPACE: "Espace", KEY_SHIFT: "Maj", KEY_ESCAPE: "Échap", KEY_ENTER: "Entrée", KEY_BACKSPACE: "Retour arrière", KEY_CTRL: "Ctrl"} # i18n


## Nom d'une touche physique selon la disposition du clavier (A sur AZERTY pour KEY_Q).
static func key_name(physical_keycode: int) -> String:
	if physical_keycode == KEY_NONE:
		return "—"
	var kc := physical_keycode
	if DisplayServer.get_name() != "headless":
		kc = DisplayServer.keyboard_get_keycode_from_physical(kc)
	return Loc.t(KEY_FR[kc]) if KEY_FR.has(kc) else OS.get_keycode_string(kc)


## Libellé d'un évènement d'entrée : « Clic gauche », « A », « Espace »…
static func event_label(ev: InputEvent) -> String:
	var mb := ev as InputEventMouseButton
	if mb:
		return Loc.t(MOUSE_NAMES[mb.button_index]) if MOUSE_NAMES.has(mb.button_index) else Loc.t("Souris %d") % mb.button_index
	var key_ev := ev as InputEventKey
	if key_ev:
		var kc := key_ev.physical_keycode if key_ev.physical_keycode != KEY_NONE else key_ev.keycode
		return key_name(kc)
	return ""


## Libellés de toutes les entrées d'une action, dans l'ordre. « touche » : les touches avant la souris.
static func action_labels(action: String, keys_first := false) -> Array:
	var out: Array = []
	if not InputMap.has_action(action):
		return out
	var mouse: Array = []
	var keys: Array = []
	for ev in InputMap.action_get_events(action):
		var s := event_label(ev)
		if s == "":
			continue
		if ev is InputEventMouseButton:
			mouse.append(s)
		else:
			keys.append(s)
	out.append_array(keys + mouse if keys_first else mouse + keys)
	return out


## Premier libellé d'une action, ou « ? » si elle n'est pas dans la carte des entrées.
static func action_label(action: String, keys_first := false) -> String:
	var all := action_labels(action, keys_first)
	if not all.is_empty():
		return str(all[0])
	return key_name(DEFAULT_KEYS[action]) if DEFAULT_KEYS.has(action) else "?"


## Les quatre touches de déplacement dans l'ordre « avancer, gauche, reculer, droite » (Z Q S D).
static func move_keys() -> String:
	var parts: Array = []
	for a in ["move_up", "move_left", "move_down", "move_right"]:
		parts.append(action_label(a))
	return " ".join(parts)


## Libellé de la compétence principale n (1 ou 2). En mode MOBA, la compétence 2 passe sur une touche
## (le clic droit sert à marcher) : Settings.binding_name donne déjà la liaison en service.
static func main_label(n: int) -> String:
	return Settings.binding_name(n - 1)


## Première ligne de l'aide de départ : se déplacer et attaquer.
static func move_line() -> String:
	var attack := Loc.t("l'attaque part toute seule") if Settings.aim_mode == "auto" else Loc.t("l'attaque part toute seule vers le curseur")
	match Settings.move_mode:
		"curseur":
			return Loc.t("La souris guide le héros   ·   %s   ·   %s : esquive") % [attack, action_label("dash")]
		"moba":
			return Loc.t("Clic droit : marcher jusqu'au point   ·   %s   ·   %s : esquive") % [attack, action_label("dash")]
	return Loc.t("%s : se déplacer   ·   %s   ·   %s : esquive") % [move_keys(), attack, action_label("dash")]


## Deuxième ligne : les compétences. « Clic gauche et clic droit » ou, en mode MOBA, le clic gauche et la touche.
static func skills_line() -> String:
	var l := main_label(1)
	var r := main_label(2)
	if Settings.move_mode == "moba":
		return Loc.t("%s : compétence 1   ·   %s : compétence 2   ·   %s : compétences secondaires") % [l, r, secondary_keys()]
	return Loc.t("%s et %s : tes deux compétences principales   ·   %s : compétences secondaires") % [l, r, secondary_keys()]


## Touches des compétences secondaires, séparées par des espaces (« A E R F »).
static func secondary_keys() -> String:
	var parts: Array = []
	for i in range(Settings.MOUSE_SLOTS, Settings.SLOT_COUNT):
		parts.append(Settings.binding_name(i))
	return " ".join(parts)


## Lignes du rappel des commandes, sous la forme [touches, action], pour le journal et l'écran titre.
## À la manette, les noms des boutons (« RT », ou « R2 » en style PlayStation).
static func reminder_rows() -> Array:
	if Settings.pad_active():
		return pad_rows()
	var rows: Array = []
	match Settings.move_mode:
		"curseur":
			rows.append([Loc.t("Souris"), Loc.t("Le héros marche vers le curseur")])
		"moba":
			rows.append([Loc.t("Clic droit"), Loc.t("Marcher jusqu'au point cliqué")])
		_:
			rows.append([move_keys(), Loc.t("Se déplacer")])
	rows.append([Loc.t("Automatique"), Loc.t("L'attaque de base part toute seule sur l'ennemi visé")])
	rows.append([main_label(1), Loc.t("Compétence principale 1")])
	rows.append([main_label(2), Loc.t("Compétence principale 2")])
	rows.append([secondary_keys(), Loc.t("Compétences secondaires")])
	rows.append([action_label("dash"), Loc.t("Esquive")])
	rows.append([action_label("toggle_tree"), Loc.t("Arbre de vie")])
	rows.append([action_label("show_stats"), Loc.t("Statistiques (maintenir)")])
	return rows


## Rappel des commandes à la manette.
static func pad_rows() -> Array:
	var sec: Array = []
	for i in range(Settings.MOUSE_SLOTS, Settings.SLOT_COUNT):
		sec.append(Settings.pad_name_of(Settings.pad_bindings[i]))
	return [
		[Settings.pad_name_of(Settings.PAD_STICK_L), Loc.t("Se déplacer")],
		[Settings.pad_name_of(Settings.PAD_STICK_R), Loc.t("Viser (sinon, la cible la plus proche)")],
		[Settings.pad_name_of(Settings.pad_bindings[0]), Loc.t("Compétence principale 1")],
		[Settings.pad_name_of(Settings.pad_bindings[1]), Loc.t("Compétence principale 2")],
		[" ".join(sec), Loc.t("Compétences secondaires")],
		[Settings.pad_name_of(Settings.pad_actions["dash"]), Loc.t("Esquive")],
		[Settings.pad_name_of(Settings.pad_actions["toggle_tree"]), Loc.t("Arbre de vie")],
		[Settings.pad_name_of(Settings.pad_actions["toggle_map"]), Loc.t("Carte")],
		[Settings.pad_name_of(Settings.pad_actions["show_stats"]), Loc.t("Statistiques (maintenir)")],
	]
