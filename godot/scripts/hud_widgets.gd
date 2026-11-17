## Éléments dessinés de l'interface en jeu : emplacement de compétence, barre de vie et repères du coin.
## Tout est vectoriel (charte graphique : Art, Anim) ; hud.gd les assemble et leur donne les valeurs.
extends RefCounted

const UiTheme = preload("res://scripts/ui_theme.gd")


## Un emplacement de la barre de compétences : médaillon d'icône, recharge en arc, touche.
## Trois états : une compétence, « libre » (débloqué, sans compétence : un simple anneau discret)
## et « verrouillé » (pas encore débloqué : masqué, il apparaît quand l'Arbre l'ouvre).
class Slot extends Control:
	enum { SKILL, FREE, LOCKED }
	## Diamètre du médaillon : les deux emplacements « souris » sont plus gros que les secondaires.
	const SIZE := 56.0
	const SIZE_MOUSE := 66.0
	## Genre de l'emplacement : touche du clavier, clic gauche ou clic droit de la souris.
	enum { KEY, MOUSE_LEFT, MOUSE_RIGHT }
	var kind := KEY
	## Emplacement « souris » dont l'entrée est une touche (mode MOBA) : il s'affiche avec sa touche.
	var as_key := false
	## Demande d'échange de deux emplacements (glisser-déposer) : de, vers.
	signal swap_requested(from: int, to: int)
	var diam := SIZE
	var index := 0
	var state := LOCKED
	var skill_id := ""
	var ratio := 0.0
	var seconds := 0.0
	var key_text := ""
	## Temps écoulé depuis la fin de la recharge (éclat « prête »), et depuis l'apparition.
	var ready_t := 1.0
	var born_t := 1.0
	var _was_skill := false
	## Libellés lus par les tests ; le nom complet est dans l'infobulle.
	var name_label := Label.new()
	var key_label := Label.new()

	func _init() -> void:
		custom_minimum_size = Vector2(SIZE + 8.0, SIZE + 24.0)
		mouse_filter = Control.MOUSE_FILTER_STOP

	## Fixe le genre (et donc la taille) de l'emplacement.
	func set_kind(k: int) -> void:
		kind = k
		diam = SIZE_MOUSE if k != KEY else SIZE
		custom_minimum_size = Vector2(diam + 8.0, diam + (34.0 if k != KEY else 24.0))
		queue_redraw()

	func apply(new_state: int, id: String, new_ratio: float, secs: float, keys: String, tip: String) -> void:
		if new_state == SKILL and not _was_skill:
			born_t = 0.0
		if state == SKILL and new_state == SKILL and ratio > 0.0 and new_ratio <= 0.0:
			ready_t = 0.0
		_was_skill = new_state == SKILL
		state = new_state
		skill_id = id
		ratio = new_ratio
		seconds = secs
		key_text = keys
		tooltip_text = tip
		visible = state != LOCKED
		queue_redraw()

	## Glisser une compétence : l'emplacement d'arrivée échange sa compétence avec celle-ci.
	func _get_drag_data(_at: Vector2) -> Variant:
		if state != SKILL:
			return null
		var preview := Control.new()
		var badge := Control.new()
		badge.custom_minimum_size = Vector2(SIZE, SIZE)
		badge.size = Vector2(SIZE, SIZE)
		badge.position = -badge.size / 2.0
		badge.draw.connect(func(): Art.icon_badge(badge, skill_id, Rect2(Vector2.ZERO, Vector2(SIZE, SIZE))))
		preview.add_child(badge)
		set_drag_preview(preview)
		return {"slot": index}

	func _can_drop_data(_at: Vector2, data: Variant) -> bool:
		return state != LOCKED and data is Dictionary and data.has("slot") and int(data["slot"]) != index

	func _drop_data(_at: Vector2, data: Variant) -> void:
		swap_requested.emit(int(data["slot"]), index)

	func _process(delta: float) -> void:
		if ready_t < 1.0 or born_t < 1.0:
			ready_t += delta
			born_t += delta
			queue_redraw()

	func _draw() -> void:
		var font := UiTheme.font(true)
		var c := Vector2(size.x / 2.0, diam / 2.0 + 2.0)
		var r := diam / 2.0
		match state:
			FREE:
				# Débloqué mais vide : un anneau pointillé, presque invisible.
				for i in 16:
					var a := TAU * i / 16.0
					draw_arc(c, r * 0.8, a, a + TAU / 32.0, 4, Color(Art.c("texte_doux"), 0.35), 1.5, true)
			SKILL:
				var grow := Anim.pop(born_t / Anim.DUREE["apparition"]) if born_t < 1.0 else 1.0
				var col := Art.icon_color(skill_id)
				var rr := r * clampf(grow, 0.0, 1.2)
				var rect := Rect2(c - Vector2(rr, rr), Vector2(rr, rr) * 2.0)
				Art.icon_badge(self, skill_id, rect)
				if ratio > 0.0:
					# Recharge : voile sombre qui se retire dans le sens des aiguilles d'une montre,
					# puis anneau coloré qui se referme.
					var pts := PackedVector2Array([c])
					var a0 := -PI / 2.0
					var start := a0 + TAU * (1.0 - ratio)
					var n := maxi(int(48.0 * ratio), 2)
					for i in n + 1:
						pts.append(c + Vector2.from_angle(start + TAU * ratio * i / n) * rr * 0.9)
					# Le voile couvre la part restante, de « start » jusqu'en haut.
					var veil := Color(0.03, 0.04, 0.04, 0.62)
					if ratio > 0.995:
						draw_circle(c, rr * 0.9, veil)
					elif ratio > 0.01:
						draw_colored_polygon(pts, veil)
					draw_arc(c, rr + 3.0, a0, a0 + TAU * (1.0 - ratio), 48, Color(col, 0.9), 2.5, true)
					if seconds >= 0.1:
						var txt := "%d" % ceili(seconds) if seconds >= 1.0 else "%.1f" % seconds
						var fs := 20
						var w := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_CENTER, -1, fs).x
						var p := Vector2(c.x - w / 2.0, c.y + fs * 0.36)
						draw_string(font, p + Vector2(1.5, 1.5), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0, 0, 0, 0.85))
						draw_string(font, p, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Art.c("texte"))
				if ready_t < 0.35:
					# Prête : un éclair d'anneau qui s'élargit.
					var k := ready_t / 0.35
					draw_arc(c, rr + 3.0 + 8.0 * Anim.ease_out(k), 0.0, TAU, 48, Color(col.lerp(Color.WHITE, 0.5), 1.0 - k), 3.0 * (1.0 - k) + 1.0, true)
		if state != LOCKED and kind != KEY and not as_key:
			# Clic de la souris : une petite souris dont le bouton utilisé est allumé.
			var on2 := state == SKILL
			var m := Vector2(size.x / 2.0, diam + 16.0)
			var body_r := Rect2(m + Vector2(-10.0, -13.0), Vector2(20.0, 28.0))
			var ink := Art.c("texte") if on2 else Art.c("texte_doux")
			var shell := StyleBoxFlat.new()
			shell.bg_color = Color(Art.c("contour"), 0.9)
			shell.border_color = Color(ink, 0.95)
			shell.set_border_width_all(2)
			shell.set_corner_radius_all(9)
			draw_style_box(shell, body_r)
			# Le bouton utilisé est rempli d'or, l'autre reste vide.
			var btn := StyleBoxFlat.new()
			btn.bg_color = Color(Art.c("or"), 0.95 if on2 else 0.55)
			btn.set_corner_radius_all(0)
			if kind == MOUSE_LEFT:
				btn.corner_radius_top_left = 8
			else:
				btn.corner_radius_top_right = 8
			var bx := body_r.position.x + (2.0 if kind == MOUSE_LEFT else 10.0)
			draw_style_box(btn, Rect2(Vector2(bx, body_r.position.y + 2.0), Vector2(8.0, 10.0)))
			draw_line(body_r.position + Vector2(10.0, 2.0), body_r.position + Vector2(10.0, 12.0), Color(ink, 0.95), 1.5)
			draw_line(body_r.position + Vector2(2.0, 12.0), body_r.position + Vector2(18.0, 12.0), Color(ink, 0.95), 1.5)
		elif state != LOCKED and key_text != "":
			# Touche : une petite plaque sous le médaillon.
			var fs2 := 13
			var w2 := font.get_string_size(key_text, HORIZONTAL_ALIGNMENT_CENTER, -1, fs2).x
			var plate := Rect2(Vector2(size.x / 2.0 - w2 / 2.0 - 6.0, diam + 6.0), Vector2(w2 + 12.0, 17.0))
			var on := state == SKILL
			draw_rect(plate, Color(Art.c("contour"), 0.85 if on else 0.5))
			draw_rect(plate, Color(Art.c("texte_doux"), 0.7 if on else 0.3), false, 1.0)
			draw_string(font, plate.position + Vector2(6.0, 13.0), key_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2,
				Art.c("texte") if on else Art.c("texte_doux"))


