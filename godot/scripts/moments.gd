## Moments forts (jalon Éclat, tâche A) : impact frames, caméra et ralenti. Nœud de main.gd
## (main.moments). Rien ici ne change le jeu : ni dégâts, ni vie, ni portée, ni recharge. Le
## joueur garde toujours la main (pas de pause, pas d'écran à lire, pas de cinématique).
##
## Noms convenus avec les autres tâches du jalon :
##   impact_frame(force, cibles, style)  « encre » (noir et blanc) ou « region » (couleurs de la région inversées)
##   slowmo(duree, vitesse)              ralenti en rampe (Engine.time_scale), un seul à la fois
##   camera_kick(direction, force)       à-coup de la caméra dans le sens du coup
##   zoom_pulse(force, duree)            zoom bref vers l'impact puis retour doux
##   focus(position, duree)              la caméra cadre un point puis revient au héros
## Un moment plus fort remplace un plus faible en cours, jamais l'inverse.
##
## Dosage : data/feel.json, sections « impact_frame », « camera » et « slowmo ».
## Options du joueur (jalon 11 K) :
##   - Settings.flash_strength() dose l'impact frame ; à 0, elle devient un simple contour lumineux
##     autour des cibles, sans fond ni inversion de l'écran ;
##   - Settings.shake_strength() dose l'à-coup, le zoom et le cadrage ; à 0, la caméra est immobile ;
##   - Settings.hitstop_strength() dose le ralenti ; à 0, le jeu garde sa vitesse.
## Photosensibilité (WCAG 2.3.1) : jamais plus de impact_frame › max_per_second éclairs par seconde ;
## au-delà, l'impact frame perd son alternance, puis n'est plus qu'un contour.
##
## Impact frame : pendant 2 ou 3 images affichées (en temps réel, pas en temps de jeu), un fond uni
## couvre le monde (au-dessus du sol, des décors et des effets, sous le HUD) et les cibles passent
## devant, en silhouette d'une seule couleur (shaders/silhouette.gdshader appliqué à leur propre
## dessin : héros, Flétris, boss, Cœur). Un Flétri qui vient de mourir est redessiné depuis le cache
## des silhouettes (silhouette_cache.gd), puisque son nœud disparaît.
## Sprites cuits (sprite_bake.gd, refonte des personnages) : l'image cuite d'un Flétri passe en
## silhouette par shaders/silhouette_sprite.gdshader (atlas prémultiplié, teinte d'état dans la
## couleur du dessin : un Flétri qui clignote sous le coup garde sa forme), et un Flétri mort est
## redessiné depuis son image cuite (enemy_remains.gd › enemy_frame) quand il en avait une.
extends Node2D

const SilhouetteShader = preload("res://shaders/silhouette.gdshader")
const SilhouetteCache = preload("res://scripts/silhouette_cache.gd")
const SilhouetteSpriteShader = preload("res://shaders/silhouette_sprite.gdshader")
const Sprites = preload("res://scripts/sprite_bake.gd")
const Remains = preload("res://scripts/enemy_remains.gd")
const Content = preload("res://scripts/content.gd")
const Regions = preload("res://scripts/regions.gd")

## Plans de dessin : le fond de l'impact frame au-dessus de tout le monde, les silhouettes devant.
const Z_BACK := 4000
const Z_SIL := 4001
const STYLES := ["encre", "region"]

var main

# --- Impact frame en cours (vide si aucune) ---
## {force, style, seq (variantes « A »/« B »), i (variante affichée), t (secondes réelles),
##  min_time, region, outline (vrai : contour seul), pos}
var _frame := {}
## Nœuds passés en silhouette, avec ce qu'il faut pour les rendre tels quels :
## {node, z, zrel, mats: [[canvas_item, material, use_parent_material]]}.
var _sil: Array = []
## Silhouettes redessinées (Flétri déjà mort) : {kind, pos, r, face}.
var _ghosts: Array = []
var _ghost_node: Node2D
var _mat: ShaderMaterial
## Même rôle pour les images cuites (atlas prémultiplié).
var _ghost_sprites: Node2D
var _mat_sprite: ShaderMaterial
## Instants (secondes réelles) des éclairs de la dernière seconde.
var _flashes: Array = []
## Délai des impact frames de critique lourd (secondes réelles).
var _crit_cd := 0.0
## Chance de critique du dernier coup du joueur (posée par main.player_hit_enemy).
var crit_chance := 0.0
var _rng := RandomNumberGenerator.new()

