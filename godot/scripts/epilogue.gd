## Épilogue de l'aventure (quest_ui.epilogue), après la victoire sur la Flétrissure (finale_arena.gd) :
## le monde entier reverdit, les textes de data/finale.json › epilogue, les statistiques de toute
## l'aventure, puis le générique qui défile (data/finale.json › credits), et enfin « Continuer à
## jouer » ou « Retour au titre ». Tout est dessiné par le code : le ciel, les collines et l'Arbre
## (repris de ending.gd, toutes ses branches en fleurs) et le générique (_draw_credits).
##
## Se déclenche une seule fois : Game.flags["fin_aventure_vue"] (Objectives.ENDING_SEEN) est posé
## dès le début. Même interface que ending.gd pour les tests et les robots : active, begin(main),
## set_time(s), _on_continue(), signal closed.
extends "res://scripts/ending.gd"

const Content = preload("res://scripts/content.gd")

## Instants (secondes) de l'épilogue : titre, texte, statistiques, puis le générique.
const E_TITLE := 3.5
const E_BODY := 5.0
const E_STATS := 7.5
const E_CREDITS := 14.0
## Vitesse du générique (pixels par seconde, pour un écran de 720 px de haut).
const CREDITS_SPEED := 60.0
## Hauteur (part de l'écran) où s'arrête la dernière ligne du générique.
const CREDITS_STOP := 0.4

## Lignes du générique, prêtes à dessiner : [texte, taille (px à 720 de haut), couleur, gras, écart avant].
var credit_lines: Array = []
## Hauteur totale du générique (px à 720 de haut) et instant où il s'arrête (le dernier titre au milieu).
var credits_height := 0.0
var end_time := 30.0
var _end_box: VBoxContainer


func _build() -> void:
	super._build()
	# Les boutons quittent le panneau des statistiques : ils viennent sous le générique, à la fin.
	for b in _right.find_children("*", "Button", true, false):
		b.get_parent().remove_child(b)
		b.queue_free()
	var v: Node = _right.get_child(0)
	for c in v.get_children():
		if c is Label and (c as Label).text == "TA PARTIE":
			(c as Label).text = "TON AVENTURE"
	_end_box = VBoxContainer.new()
	_end_box.add_theme_constant_override("separation", 10)
	_end_box.anchor_left = 0.5
	_end_box.anchor_right = 0.5
	_end_box.anchor_top = 0.62
	_end_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_end_box.grow_vertical = Control.GROW_DIRECTION_END
	add_child(_end_box)
	_continue = UiTheme.button("Continuer à jouer", 260.0)
	_continue.pressed.connect(_on_continue)
	_end_box.add_child(_continue)
	var to_title := UiTheme.button("Retour au titre", 260.0)
	to_title.pressed.connect(Flow.go_title)
	_end_box.add_child(to_title)
	_build_credits()
	_apply()


## Les statistiques de toute l'aventure, lues au début de l'épilogue (avant que le monde reverdisse).
static func collect_adventure_stats(m) -> Array:
	var base: Array = collect_stats(m)
	var out: Array = []
	for pair in base:
		if pair[0] != "Monde ravivé":
			out.append(pair)
	var regions: Array = Regions.ids()
	var done := regions.filter(func(id): return Game.flags.get(Regions.boss_flag(id), false)).size()
	var altars := 0
	var secrets := 0
	for k in Game.flags:
		var key := str(k)
		var on = Game.flags[k]
		if key.ends_with("_vu") or not (on is bool and on):
			continue
		if key.begins_with("autel_"):
			altars += 1
		elif key.begins_with("secret_"):
			secrets += 1
	out.append(["Régions purifiées", "%d / %d" % [done, regions.size()]])
	out.append(["Élites vaincues", str(int(Game.flags.get(Objectives.ELITES, 0)))])
	out.append(["Autels réveillés", str(altars)])
	out.append(["Secrets trouvés", str(secrets)])
	out.append(["Combats contre la Flétrissure", str(int(Game.flags.get("stat_finale_essais", 0)) + 1)])
	for pair in base:
		if pair[0] == "Monde ravivé":
			out.append(pair)
	return out


## Lance l'épilogue : drapeau posé (il ne reviendra pas), le monde entier reverdit, sauvegarde, jeu en pause.
func begin(m, _reg := "") -> void:
	main = m
	region = ""
	texts = Content._load("finale").get("epilogue", {})
	stats = collect_adventure_stats(m)
	all_lush = true
	Game.flags[Objectives.ENDING_SEEN] = true
	_revive_world(m)
	m.save_game()
	for c in get_children():
		remove_child(c)
		c.free()
	_build()
	active = true
	visible = true
	t = 0.0
	_focused = false
	get_tree().paused = true
	Sfx.play("coeur")
	_apply()


## Le monde entier reverdit : la terre de chaque région, et des fleurs aux couleurs des régions.
static func _revive_world(m) -> void:
	if m == null or m.get("ground") == null:
		return
	# Un disque qui déborde du monde, assez fort pour que même les coins soient pleins de vie.
	m.ground.paint(Vector2.ZERO, Regions.WORLD_HALF * 2.0, 6.0)
	m.flora.spawn_patch(Vector2.ZERO, 420.0, 30, Art.ec("seve", "clair"))
	for id in Regions.ids():
		m.ground.set_purified(id, 1.0)
		var tint := Regions.color(Regions.def(id).get("color", "#7fd36b"))
		m.flora.spawn_patch(Regions.center(id), 900.0, 50, tint)


