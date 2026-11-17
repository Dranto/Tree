## Interface en jeu : vie, expérience, points à placer, compétences et état du monde.
## Construite en nœuds Control ancrés aux bords : elle suit la taille de la fenêtre.
extends Control

const UiTheme = preload("res://scripts/ui_theme.gd")
const Content = preload("res://scripts/content.gd")
const DeathScreen = preload("res://scripts/death_screen.gd")

## Part du monde qu'il est possible de raviver (disque de l'arbre sur la carte carrée).
const REVIVABLE := 0.67
## Emplacements de compétences : toujours MAX_SLOTS affichés, dont skill_slots débloqués
## (4 au départ) ; un emplacement vide est « libre », un emplacement pas encore débloqué « verrouillé ».
const MAX_SLOTS := 6
const MARGIN := 20

## Durée d'affichage d'une annonce (s), dont une seconde de fondu à la fin.
const BANNER_TIME := 3.0
## Une annonce de combat attend au plus ce temps qu'une annonce ordinaire ait été lue.
const BANNER_MIN := 1.2
## Durée maximale de l'aide de départ (s) ; elle s'efface plus tôt dès qu'elle a servi.
const HINT_TIME := 12.0
## Un ennemi à moins de cette distance du joueur (pixels du monde) : le combat commence, l'aide s'efface.
const HINT_ENEMY_NEAR := 420.0

var main
var banner_text := ""
var banner_time := 0.0
## Sorte de l'annonce affichée : « info » (objectifs, points, niveaux…) ou « combat ».
var banner_kind := "info"
## Annonces en attente, dans l'ordre : [texte, sorte]. Une seule annonce est visible à la fois.
## Pendant un combat de boss et l'écran de mort, les annonces ordinaires attendent la fin.
var banner_queue: Array = []
var hint_time := HINT_TIME
## Aide de départ : le joueur s'est déplacé, a tiré (les deux gestes qu'elle enseigne).
var _hint_moved := false
var _hint_shot := false
var _hint_start = null

var _labels := {}
var _corner
var _vital
var _banner: Label
var _hint_box: VBoxContainer
var _slots: Array = []
## Écran de mort et flèche vers la sève perdue (death_screen.gd).
var death_screen


const Widgets = preload("res://scripts/hud_widgets.gd")


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = UiTheme.make()
	_build_top_left()
	_build_bottom_left()
	_build_bottom_center()
	_build_banner()
	death_screen = DeathScreen.new()
	death_screen.main = main
	add_child(death_screen)
	Settings.changed.connect(func(): _labels.clear())
	Game.points_granted.connect(_on_points_granted)
	Game.graft_found.connect(_on_graft_found)
	_refresh()


## Affiche une annonce en haut de l'écran, ou la met dans la file si une autre est visible.
## « kind » : « combat » pour les annonces d'un combat en cours (boss, siège du Cœur), qui passent
## devant les autres ; « info » pour le reste, qui attend la fin d'un combat de boss.
func banner(s: String, kind := "info") -> void:
	if (banner_text == s and banner_time > 0.0) or banner_queue.any(func(b): return b[0] == s):
		return
	if kind == "combat":
		# Devant les annonces ordinaires en attente, derrière les autres annonces de combat.
		var at := 0
		while at < banner_queue.size() and banner_queue[at][1] == "combat":
			at += 1
		banner_queue.insert(at, [s, kind])
	else:
		banner_queue.append([s, kind])
	_next_banner()


## Les annonces ordinaires attendent : combat de boss (seules les informations du combat restent)
## ou écran de mort.
func holds_info() -> bool:
	return in_boss_fight() or (death_screen != null and death_screen.is_showing())


func in_boss_fight() -> bool:
	return main != null and main.get("arena") != null and main.arena.in_combat()


## Passe à l'annonce suivante quand celle qui est affichée a fait son temps. Une annonce de
## combat abrège une annonce ordinaire déjà lue.
func _next_banner() -> void:
	if banner_queue.is_empty():
		return
	var showing := banner_time > 0.2
	if death_screen != null and death_screen.is_showing():
		return
	var pick := -1
	for i in banner_queue.size():
		if banner_queue[i][1] == "combat" or not holds_info():
			pick = i
			break
	if pick < 0:
		return
	if showing:
		var urgent: bool = banner_queue[pick][1] == "combat" and banner_kind != "combat"
		if not urgent or BANNER_TIME - banner_time < BANNER_MIN:
			return
	var b: Array = banner_queue.pop_at(pick)
	banner_text = b[0]
	banner_kind = b[1]
	banner_time = BANNER_TIME


## Retire les annonces de combat en attente (le combat vient de se finir par une mort).
func drop_combat_banners() -> void:
	banner_queue = banner_queue.filter(func(b): return b[1] != "combat")
	if banner_kind == "combat":
		banner_time = minf(banner_time, 0.0)