# --- Ralenti ---
## {t, dur, speed (vitesse visée, option comprise), ramp_in, ramp_out}
var _slow := {}

# --- Caméra ---
var _kick := Vector2.ZERO
var _zoom := {}
var _focus := {}
## Cadrage durable (px écran, réglé par une scène : la Flétrissure qui grandit lève le cadre pour garder
## sa ramure à l'écran). Ce n'est pas une secousse : il reste même à secousses coupées.
var frame_bias := Vector2.ZERO
## Distorsion du dernier coup en cours (final_blow.gd), ou null.
var _warp = null
var _cam_dirty := false

## Horloge en secondes réelles (avance même pendant un arrêt sur image ou un ralenti).
var _clock := 0.0
## Figé (tests visuels) : l'impact frame en cours reste affichée.
var frozen := false

## Compteurs (lus par tests/moments_test.gd).
var impact_frames := 0
var outline_frames := 0
var slowmos := 0
var last_style := ""
var last_seq: Array = []
## Image affichée de l'impact frame en cours : couleurs du fond et des silhouettes (tests).
var shown_back := Color.TRANSPARENT
var shown_sil := Color.TRANSPARENT


func _ready() -> void:
	_rng.seed = 5309  # tirages des moments : toujours les mêmes (parties rejouables)
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Après fx.gd : la secousse de l'image est déjà calculée quand la caméra est posée.
	process_priority = 100
	z_index = Z_BACK
	z_as_relative = false
	_mat = ShaderMaterial.new()
	_mat.shader = SilhouetteShader
	_ghost_node = Node2D.new()
	_ghost_node.z_index = Z_SIL
	_ghost_node.z_as_relative = false
	_ghost_node.material = _mat
	_ghost_node.draw.connect(_draw_ghosts)
	add_child(_ghost_node)
	_mat_sprite = ShaderMaterial.new()
	_mat_sprite.shader = SilhouetteSpriteShader
	_ghost_sprites = Node2D.new()
	_ghost_sprites.z_index = Z_SIL
	_ghost_sprites.z_as_relative = false
	_ghost_sprites.material = _mat_sprite
	_ghost_sprites.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_ghost_sprites.draw.connect(_draw_ghost_sprites)
	add_child(_ghost_sprites)
	if main != null and main.has_signal("elite_killed"):
		main.elite_killed.connect(on_elite_kill)


func _exit_tree() -> void:
	_end_frame()
	if not _slow.is_empty():
		_slow = {}
		Engine.time_scale = 1.0


## Réglage de data/feel.json (section, clé), ou la valeur par défaut.
static func feel(section: String, key: String, default := 0.0) -> float:
	return float(Content.feel().get(section, {}).get(key, default))


## Réglage non numérique de data/feel.json (couleur, table).
static func feel_v(section: String, key: String, default: Variant) -> Variant:
	return Content.feel().get(section, {}).get(key, default)


func _benchmark() -> bool:
	return main != null and "benchmark" in main and main.benchmark


# =============================================================================================
# Impact frames
# =============================================================================================