## Barre de vie : plaque arrondie, remplissage, traînée claire qui rattrape les dégâts, chiffres.
class Vital extends Control:
	var ratio := 1.0
	var ghost := 1.0
	var text := ""
	var flash := 0.0
	var _prev := 1.0

	func _init() -> void:
		custom_minimum_size = Vector2(300, 26)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func set_value(v: float, label: String) -> void:
		if v < _prev - 0.001:
			flash = 1.0
		_prev = v
		ratio = v
		text = label
		if ghost < ratio:
			ghost = ratio
		queue_redraw()

	func _process(delta: float) -> void:
		if flash > 0.0:
			flash = maxf(0.0, flash - delta / 0.25)
		if ghost > ratio:
			ghost = maxf(ratio, ghost - delta * 0.35)
		queue_redraw()

	func _draw() -> void:
		var back := Rect2(Vector2(22, 3), Vector2(size.x - 22, size.y - 6))
		draw_rect(back.grow(2.0), Art.c("contour"))
		draw_rect(back, Color(0.16, 0.05, 0.06))
		if ghost > ratio:
			draw_rect(Rect2(back.position, Vector2(back.size.x * ghost, back.size.y)), Color(Art.c("danger_eclair"), 0.55))
		var fill := Color(0.78, 0.25, 0.25).lerp(Color.WHITE, 0.6 * flash)
		var fw := back.size.x * ratio
		draw_rect(Rect2(back.position, Vector2(fw, back.size.y)), fill)
		draw_rect(Rect2(back.position, Vector2(fw, back.size.y * 0.4)), Color(1, 1, 1, 0.12))
		# Cœur de vie, à gauche : l'icône de la charte dans son médaillon.
		Art.icon_badge(self, "vie", Rect2(Vector2(0, 0), Vector2(size.y, size.y)))
		var font := UiTheme.font(true)
		draw_string(font, back.position + Vector2(8, back.size.y - 5), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0, 0, 0, 0.8))
		draw_string(font, back.position + Vector2(7, back.size.y - 6), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Art.c("texte"))