## Lignes du générique, depuis data/finale.json › credits ; « auto » : les régions et les gardiens
## du monde tel qu'il est (n'importe quel nombre de régions).
func _build_credits() -> void:
	credit_lines = []
	credits_height = 0.0
	for entry in Content._load("finale").get("credits", []):
		if not entry is Dictionary:
			continue
		if str(entry.get("title", "")) != "":
			_credit(str(entry["title"]), 44, UiTheme.GOLD, true, 30.0)
			continue
		_credit(str(entry.get("head", "")).to_upper(), 13, Color(0.62, 0.72, 0.62), false, 46.0)
		var lines: Array = entry.get("lines", [])
		match str(entry.get("auto", "")):
			"regions":
				lines = []
				for id in Regions.ids():
					var place := str(Regions.def(id).get("place", id))
					var who := str(Regions.def(id).get("name", id)).replace("Région de ", "").replace("Région d'", "")
					lines.append("%s · %s" % [place.substr(0, 1).to_upper() + place.substr(1), who])
			"bosses":
				lines = []
				for id in Regions.ids():
					lines.append(str(Regions.section(id, "boss").get("name", id)))
				lines.append(str(Content._load("finale").get("boss", {}).get("name", "La Flétrissure")))
		for l in lines:
			_credit(str(l), 21, UiTheme.INK, false, 8.0)
	end_time = E_CREDITS + _scroll_needed() / CREDITS_SPEED


func _credit(text: String, size_px: int, color: Color, bold: bool, gap: float) -> void:
	credits_height += gap + size_px * 1.3
	credit_lines.append([text, size_px, color, bold, gap])


## Défilement (px à 720 de haut) pour que la dernière ligne s'arrête aux deux cinquièmes de l'écran.
func _scroll_needed() -> float:
	return 720.0 * (1.0 - CREDITS_STOP) + credits_height


func _input(event: InputEvent) -> void:
	if not visible or not active:
		return
	var press: bool = (event is InputEventMouseButton and event.pressed) or (event is InputEventKey and event.pressed and not event.echo)
	if press and t < end_time:
		# Un appui passe à l'étape suivante : textes, puis générique, puis la fin.
		if t < E_STATS + 1.4:
			t = E_STATS + 1.4
		elif t < E_CREDITS:
			t = E_CREDITS
		else:
			t = end_time
		_apply()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if not visible:
		return
	t += delta
	# Musique du générique (data/audio.json › regions › generique), sinon la couche lumineuse du monde.
	Music.set_mood(1.0, "generique")
	_apply()
	if t >= end_time and not _focused and is_instance_valid(_continue):
		_focused = true
		_continue.grab_focus()
	queue_redraw()


func _apply() -> void:
	if _title == null or _end_box == null:
		return
	# Les textes et les statistiques s'effacent quand le générique commence.
	var out := 1.0 - clampf((t - E_CREDITS + 1.4) / 1.4, 0.0, 1.0)
	_sub.modulate.a = _fade(E_TITLE) * out
	_title.modulate.a = _fade(E_TITLE) * out
	_body.modulate.a = _fade(E_BODY) * out
	_right.modulate.a = _fade(E_STATS) * out
	_left.visible = out > 0.0
	_right.visible = out > 0.0
	var ended := t >= end_time
	_end_box.visible = ended
	_end_box.modulate.a = clampf((t - end_time) / 0.8, 0.0, 1.0) if ended else 0.0
	for b in _end_box.find_children("*", "Button", true, false):
		(b as Button).disabled = not ended
	queue_redraw()
	UiAudit.begin("fin")
	UiAudit.scan_controls("fin", self)


func _draw() -> void:
	super._draw()
	if t >= E_CREDITS - 1.0:
		_draw_credits()


## Le générique : un voile sombre, puis les lignes qui montent ; la dernière s'arrête au tiers.
func _draw_credits() -> void:
	var s := size
	var u := s.y / 720.0
	var veil := clampf((t - E_CREDITS + 1.0) / 1.5, 0.0, 1.0)
	draw_rect(Rect2(Vector2.ZERO, s), Color(0.02, 0.03, 0.03, 0.55 * veil))
	var scroll := minf((t - E_CREDITS) * CREDITS_SPEED, _scroll_needed())
	var y := s.y + (-maxf(scroll, 0.0)) * u
	var settled := t >= end_time
	for i in credit_lines.size():
		var l: Array = credit_lines[i]
		y += (float(l[4]) + float(l[1]) * 1.3) * u
		var fs := maxi(8, roundi(float(l[1]) * u))
		if y < -40.0 * u or y > s.y + 40.0 * u:
			continue
		var font := UiTheme.font(bool(l[3]))
		# Fondu en haut et en bas de l'écran.
		var edge := clampf(minf(y / (s.y * 0.12), (s.y - y) / (s.y * 0.12)), 0.0, 1.0)
		var col: Color = l[2]
		col.a *= edge * veil
		var pos := Vector2(0.0, y)
		if settled and i == credit_lines.size() - 1:
			UiAudit.draw_text(self, "fin", font, pos, str(l[0]), HORIZONTAL_ALIGNMENT_CENTER, s.x, fs, col)
		else:
			draw_string(font, pos, str(l[0]), HORIZONTAL_ALIGNMENT_CENTER, s.x, fs, col)
	# Une graine qui germe, sous le dernier titre, une fois le générique arrêté.
	if settled:
		var k := clampf((t - end_time) / 1.2, 0.0, 1.0)
		var c := Vector2(s.x * 0.5, s.y * CREDITS_STOP + 44.0 * u)
		Art.glow(self, c, 26.0 * u * k, "seve")