## Lance une impact frame. force : 0 à 1 (au moins impact_frame › strong : alternance avec la
## variante inverse en « encre »). cibles : nœuds (Node2D) passés en silhouette, ou silhouettes à
## redessiner {kind, pos, r, face} ; le héros et les Flétris proches de la première cible
## s'ajoutent d'eux-mêmes. style : « encre » ou « region » (region_id : la région dont on prend les
## couleurs ; vide, celle où se trouve la première cible). Vrai si elle est lancée.
## hold (> 0) : chaque variante tient « hold » secondes réelles (le dernier coup du boss final), au
## lieu de deux ou trois images.
func impact_frame(force: float, cibles: Array = [], style := "encre", region_id := "", hold := 0.0) -> bool:
	if not style in STYLES or _benchmark() or not is_inside_tree():
		return false
	if not _frame.is_empty() and force <= float(_frame["force"]):
		return false
	_end_frame()
	var at := _first_pos(cibles)
	var outline := Settings.flash_strength() <= 0.0
	var seq: Array = ["A"]
	var strong := force >= feel("impact_frame", "strong", 0.8)
	var frames := int(feel("impact_frame", "frames_strong" if strong else "frames", 3.0 if strong else 2.0))
	frames = clampi(frames, 1, 4)
	if not outline:
		# Photosensibilité : chaque passage d'un fond à l'autre est un éclair.
		var room := _flash_room()
		if room <= 0:
			outline = true
		else:
			var alternate := strong and style == "encre" and room >= 2 and frames >= 3
			seq = []
			for i in (2 if hold > 0.0 else frames):
				seq.append("B" if alternate and i % 2 == 1 else "A")
			_flashes.append(_now())
			if alternate:
				_flashes.append(_now())
	if outline:
		seq = []
		for i in frames:
			seq.append("A")
	if region_id == "" and style == "region":
		region_id = _region_of(at)
	_frame = {"force": force, "style": style, "seq": seq, "i": 0, "t": 0.0,
		"min_time": feel("impact_frame", "min_time", 0.03), "region": region_id, "outline": outline, "pos": at,
		"fresh": true, "hold": hold,
		"per": feel("impact_frame", "frame_time_strong" if strong else "frame_time", 0.09 if strong else 0.06)}
	_collect(cibles, at, outline)
	if outline:
		outline_frames += 1
	else:
		impact_frames += 1
	last_style = style
	last_seq = seq.duplicate()
	_apply_variant()
	return true


## Tirage 0-1 propre aux moments (jamais main.rng : la partie reste rejouable à l'identique).
func _roll() -> float:
	return _rng.randf()


## Vrai pendant une impact frame.
func in_impact_frame() -> bool:
	return not _frame.is_empty()


## Nombre d'éclairs encore permis dans la seconde (photosensibilité).
func _flash_room() -> int:
	var now := _now()
	_flashes = _flashes.filter(func(t): return now - float(t) < 1.0)
	return int(feel("impact_frame", "max_per_second", 3.0)) - _flashes.size()


func _now() -> float:
	return _clock


func _first_pos(cibles: Array) -> Vector2:
	for c in cibles:
		if c is Dictionary and c.has("pos"):
			return c["pos"]
		if c is Node2D and is_instance_valid(c):
			return c.global_position
	if main != null and main.player != null:
		return main.player.position
	return Vector2.ZERO


func _region_of(at: Vector2) -> String:
	if main == null:
		return ""
	if main.has_method("underground") and main.underground():
		return "finale"
	return str(main.region_at(at)) if main.has_method("region_at") else ""


## Le héros, les cibles et les Flétris proches de la première cible.
func _collect(cibles: Array, at: Vector2, outline: bool) -> void:
	var nodes: Array = []
	if main != null and main.player != null:
		nodes.append(main.player)
	for c in cibles:
		if c is Dictionary:
			_ghosts.append(c)
		elif c is Node2D and is_instance_valid(c) and not c in nodes:
			nodes.append(c)
	if main != null and main.has_method("enemies_near"):
		var cap := int(feel("impact_frame", "near_max", 8.0))
		var near: Array = main.enemies_near(at, feel("impact_frame", "near_radius", 340.0), false)
		near.sort_custom(func(a, b): return a.position.distance_squared_to(at) < b.position.distance_squared_to(at))
		for e in near:
			if cap <= 0:
				break
			if is_instance_valid(e) and not e in nodes and not e.is_queued_for_deletion():
				nodes.append(e)
				cap -= 1
	for n in nodes:
		if outline:
			_sil.append({"node": n, "outline_only": true})
		else:
			_lift(n)
	_ghost_node.queue_redraw()
	_ghost_sprites.queue_redraw()


## Passe un nœud devant le fond, en silhouette (lui et ses enfants dessinés).
func _lift(n: Node2D) -> void:
	var entry := {"node": n, "z": n.z_index, "zrel": n.z_as_relative, "mats": []}
	n.z_as_relative = false
	n.z_index = Z_SIL
	var stack: Array = [n]
	while not stack.is_empty():
		var ci = stack.pop_back()
		if ci is CanvasItem:
			entry["mats"].append([ci, ci.material, ci.use_parent_material])
			# Image cuite (atlas prémultiplié) : sa propre silhouette, lue dans la texture.
			ci.material = _mat_sprite if ci.material != null and (ci.material == Sprites.material() or ci.material == Sprites.material(true)) else _mat
		for ch in ci.get_children():
			if ch is CanvasItem:
				stack.append(ch)
	_sil.append(entry)