## Annonce visible à l'écran (texte vide s'il n'y en a pas).
func visible_banner() -> String:
	return banner_text if banner_time > 0.0 and _banner.visible else ""


## Vrai quand aucune annonce n'est affichée ni en attente.
func banners_idle() -> bool:
	return banner_time <= 0.0 and banner_queue.is_empty()


## L'aide de départ est-elle à l'écran ?
func hint_visible() -> bool:
	return _hint_box.visible and _hint_box.modulate.a > 0.01


## Écran de mort (voir death_screen.gd et main.player_died).
func show_death(info: Dictionary) -> void:
	# Rien par-dessus l'écran de mort : une annonce ordinaire pas encore lue reprendra ensuite.
	if banner_time > 1.0 and banner_kind != "combat":
		banner_queue.push_front([banner_text, banner_kind])
	banner_time = 0.0
	_banner.visible = false
	death_screen.show_death(info)
## Points d'arbre gagnés hors niveau : la source et le nombre de points.
func _on_points_granted(n: int, source: String) -> void:
	banner("%s : +%d point%s de l'Arbre de vie (%s)" % [Game.point_source_label(source), n, "s" if n > 1 else "", key_label("toggle_tree")])


func _on_graft_found(id: String) -> void:
	var g: Dictionary = Content.grafts().get(id, {})
	banner("Greffe trouvée : %s. Pose-la dans l'Arbre de vie (%s)" % [g.get("name", id), key_label("toggle_tree")])


## Nom de la touche selon la disposition du clavier du joueur (Z sur AZERTY pour « avancer »).
## Première ligne de l'aide de départ : se déplacer (selon le mode choisi dans les options), attaque
## automatique, compétences des clics, esquive.
func move_hint_line() -> String:
	var dash := key_label("dash")
	var skills := "%s et %s : compétences" % [Settings.binding_name(0), Settings.binding_name(1).to_lower() if Settings.binding_is_mouse(1) else Settings.binding_name(1)]
	match Settings.move_mode:
		"curseur":
			return "La souris guide le héros   ·   L'attaque part toute seule   ·   %s   ·   %s : esquive" % [skills, dash]
		"moba":
			return "Clic droit : marcher jusqu'au point   ·   L'attaque part toute seule   ·   %s   ·   %s : esquive" % [skills, dash]
	return "%s %s %s %s : se déplacer   ·   L'attaque part toute seule   ·   %s   ·   %s : esquive" % [key_label("move_up"), key_label("move_left"), key_label("move_down"), key_label("move_right"), skills, dash]


func key_label(action: String) -> String:
	if _labels.has(action):
		return _labels[action]
	var label := "?"
	if InputMap.has_action(action):
		for ev in InputMap.action_get_events(action):
			var key_ev := ev as InputEventKey
			if key_ev:
				var kc := key_ev.physical_keycode
				if DisplayServer.get_name() != "headless":
					kc = DisplayServer.keyboard_get_keycode_from_physical(kc)
				label = OS.get_keycode_string(kc)
				break
	_labels[action] = label
	return label


func _label(parent: Node, size_px: int, color: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size_px)
	l.add_theme_color_override("font_color", color)
	parent.add_child(l)
	return l


func _build_top_left() -> void:
	# Pas de cadre : le coin n'est qu'un médaillon et trois repères sur le jeu.
	_corner = Widgets.Corner.new()
	_corner.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT, Control.PRESET_MODE_MINSIZE, MARGIN)
	add_child(_corner)


func _build_bottom_left() -> void:
	_vital = Widgets.Vital.new()
	_vital.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, MARGIN)
	_vital.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(_vital)


func _build_bottom_center() -> void:
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.alignment = BoxContainer.ALIGNMENT_END
	v.add_theme_constant_override("separation", 10)
	v.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, MARGIN)
	v.grow_horizontal = Control.GROW_DIRECTION_BOTH
	v.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(v)
	_hint_box = VBoxContainer.new()
	_hint_box.add_theme_constant_override("separation", 4)
	v.add_child(_hint_box)
	for i in 2:
		var l := _label(_hint_box, 16, Color(0.9, 0.95, 0.85))
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 6)
	v.add_child(row)
	for i in MAX_SLOTS:
		var s := Widgets.Slot.new()
		s.index = i
		s.gui_input.connect(_on_slot_input.bind(i))
		row.add_child(s)
		_slots.append(s)


## Clic sur un emplacement débloqué : y mettre une compétence acquise restée sans place.
func _on_slot_input(event: InputEvent, i: int) -> void:
	var mb := event as InputEventMouseButton
	if mb and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT and main and main.player:
		main.player.cycle_slot(i)