## Coin d'informations : médaillon de niveau cerclé par l'expérience, points à dépenser,
## monde ravivé (anneau) et Flétris purifiés. Peu de texte, des repères.
class Corner extends Control:
	var level := 1
	var xp := 0.0
	var points := 0
	var tree_key := "Tab"
	var world := 0.0
	var kills := 0
	var t := 0.0
	var _prev_points := 0
	var points_t := 1.0
	var _prev_level := 1
	var level_t := 1.0

	func _init() -> void:
		custom_minimum_size = Vector2(210, 66)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func set_values(lv: int, xp_ratio: float, pts: int, key: String, revived: float, k: int) -> void:
		if pts > _prev_points:
			points_t = 0.0
		if lv > _prev_level:
			level_t = 0.0
		_prev_points = pts
		_prev_level = lv
		level = lv
		xp = xp_ratio
		points = pts
		tree_key = key
		world = revived
		kills = k
		queue_redraw()

	func _process(delta: float) -> void:
		t += delta
		points_t += delta
		level_t += delta
		if points > 0 or points_t < 1.0 or level_t < 1.0:
			queue_redraw()

	func _draw() -> void:
		var font := UiTheme.font(true)
		var soft := UiTheme.font(false)
		# Niveau : disque sombre, anneau d'expérience qui se remplit, chiffre au centre.
		var c := Vector2(30, 33)
		var r := 25.0
		var pop := 1.0 + 0.25 * (1.0 - Anim.ease_out(level_t / 0.5)) if level_t < 0.5 else 1.0
		draw_circle(c + Vector2(0, 2), r * pop, Art.c("ombre"))
		draw_circle(c, r * pop, Art.c("contour"))
		draw_circle(c, (r - 3.0) * pop, Color(0.1, 0.16, 0.1))
		draw_arc(c, r - 1.5, 0.0, TAU, 40, Color(0.18, 0.28, 0.18), 3.0, true)
		if xp > 0.0:
			draw_arc(c, r - 1.5, -PI / 2.0, -PI / 2.0 + TAU * clampf(xp, 0.0, 1.0), 48, Art.c("accent"), 3.0, true)
		var lv := str(level)
		var fs := 22 if level < 100 else 16
		var w := font.get_string_size(lv, HORIZONTAL_ALIGNMENT_CENTER, -1, fs).x
		draw_string(font, c + Vector2(-w / 2.0, fs * 0.36), lv, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Art.c("texte"))
		# Points à dépenser : un repère or qui pulse tant qu'il en reste.
		var x := 68.0
		if points > 0:
			var pulse := 0.5 + 0.5 * sin(t * TAU / 1.2)
			var chip := Rect2(Vector2(x, 4), Vector2(size.x - x, 26))
			draw_rect(chip, Color(Art.c("or"), 0.14 + 0.14 * pulse))
			draw_rect(chip, Color(Art.c("or"), 0.55 + 0.4 * pulse), false, 1.5)
			Art.icon(self, "competence", Rect2(chip.position + Vector2(3, 1), Vector2(24, 24)))
			var s1 := "+%d" % points
			draw_string(font, chip.position + Vector2(30, 19), s1, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Art.c("or"))
			var kw := font.get_string_size(s1, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
			draw_string(soft, chip.position + Vector2(36 + kw, 18), tree_key, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Art.c("texte_doux"))
			if points_t < 0.4:
				var k := points_t / 0.4
				draw_rect(chip.grow(6.0 * Anim.ease_out(k)), Color(Art.c("or"), 0.8 * (1.0 - k)), false, 2.0)
		# Monde ravivé (anneau) et Flétris purifiés (cendre).
		var cy := 46.0
		var cr := 8.0
		var wc := Vector2(x + cr, cy)
		draw_arc(wc, cr, 0.0, TAU, 24, Color(0.2, 0.28, 0.2), 3.0, true)
		if world > 0.0:
			draw_arc(wc, cr, -PI / 2.0, -PI / 2.0 + TAU * clampf(world, 0.0, 1.0), 32, Art.ec("seve"), 3.0, true)
		draw_string(soft, Vector2(x + 2 * cr + 6, cy + 5), "%d %%" % roundi(world * 100.0), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Art.c("texte"))
		var kx := x + 80.0
		Art.icon(self, "cendre", Rect2(Vector2(kx, cy - 10), Vector2(20, 20)), Art.c("texte_doux"))
		draw_string(soft, Vector2(kx + 23, cy + 5), str(kills), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Art.c("texte_doux"))