func _end_frame() -> void:
	for entry in _sil:
		if entry.get("outline_only", false):
			continue
		var n = entry["node"]
		if is_instance_valid(n):
			n.z_index = entry["z"]
			n.z_as_relative = entry["zrel"]
		for m in entry["mats"]:
			if is_instance_valid(m[0]):
				m[0].material = m[1]
				m[0].use_parent_material = m[2]
	_sil = []
	var had := not _ghosts.is_empty()
	_ghosts = []
	if had and _ghost_node != null:
		_ghost_node.queue_redraw()
		_ghost_sprites.queue_redraw()
	if not _frame.is_empty():
		_frame = {}
		queue_redraw()
	shown_back = Color.TRANSPARENT
	shown_sil = Color.TRANSPARENT


## Couleurs de la variante affichée : fond et silhouettes.
func colors(style: String, variant: String, region_id: String) -> Array:
	var paper: Color = Color(str(feel_v("impact_frame", "papier", "#efe6cf")))
	var ink: Color = Color(str(feel_v("impact_frame", "encre", "#140f0c")))
	if style == "region":
		var col := region_color(region_id)
		var back := complement(col)
		return [col, back] if variant == "B" else [back, col]
	return [ink, paper] if variant == "B" else [paper, ink]


## Couleur d'une région pour l'impact frame (impact_frame › region_colors, sinon celle de son fichier).
static func region_color(region_id: String) -> Color:
	var named: Dictionary = feel_v("impact_frame", "region_colors", {})
	if named.has(region_id):
		return Color(str(named[region_id]))
	if region_id != "" and Regions.exists(region_id):
		var spec = Regions.def(region_id).get("color", "")
		if str(spec) != "":
			return Regions.color(spec)
	return Color(str(named.get("defaut", "#e0675e")))


## Couleur complémentaire (teinte opposée), un peu assombrie pour que la silhouette ressorte.
static func complement(col: Color) -> Color:
	var v := clampf(col.v * feel("impact_frame", "region_back_value", 0.82), 0.0, 1.0)
	return Color.from_hsv(fposmod(col.h + 0.5, 1.0), col.s, v)


func _apply_variant() -> void:
	if _frame.is_empty():
		return
	var seq: Array = _frame["seq"]
	var variant: String = seq[mini(int(_frame["i"]), seq.size() - 1)]
	var cols := colors(_frame["style"], variant, _frame["region"])
	var k := clampf(Settings.flash_strength(), 0.0, 1.0)
	if _frame["outline"]:
		shown_back = Color.TRANSPARENT
		shown_sil = Color.TRANSPARENT
	else:
		shown_back = Color(cols[0], k)
		shown_sil = cols[1]
		for m in [_mat, _mat_sprite]:
			m.set_shader_parameter("tint", cols[1])
			m.set_shader_parameter("amount", k)
	queue_redraw()
	_ghost_node.queue_redraw()
	_ghost_sprites.queue_redraw()


func _step_frame(real: float) -> void:
	if _frame.is_empty() or frozen:
		return
	# La première variante est affichée au moins une image entière (lancée dans cette image).
	if _frame["fresh"]:
		_frame["fresh"] = false
		return
	_frame["t"] += real
	# Chaque image dure « per » secondes réelles : « hold » (dernier coup), sinon frame_time
	# (frame_time_strong pour les coups très forts). Trop brèves, elles faisaient un simple flash.
	var per := float(_frame.get("hold", 0.0))
	if per <= 0.0:
		per = float(_frame.get("per", 0.06))
	var at := int(float(_frame["t"]) / maxf(per, 0.001))
	if at >= _frame["seq"].size():
		_end_frame()
	elif at != int(_frame["i"]):
		_frame["i"] = at
		_apply_variant()