## Commandes d'un emplacement : la liaison choisie dans les options et le chiffre
## (« Clic gauche », « A · 1 »).
func slot_keys_text(i: int) -> String:
	var name := Settings.binding_name(i)
	var digit: int = Settings.SLOT_DIGITS[i]
	if digit == KEY_NONE:
		return name
	var d := Settings.key_name(digit)
	return d if Settings.effective_binding(i) == KEY_NONE else "%s · %s" % [name, d]


func _build_banner() -> void:
	_banner = Label.new()
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.add_theme_font_size_override("font_size", 24)
	_banner.add_theme_color_override("font_color", Color(0.95, 0.92, 0.75))
	# Le cadre épouse le texte, centré : un cadre pleine largeur passait sous le suivi des
	# objectifs (en haut à droite) et l'audit d'interface y voyait un chevauchement.
	_banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_banner.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_banner.offset_top = 140
	_banner.offset_bottom = 180
	add_child(_banner)


func _process(delta: float) -> void:
	banner_time -= delta
	# Une annonce ordinaire en cours s'efface vite quand un combat de boss commence ou à la mort.
	if banner_kind != "combat" and holds_info() and banner_time > 0.4:
		banner_time = 0.4
	_next_banner()
	hint_time -= delta
	_update_hint()
	_refresh()


## L'aide de départ s'efface dès qu'elle a servi (le joueur s'est déplacé et a tiré), qu'un
## combat commence (ennemi proche, coup reçu, siège du Cœur, boss) ou que l'Arbre est ouvert.
func _update_hint() -> void:
	if hint_time <= 0.0 or main == null or main.player == null:
		return
	var p = main.player
	if _hint_start == null:
		_hint_start = p.position
	if p.position.distance_to(_hint_start) > 60.0:
		_hint_moved = true
	if p.fire_cd > 0.0:
		_hint_shot = true
	var fight: bool = in_boss_fight() or p.hurt_flash > 0.0 or (main.heart != null and main.heart.state == "siege")
	if not fight:
		for e in main.enemies_near(p.position, HINT_ENEMY_NEAR):
			fight = true
			break
	var done: bool = (_hint_moved and _hint_shot) or fight or Game.allocated.size() > 1
	if done:
		hint_time = minf(hint_time, 0.5)


func _refresh() -> void:
	if main == null or main.player == null:
		return
	var s: Dictionary = Game.stats
	var p = main.player
	var hp_ratio: float = clampf(p.hp / s["max_hp"], 0.0, 1.0)
	_vital.set_value(hp_ratio, "%d / %d" % [roundi(p.hp), roundi(s["max_hp"])])
	var revived := minf(1.0, main.ground.ratio() / REVIVABLE)
	_corner.set_values(Game.level, clampf(Game.xp / Game.xp_to_next(), 0.0, 1.0), Game.points, key_label("toggle_tree"), revived, Game.kills)

	var open: int = p.unlocked_slots()
	for s2 in _slots:
		var slot := s2 as Widgets.Slot
		var i: int = slot.index
		var id: String = p.bar[i] if i < p.bar.size() else ""
		if i >= open:
			slot.name_label.text = "verrouillé"
			slot.apply(Widgets.Slot.LOCKED, "", 0.0, 0.0, "", "")
		elif id == "":
			slot.name_label.text = "libre"
			slot.apply(Widgets.Slot.FREE, "", 0.0, 0.0, slot_keys_text(i), "Emplacement libre")
		else:
			var k: Dictionary = Content.skills()[id]
			var cd: float = p.cds.get(id, 0.0)
			var maxcd: float = maxf(0.01, p.skill_cd.get(id, 1.0))
			slot.name_label.text = k.get("short", id)
			slot.apply(Widgets.Slot.SKILL, id, cd / maxcd if cd > 0.0 else 0.0, cd, slot_keys_text(i), "%s\n%s" % [k.get("name", id), k.get("desc", "")])

	if _banner.text != banner_text:
		_banner.text = banner_text
		var w := _banner.get_minimum_size().x
		_banner.offset_left = -w / 2.0
		_banner.offset_right = w / 2.0
	_banner.modulate.a = clampf(banner_time, 0.0, 1.0)
	_banner.visible = banner_time > 0.0

	# Pendant le combat de boss, seules les informations du combat restent (vie, compétences, barre du boss).
	_corner.visible = not in_boss_fight()

	var show_hint := hint_time > 0.0 and Settings.show_hints and not in_boss_fight()
	_hint_box.modulate.a = clampf(hint_time / 2.0, 0.0, 1.0) if show_hint else 0.0
	_hint_box.visible = show_hint
	var lines := [
		move_hint_line(),
		"%s : ouvrir l'Arbre de vie. Chaque nœud appris ravive une région du monde." % key_label("toggle_tree"),
	]
	for i in 2:
		(_hint_box.get_child(i) as Label).text = lines[i]