func _draw() -> void:
	if _frame.is_empty():
		return
	if _frame["outline"]:
		# Sans éclair : un contour lumineux autour de chaque cible, l'écran reste tel quel.
		var light := Art.c("danger_eclair")
		var w := 3.0 + 2.0 * float(_frame["force"])
		for entry in _sil:
			var n = entry["node"]
			if is_instance_valid(n):
				draw_arc(n.global_position, float(n.get("radius") if n.get("radius") != null else 16.0) + 7.0, 0.0, TAU, 40, Color(light, 0.9), w, true)
		for g in _ghosts:
			draw_arc(g["pos"], float(g.get("r", 16.0)) + 7.0, 0.0, TAU, 40, Color(light, 0.9), w, true)
		return
	if shown_back.a <= 0.0:
		return
	var vp := get_viewport()
	var rect: Rect2 = vp.get_canvas_transform().affine_inverse() * vp.get_visible_rect()
	draw_rect(rect.grow(64.0), shown_back)
	_draw_rays(rect)


## Traits de vitesse : des coins fins qui partent du point d'impact vers les bords, à la couleur
## des silhouettes (le regard va au coup). Tirés d'une graine fixe par impact frame.
func _draw_rays(rect: Rect2) -> void:
	var n := int(feel("impact_frame", "rays", 14.0) * (0.6 + 0.4 * float(_frame["force"])))
	if n <= 0:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 9137 + impact_frames
	var at: Vector2 = _frame["pos"]
	var far := rect.size.length()
	var inner := feel("impact_frame", "rays_inner", 110.0)
	var col := Color(shown_sil, shown_back.a * 0.9)
	for i in n:
		var a := TAU * (i + rng.randf_range(-0.35, 0.35)) / n
		var d := Vector2.from_angle(a)
		var w := rng.randf_range(0.006, 0.02) * far
		var r0 := inner * rng.randf_range(0.9, 1.8)
		draw_colored_polygon(PackedVector2Array([at + d * r0, at + d * far + d.orthogonal() * w, at + d * far - d.orthogonal() * w]), col)


func _draw_ghosts() -> void:
	if _frame.is_empty() or _frame["outline"]:
		return
	for g in _ghosts:
		if str(g.get("kind", "")) == "" or not g.get("sprite", {}).is_empty():
			continue
		_ghost_node.draw_set_transform(g["pos"])
		SilhouetteCache.draw(_ghost_node, str(g["kind"]), float(g.get("r", 14.0)), 0.01,
			g.get("face", Vector2.RIGHT), 0.0, {})
	_ghost_node.draw_set_transform(Vector2.ZERO)


## Flétris morts qui avaient une image cuite : redessinés depuis elle, du même côté, à leur taille.
func _draw_ghost_sprites() -> void:
	if _frame.is_empty() or _frame["outline"]:
		return
	for g in _ghosts:
		var f: Dictionary = g.get("sprite", {})
		if f.is_empty():
			continue
		var k := float(g.get("r", f["r"])) / maxf(float(f["r"]), 0.01)
		_ghost_sprites.draw_set_transform(g["pos"], 0.0, Vector2(k * float(f.get("side", 1.0)), k))
		# Couleur du dessin : rgb blanc, part de teinte nulle (pas de teinte d'état).
		_ghost_sprites.draw_texture_rect_region(f["tex"], f["rect"], f["src"], Color(1, 1, 1, 1))
	_ghost_sprites.draw_set_transform(Vector2.ZERO)


# =============================================================================================
# Ralenti
# =============================================================================================

## Ralenti : le jeu passe en douceur à « vitesse » (0 à 1), y reste, puis revient à 1, en « duree »
## secondes réelles. Le joueur garde la main. Un seul à la fois : un ralenti plus profond remplace
## celui en cours, un plus léger est ignoré. Vrai s'il est lancé.
## floor (> 0) : vitesse plancher propre à ce ralenti, au lieu de slowmo › min_speed.
func slowmo(duree: float, vitesse: float, floor_ := -1.0) -> bool:
	var k := clampf(Settings.hitstop_strength(), 0.0, 1.0)
	if k <= 0.0 or duree <= 0.0 or _benchmark():
		return false
	var speed := lerpf(1.0, clampf(vitesse, floor_ if floor_ > 0.0 else feel("slowmo", "min_speed", 0.2), 1.0), k)
	if speed >= 0.999:
		return false
	if not _slow.is_empty() and speed >= float(_slow["speed"]):
		return false
	var ramp_in := minf(feel("slowmo", "ramp_in", 0.12), duree * 0.5)
	var ramp_out := minf(feel("slowmo", "ramp_out", 0.4), duree * 0.5)
	_slow = {"t": 0.0, "dur": duree, "speed": speed, "ramp_in": ramp_in, "ramp_out": ramp_out}
	slowmos += 1
	_apply_time()
	return true


## Vitesse du ralenti en cours (1 sans ralenti). fx.gd la combine avec l'arrêt sur image.
func speed() -> float:
	if _slow.is_empty():
		return 1.0
	var t: float = _slow["t"]
	var dur: float = _slow["dur"]
	var s: float = _slow["speed"]
	if t < _slow["ramp_in"]:
		return lerpf(1.0, s, smoothstep(0.0, 1.0, t / maxf(_slow["ramp_in"], 0.001)))
	var out_from: float = dur - float(_slow["ramp_out"])
	if t > out_from:
		return lerpf(s, 1.0, smoothstep(0.0, 1.0, (t - out_from) / maxf(_slow["ramp_out"], 0.001)))
	return s


func in_slowmo() -> bool:
	return not _slow.is_empty()


func _step_slow(real: float) -> void:
	if _slow.is_empty():
		return
	_slow["t"] += real
	if _slow["t"] >= _slow["dur"]:
		_slow = {}
	_apply_time()


## Vitesse du jeu = arrêt sur image (fx.gd) × ralenti : les deux cohabitent sans s'écraser.
func _apply_time() -> void:
	if main != null and main.get("fx") != null:
		main.fx._apply_time()
	else:
		Engine.time_scale = speed()


# =============================================================================================
# Caméra
# =============================================================================================

## À-coup de la caméra de quelques pixels dans le sens du coup (force de 0 à 1, cumulée).
func camera_kick(direction: Vector2, force: float) -> void:
	var k := Settings.shake_strength()
	if k <= 0.0 or direction.length() < 0.001 or _benchmark():
		return
	_kick += direction.normalized() * clampf(force, 0.0, 1.0) * feel("camera", "kick_px", 9.0) * k
	var cap := feel("camera", "kick_px", 9.0) * 1.5
	if _kick.length() > cap:
		_kick = _kick.normalized() * cap
	_cam_dirty = true


## Zoom bref vers l'impact (force de 0 à 1) puis retour doux, en « duree » secondes réelles.
## Le zoom ne fait que rapprocher : rien de plus que d'habitude n'entre à l'écran.
func zoom_pulse(force: float, duree: float) -> void:
	if Settings.shake_strength() <= 0.0 or duree <= 0.0 or _benchmark():
		return
	if not _zoom.is_empty() and force <= float(_zoom["force"]) * _envelope(_zoom, 0.25):
		return
	_zoom = {"t": 0.0, "dur": duree, "force": clampf(force, 0.0, 1.0)}
	_cam_dirty = true


## La caméra glisse vers « position » (une part du chemin, plafonnée) puis revient au héros.
## rise : part de la durée passée à y aller (0,3 : un coup d'œil ; près de 1 : une approche lente,
## puis un retour bref, comme pendant la charge d'un boss). reach (> 0) : part du chemin et plafond
## en pixels propres à ce cadrage, au lieu de feel.json › camera (focus_frac, focus_max).
func focus(position_: Vector2, duree: float, rise := 0.3, frac := -1.0, reach := -1.0) -> void:
	if Settings.shake_strength() <= 0.0 or duree <= 0.0 or _benchmark():
		return
	_focus = {"t": 0.0, "dur": duree, "pos": position_, "rise": clampf(rise, 0.05, 0.95), "frac": frac, "reach": reach}
	_cam_dirty = true


## Courbe d'un effet bref : montée rapide (part « rise » de la durée), puis retour doux.
static func _envelope(e: Dictionary, rise := 0.2) -> float:
	var k := clampf(float(e["t"]) / maxf(float(e["dur"]), 0.001), 0.0, 1.0)
	if k < rise:
		return Anim.ease_out(k / rise)
	return 1.0 - smoothstep(0.0, 1.0, (k - rise) / (1.0 - rise))


func zoom_now() -> float:
	if _zoom.is_empty():
		return 1.0
	return 1.0 + float(_zoom["force"]) * feel("camera", "zoom_max", 0.12) * Settings.shake_strength() * _envelope(_zoom, 0.18)


func focus_offset() -> Vector2:
	if _focus.is_empty() or main == null or main.player == null:
		return Vector2.ZERO
	var to: Vector2 = _focus["pos"] - main.player.position
	var frac := float(_focus.get("frac", -1.0))
	var reach := float(_focus.get("reach", -1.0))
	to *= frac if frac > 0.0 else feel("camera", "focus_frac", 0.4)
	to = to.limit_length(reach if reach > 0.0 else feel("camera", "focus_max", 160.0))
	return to * Settings.shake_strength() * _envelope(_focus, float(_focus.get("rise", 0.3)))


func _step_camera(real: float) -> void:
	for e in [_zoom, _focus]:
		if not e.is_empty():
			e["t"] += real
	if not _zoom.is_empty() and _zoom["t"] >= _zoom["dur"]:
		_zoom = {}
	if not _focus.is_empty() and _focus["t"] >= _focus["dur"]:
		_focus = {}
	_kick *= exp(-feel("camera", "kick_decay", 16.0) * real)
	if _kick.length() < 0.05:
		_kick = Vector2.ZERO
	var cam: Camera2D = main.camera if main != null and main.get("camera") != null else null
	if cam == null or not is_instance_valid(cam):
		return
	var shake: Vector2 = main.fx.shake_offset if main.get("fx") != null else Vector2.ZERO
	var active := _kick != Vector2.ZERO or not _zoom.is_empty() or not _focus.is_empty()
	if Settings.shake_strength() <= 0.0:
		_kick = Vector2.ZERO
		_zoom = {}
		_focus = {}
		active = false
	if active or _cam_dirty or shake != Vector2.ZERO or cam.offset != frame_bias:
		cam.offset = frame_bias + shake + _kick + focus_offset()
		var z := zoom_now()
		if cam.zoom.x != z:
			cam.zoom = Vector2(z, z)
	_cam_dirty = active


func _process(delta: float) -> void:
	# Temps réel : delta est ralenti avec le jeu (comme dans fx.gd), et suit --fixed-fps.
	var real := clampf(delta / maxf(Engine.time_scale, 0.01), 0.0, 0.1)
	_clock += real
	_crit_cd -= real
	if get_tree().paused:
		# Menu ouvert : rien ne bouge et le jeu ne reste pas ralenti derrière le menu.
		_end_frame()
		if Engine.time_scale != 1.0:
			Engine.time_scale = 1.0
		return
	_step_frame(real)
	_step_slow(real)
	_step_camera(real)


# =============================================================================================
# Accroches (fx.gd, heart.gd, main.elite_killed)
# =============================================================================================

## Critique lourd (fx.impact) : impact frame « encre », à-coup de la caméra dans le sens du coup.
func on_crit_heavy(pos: Vector2) -> void:
	if _crit_cd > 0.0:
		return
	# Pas systématique : plus on a de chances de critique, plus l'impact frame est rare
	# (probabilité inversement proportionnelle : crit_ref / chance), contre le flood visuel.
	var ref := feel("impact_frame", "crit_ref", 0.25)
	if crit_chance > ref and _roll() > ref / crit_chance:
		return
	var target: Array = []
	if main != null and main.has_method("enemies_near"):
		var near: Array = main.enemies_near(pos, 24.0, true)
		if not near.is_empty():
			target = [near[0]]
	if target.is_empty():
		target = [{"pos": pos, "r": 16.0, "kind": ""}]
	if impact_frame(feel("impact_frame", "crit_heavy", 0.55), target, "encre"):
		_crit_cd = feel("impact_frame", "crit_cooldown", 0.6)
	if main != null and main.player != null:
		camera_kick(pos - main.player.position, feel("camera", "crit_heavy_kick", 0.5))


## Mort d'une élite (main.elite_killed) : impact frame « encre » forte (alternance papier/encre),
## à-coup et zoom bref. Pas de ralenti (réservé aux Cœurs et aux boss).
func on_elite_kill(e) -> void:
	if e == null or not is_instance_valid(e):
		return
	var ghost := {"kind": str(e.get("kind_id")), "pos": e.position, "r": float(e.radius), "face": e.get("face") if e.get("face") is Vector2 else Vector2.RIGHT,
		"sprite": Remains.enemy_frame(e)}
	impact_frame(feel("impact_frame", "elite_kill", 0.85), [ghost], "encre")
	Rumble.play("elite_kill")
	if main != null and main.player != null:
		camera_kick(e.position - main.player.position, feel("camera", "elite_kick", 0.8))
	zoom_pulse(feel("camera", "elite_zoom", 0.25), feel("camera", "elite_zoom_time", 0.35))


func _boss() -> Node2D:
	if main == null or not main.has_method("active_arena"):
		return null
	var a = main.active_arena()
	if a == null:
		return null
	var b = a.get("boss")
	return b if b != null and is_instance_valid(b) else null


## Changement de phase d'un boss (fx.boss_phase) : impact frame aux couleurs de la région,
## cadrage sur le boss, zoom et ralenti.
func on_boss_phase(pos: Vector2) -> void:
	var b := _boss()
	impact_frame(feel("impact_frame", "boss_phase", 0.9), [b] if b != null else [{"pos": pos, "r": 40.0, "kind": ""}], "region")
	Rumble.play("boss_phase")
	_big_moment("boss_phase", pos)


## Mort d'un boss (fx.boss_kill) : la plus forte impact frame, long ralenti.
func on_boss_kill(pos: Vector2) -> void:
	var b := _boss()
	if b != null and b.get("grand_finale") == true:
		_final_blow(b, pos)
		return
	impact_frame(feel("impact_frame", "boss_kill", 1.0), [b] if b != null else [{"pos": pos, "r": 40.0, "kind": ""}], "region")
	Rumble.play("boss_kill")
	_big_moment("boss_kill", pos)


## Cœur purifié (heart.gd › purify) : impact frame aux couleurs de la région du Cœur, ralenti.
func on_heart(heart) -> void:
	if heart == null:
		return
	var center: Vector2 = heart.get("center") if heart.get("center") is Vector2 else heart.position
	var body = heart.get("body")
	var cibles: Array = [body] if body is Node2D and is_instance_valid(body) else [{"pos": center, "r": 40.0, "kind": ""}]
	impact_frame(feel("impact_frame", "heart", 0.95), cibles, "region", str(heart.get("region")) if heart.get("region") != null else "")
	Rumble.play("heart")
	_big_moment("heart", center)


## Le dernier coup du boss final : une impact frame en encre tenue longtemps (papier, puis encre),
## un ralenti presque à l'arrêt, et tout l'affichage qui se distord (final_blow.gd). Dosage :
## feel.json › final_blow.
func _final_blow(b: Node2D, pos: Vector2) -> void:
	impact_frame(1.0, [b], "encre", "", feel("final_blow", "hold", 0.42))
	focus(pos, feel("final_blow", "focus", 3.2), 0.15, 0.6, 300.0)
	zoom_pulse(1.0, feel("final_blow", "zoom_time", 2.6))
	slowmo(feel("final_blow", "slowmo", 3.4), feel("final_blow", "speed", 0.05), feel("final_blow", "speed", 0.05))
	if Settings.reduce_effects or Settings.shake_strength() <= 0.0 or _benchmark():
		return
	var warp = load("res://scripts/final_blow.gd").new()
	warp.main = main
	get_tree().root.add_child(warp)
	warp.start(b, pos, Settings.shake_strength())
	_warp = warp


## Arrête tout moment en cours (impact frame, ralenti, caméra, distorsion) : tests visuels.
func stop_all() -> void:
	_end_frame()
	_slow = {}
	_zoom = {}
	_focus = {}
	_apply_time()
	if _warp != null and is_instance_valid(_warp):
		_warp.queue_free()
	_warp = null


func _big_moment(key: String, pos: Vector2) -> void:
	focus(pos, feel("camera", key + "_focus", 1.0))
	zoom_pulse(feel("camera", key + "_zoom", 0.5), feel("camera", key + "_zoom_time", 0.8))
	slowmo(feel("slowmo", key, 1.0), feel("slowmo", key + "_speed", 0.4))
