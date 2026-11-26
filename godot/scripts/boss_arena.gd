## Arène du boss d'une région (une par région, posée par main.gd) : un cercle muré au-delà du Cœur de
## flétrissure (Regions.arena_center). Réglée par la section « boss » de data/regions/<région>.json
## (script du boss, nom, barre, phases, taille de l'arène, textes) ; sans elle, l'arène de la
## Mère-Ronce. Son sol et son mur sont dessinés par les dessins de la région (Regions.art : ronces du
## roncier par défaut, champignons de Spore, pierres levées de Vent…).
##
## - "fermee"  : tant que les Cœurs de la région ne sont pas tous purifiés, son mur (de ronces mortes dans le roncier) en interdit l'entrée ;
## - "ouverte" : le Cœur est purifié, le mur s'écarte ; y entrer réveille le boss ;
## - "combat"  : le mur se referme derrière le joueur ; il peut se resserrer (start_shrink) ;
## - "vaincue" : Game.flags["<région>_boss_vaincu"] est posé, l'arène refleurit.
##
## Mourir pendant le combat ramène à la graine (main.player_died) : le boss se rendort avec toute
## sa vie, mais le Cœur reste purifié et l'arène ouverte.
## Ce nœud est au niveau du sol (sous les personnages) ; le boss (boss_<région>.gd, BossBase) est
## rangé avec les ennemis.
##
## Arène en décor (refonte du monde, vague 3 A ; contrat dans region_art.gd) : pour une région dont
## l'art le dit (arena_baked), le mur est fait de pièces de décor (ArenaPiece) posées dans le calque
## trié en profondeur (main.actors_layer) et cuites par lieux_bake.gd ; le sol est sur un calque fixe,
## redessiné quand l'état change. La brèche s'ouvre en animation, le mur tremble aux phases et aux coups
## du boss (et le monde vivant le sait : world_life.event « boss_phase », « boss_hit »), suit le rayon
## quand il se resserre, et refleurit après la victoire. Dessin seul : le combat lit toujours radius,
## state et gap_open comme avant.
extends Node2D

const BossSync = preload("res://scripts/boss_sync.gd")
const BossBar = preload("res://scripts/boss_bar.gd")
const Content = preload("res://scripts/content.gd")
const Regions = preload("res://scripts/regions.gd")
const BossEclat = preload("res://scripts/boss_eclat.gd")
const LieuxBake = preload("res://scripts/world_bake/lieux_bake.gd")

## Fondu des pièces vers leur image ravivée après la victoire (secondes).
const REVIVE_TIME := 2.0
## Pièce qui cache le héros ou le boss : opacité visée.
const SEE_THROUGH := 0.42
## Résolution du sol cuit (pixels de l'image par pixel du monde) : un sol doux supporte d'être cuit bas.
const FLOOR_SCALE := 0.5
## Résolution des pièces du mur : 1 pixel d'image par pixel du monde (lissées par le suréchantillonnage
## de la cuisson), lues sans mipmaps : en rendu logiciel, le filtrage trilinéaire de dizaines de grandes
## images qui se chevauchent coûtait plus que tout le reste de l'arène.
const PIECE_SCALE := 1.0

const SHRINK_WARN := 1.6
const SHRINK_SPEED := 30.0
const WALL_DAMAGE := 8.0
## Points du boss si « boss › reward » du fichier de la région ne les donne pas.
const REWARD_POINTS := 2

var main
var heart
## Région de l'arène, son drapeau et son boss (script BossBase, nom, barre, phases, textes).
var region := "ronce"
var flag := "ronce_boss_vaincu"
var boss_script: GDScript
var boss_name := "La Mère-Ronce" # i18n
var bar_color := Color("c84b44")
var phase_names: Array = ["Phase 1 sur 3", "Phase 2 sur 3 : les bourgeons éclosent", "Phase 3 sur 3 : les ronces se resserrent"] # i18n
## Rayon de l'arène, rayon final quand elle se resserre, et distance entre le Cœur et son centre
## (vers l'extérieur du monde).
var max_radius := 470.0
var min_radius := 310.0
var offset := 800.0
## Fleurs de la vague de vie après la victoire.
var life_color := Color("e0675e")
var center := Vector2.ZERO
var radius := 470.0
var state := "fermee"
var boss
var bar
var t := 0.0
## Ouverture du mur (0 fermé, 1 ouvert), animée.
var gap_open := 0.0
var shrink_warn := 0.0
var shrinking := false
## Vague de vie après la victoire (secondes), -1 sinon.
var life_wave := -1.0
var life_step := 0.0
## Combats perdus depuis le lancement (sert au robot du mode autotest).
var defeats := 0
## Figée par les tests visuels.
var frozen := false
## Forme du mur : un décalage et une taille par ronce, tirés une fois.
var _wall: Array = []
var rng := RandomNumberGenerator.new()
## Arrivée, phases et mort signatures du boss (boss_eclat.gd), créé au premier combat.
var eclat

# Robot du mode « -- --autotest=boss ».
var auto_time := 0.0
## Durée maximale du combat du robot (« -- --autotest=boss ») avant l'échec.
var auto_max := 300.0
var auto_done := false
var auto_shots := {}
var auto_boss_left := 1.0

## Arène en décor (vague 3 A) : dessins de la région, pièces du mur et calque du sol.
var art: GDScript
var baked := false
var pieces: Array = []
var _descs: Array = []
var _floor: Node2D
var _floor_key := ""
## Tremblement du mur (phase du boss : 1 puis retombe), frisson (coup reçu par le boss).
var quake := 0.0
var shiver := 0.0
## Fondu vers le ravivé après la victoire (0 → 1).
var revive_k := 1.0
var _seen_phase := 0
var _seen_hp := -1.0
var _hit_cd := 0.0
var _pieces_sig := ""
var _pieces_move := ""
var _pieces_fade_done := true
var _live_clock := 0.0


## Une pièce du mur (ou un repère), triée en profondeur avec les personnages.
class ArenaPiece extends Node2D:
	var arena
	var i := 0

	func _draw() -> void:
		arena.draw_piece(self, i)


## Calque du sol de l'arène (fixe).
class FloorLayer extends Node2D:
	var arena

	func _draw() -> void:
		arena.draw_floor(self)


## Lit les réglages de l'arène et de son boss dans le fichier de la région (appelé par _ready).
func configure(id: String) -> void:
	region = id
	flag = Regions.boss_flag(id)
	var b := Regions.section(id, "boss")
	boss_script = load(str(b.get("script", "res://scripts/boss_ronce.gd")))
	boss_name = str(b.get("name", boss_name))
	bar_color = Regions.color(b.get("bar_color", "#c84b44"))
	phase_names = b.get("phases", phase_names)
	var ar: Dictionary = b.get("arena", {})
	max_radius = float(ar.get("radius", max_radius))
	min_radius = float(ar.get("radius_min", min_radius))
	offset = float(ar.get("offset", offset))
	life_color = Regions.color(ar.get("life_color", "#e0675e"))
	radius = max_radius


func _ready() -> void:
	configure(region)
	if Regions.exists(region):
		center = Regions.arena_center(region)
	else:
		var dir: Vector2 = heart.center.normalized() if heart.center.length() > 1.0 else Vector2.UP
		var limit: float = main.world_half - max_radius - Regions.WORLD_MARGIN
		center = (heart.center + dir * offset).clamp(Vector2(-limit, -limit), Vector2(limit, limit))
	var shape := RandomNumberGenerator.new()
	shape.seed = 97
	for i in 72:
		_wall.append([shape.randf_range(-0.03, 0.03), shape.randf_range(0.7, 1.3), shape.randf_range(-1.0, 1.0)])
	Game.seed_rng(rng, 4 + 10 * maxi(0, Regions.ids().find(region)))
	art = Regions.art(region) if Regions.exists(region) else load(Regions.BASE_ART)
	baked = art.has_method("arena_baked") and art.arena_baked(region)
	if baked:
		_build_pieces()
	bar = BossBar.new()
	# Marques des phases sur la barre : celles du boss (lues sur un boss jamais posé dans le monde).
	var probe = boss_script.new()
	bar.marks = probe.phase_limits
	probe.free()
	main.hud.get_parent().add_child(bar)


func in_combat() -> bool:
	return state == "combat"


## Point devant la brèche, côté Cœur, hors de la zone qui réveille la Mère-Ronce : là où l'on
## reprend une partie sauvegardée pendant le combat, et où la sève attend après une mort dans l'arène.
func entrance() -> Vector2:
	var dir: Vector2 = (heart.center - center).normalized() if heart.center.distance_to(center) > 1.0 else Vector2.DOWN
	return center + dir * (max_radius + 70.0)


func _process(delta: float) -> void:
	t += delta
	quake = maxf(0.0, quake - delta / 0.9)
	shiver = maxf(0.0, shiver - delta / 0.25)
	revive_k = 1.0 if frozen else minf(1.0, revive_k + delta / REVIVE_TIME)
	# Redessinée seulement quand elle touche le cadre de la caméra : les murs des régions (champignons,
	# pierres levées) coûtent plus cher que l'ancien mur de ronces.
	var near: bool = main.player.position.distance_squared_to(center) < 1900.0 * 1900.0 and _near_view()
	if near and not frozen:
		queue_redraw()
	if baked and near:
		_live_clock -= delta
		_sync_pieces()


## L'arène (mur compris, plus une marge) touche le cadre visible.
func _near_view() -> bool:
	var vp := get_viewport()
	if vp == null:
		return true
	var view := vp.get_canvas_transform().affine_inverse() * vp.get_visible_rect()
	return view.grow(max_radius + 120.0).has_point(center)


func _physics_process(delta: float) -> void:
	if frozen:
		return
	if sync != null:
		sync.tick(delta)
	var p = main.player
	var to: Vector2 = p.position - center
	var d := to.length()
	# Les drapeaux font foi (partie chargée, Cœur purifié à l'instant).
	if Game.flags.get(flag, false):
		if state != "vaincue":
			state = "vaincue"
			gap_open = 1.0
	elif state == "fermee" and Game.flags.get(Regions.heart_flag(region), false):
		state = "ouverte"
	match state:
		"fermee":
			if d < max_radius + p.radius + 16.0:
				var out: Vector2 = to / d if d > 0.01 else (heart.center - center).normalized()
				p.position = center + out * (max_radius + p.radius + 16.0)
		"ouverte":
			gap_open = minf(1.0, gap_open + delta / 1.5)
			if d < max_radius - 70.0 and (not main.benchmark or main.bench_scene == "boss"):
				_start_fight()
		"combat":
			if not is_instance_valid(boss) or boss.is_queued_for_deletion():
				_fight_lost()
				return
			gap_open = maxf(0.0, gap_open - delta / 0.6)
			_shrink_step(delta)
			var limit: float = radius - p.radius - 10.0
			if d > limit:
				p.position = center + to / maxf(d, 0.01) * limit
				p.take_hit(WALL_DAMAGE * boss.damage_scale, null)
			update_bar()
			_watch_boss(delta)
		"vaincue":
			bar.hide_bar()
			_life_wave_step(delta)


func update_bar() -> void:
	bar.show_bar(Loc.data(boss_name), boss.hp / boss.max_hp, Loc.data(str(phase_names[mini(boss.phase, phase_names.size()) - 1])), bar_color)


## Combat calé sur le morceau du boss (boss_sync.gd), s'il en a un ; null sinon.
var sync = null


## Vrai pendant que le morceau du boss joue hors combat (la finale : la descente). Lu par boss_track.gd.
func music_on() -> bool:
	return in_combat()


## Grille du morceau pour un nouveau combat : celle déjà lancée (descente de la finale), sinon une
## nouvelle, avec l'intro courte (l'arrivée dans l'arène ne dure que l'invocation).
func _music_sync():
	if sync != null and sync.running:
		return sync
	sync = BossSync.for_region(region)
	if sync != null:
		sync.start("intro_court")
	return sync


func _start_fight() -> void:
	state = "combat"
	radius = max_radius
	_seen_phase = 0
	_seen_hp = -1.0
	shrinking = false
	shrink_warn = 0.0
	main.spawn_paused = true
	# Le mur se referme : les Flétris restés dehors ne prennent pas part au combat.
	for e in main.enemies:
		if is_instance_valid(e) and not e.dead and e.position.distance_to(center) > max_radius:
			e.dead = true
			e.queue_free()
	boss = boss_script.new()
	boss.main = main
	boss.arena = self
	boss.region = region
	boss.position = center
	# Morceau du boss : il émerge pendant l'intro et frappe au premier temps de la première boucle.
	var s = _music_sync()
	if s != null:
		boss.sync = s
		boss.intro_time = maxf(boss.intro_time, s.left())
		boss.intro = boss.intro_time
	main.enemies_layer.add_child(boss)
	main.enemies.append(boss)
	main.big_enemies.append(boss)
	# Arrivée signature : le mur pousse dans la matière de la région, le sol se fend, le boss émerge.
	if eclat == null:
		eclat = BossEclat.new()
		eclat.setup(self)
	eclat.arrive(boss)
	main.fx.ring(center, 30.0, max_radius, 0.8, Color(1.0, 0.45, 0.3, 0.8), 6.0)
	# Entrée dans l'arène : le mur se referme, l'écran rougit sur les bords et tremble.
	main.screen_fx.glow(Art.c("danger"), 0.45, main.screen_fx.FADE_ARENA * 1.6)
	main.fx.shake(0.45)
	main.fx.hitstop(0.05)


## Le joueur est mort : la Mère-Ronce a disparu avec les autres ennemis. Elle reviendra avec toute
## sa vie ; le Cœur reste purifié et l'arène ouverte.
func _fight_lost() -> void:
	defeats += 1
	state = "ouverte"
	boss = null
	if sync != null:
		sync.stop()
		sync = null
	if eclat != null:
		eclat.clear()
	radius = max_radius
	shrinking = false
	shrink_warn = 0.0
	main.spawn_paused = false
	bar.hide_bar()


## Appelé par la Mère-Ronce quand elle meurt : drapeau, points d'arbre, l'arène refleurit.
func boss_defeated() -> void:
	state = "vaincue"
	if sync != null:
		sync.stop()
		sync = null
	gap_open = 1.0
	revive_k = 0.0
	shrinking = false
	shrink_warn = 0.0
	main.spawn_paused = false
	Game.flags[flag] = true
	SteamBridge.unlock(SteamBridge.boss_achievement(region))
	# Récompense (« boss › reward » de la région) : points d'arbre, donnés une seule fois, et une greffe au sol.
	var reward: Dictionary = Content.rewards().get("boss", {}).get(region, {})
	Game.grant_points(int(reward.get("points", REWARD_POINTS)), "boss", region + "_boss")
	if str(reward.get("graft", "")) != "":
		main.drop_graft(center, str(reward["graft"]))
	for i in 3:
		main.fx.ring(center, 40.0, max_radius * (0.5 + 0.3 * i), 0.9 + 0.4 * i, Color(0.6, 1.0, 0.55, 0.9), 6.0)
	# Sortie de l'arène : un éclat de sève sur les bords de l'écran, qui s'éteint doucement.
	main.screen_fx.glow(Art.ec("seve"), 0.5, 1.6)
	life_wave = 0.0
	life_step = 0.0
	bar.hide_bar()
	main.request_autosave()


## Phase 3 : le nouveau bord est annoncé au sol, puis le mur avance jusqu'à lui.
func start_shrink() -> void:
	shrink_warn = SHRINK_WARN
	shrinking = true


func _shrink_step(delta: float) -> void:
	if not shrinking:
		return
	if shrink_warn > 0.0:
		shrink_warn -= delta
		return
	radius = maxf(min_radius, radius - SHRINK_SPEED * delta)
	if radius <= min_radius:
		shrinking = false


func _life_wave_step(delta: float) -> void:
	if life_wave < 0.0:
		return
	life_wave += delta
	life_step -= delta
	if life_step <= 0.0:
		life_step = 0.12
		var r := lerpf(120.0, max_radius * 1.25, clampf(life_wave / 2.0, 0.0, 1.0))
		main.ground.paint(center, r, 0.3)
		main.flora.spawn_patch(center, r, 7, life_color)
	if life_wave >= 2.0:
		life_wave = -1.0


func _draw() -> void:
	# Sol et mur de l'arène : les dessins de la région (Regions.art, region_art.gd par défaut). En décor
	# (vague 3 A), le sol est sur son calque et le mur en pièces : ici, seulement ce qui bouge au sol.
	if baked:
		art.arena_live(self, self)
	else:
		art.draw_arena_floor(self, self)
	# Annonce du resserrement : le futur bord clignote au sol.
	if shrinking:
		var blink := 0.5 + 0.5 * sin(t * 12.0)
		draw_arc(center, min_radius, 0.0, TAU, 96, Color(1.0, 0.35, 0.2, 0.35 + 0.5 * blink), 5.0)
		for i in 24:
			var dir := Vector2.from_angle(TAU * i / 24.0)
			draw_line(center + dir * (radius - 24.0), center + dir * lerpf(radius - 24.0, min_radius + 8.0, 0.3 + 0.2 * blink), Color(1.0, 0.35, 0.2, 0.35), 3.0)
	if not baked:
		art.draw_arena_wall(self, self)
	# Le boss endormi, puis ce qui pousse à sa place : dessinés par son script (BossBase).
	if state == "ouverte" or state == "fermee":
		boss_script.draw_sleeper(self)
	elif state == "vaincue":
		boss_script.draw_victory(self)


# --- Arène en décor (vague 3 A) ---


func _build_pieces() -> void:
	_floor = FloorLayer.new()
	LieuxBake.prepare(_floor)
	_floor.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_floor.arena = self
	_floor.show_behind_parent = true
	add_child(_floor)
	_descs = art.arena_pieces(region, self)
	var layer: Node = main.get("actors_layer") if main != null else null
	for i in _descs.size():
		var pc := ArenaPiece.new()
		pc.arena = self
		pc.i = i
		pc.name = "Arene_%s_%d" % [region, i]  # i18n: non (nom de nœud)
		LieuxBake.prepare(pc)
		pc.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		# main pose encore ses enfants pendant notre _ready : la pièce rejoint le calque juste après.
		if layer != null:
			layer.add_child.call_deferred(pc)
		else:
			add_child(pc)
		var d: Dictionary = _descs[i]
		pc.position = center + Vector2.from_angle(float(d["ang"])) * ((max_radius if not d["ring"] else radius) + float(d["out"]))
		pieces.append(pc)
	tree_exiting.connect(_free_pieces)
	# Pas de cuisson pendant le _ready : la racine pose encore ses enfants (le SubViewport de la cuisson
	# n'y entrerait pas et l'atlas sortirait vide). _process s'en charge dès la première image.


func _free_pieces() -> void:
	for pc in pieces:
		if is_instance_valid(pc) and pc.get_parent() != self:
			pc.queue_free()
	pieces.clear()


## Ouverture de la pièce à l'angle « ang » (0 en place, 1 rentrée sous terre) : la brèche s'ouvre du
## milieu vers les bords, à mesure que gap_open monte.
func gap_k(ang: float) -> float:
	if gap_open <= 0.0:
		return 0.0
	var half := 0.42 * gap_open
	var d := absf(wrapf(ang - art.gate_angle(self), -PI, PI))
	return clampf((half + 0.03 - d) / 0.08, 0.0, 1.0) * minf(1.0, gap_open * 3.0)


## Jeu cuit d'un état.
func bake_key(etat: String) -> String:
	return "arene/%s/%s" % [region, etat]


func _etat() -> String:
	return "ravive" if state == "vaincue" else "fletri"


func _keep_baked(etat: String) -> void:
	var key := bake_key(etat)
	if LieuxBake.ready(key):
		return
	var a: GDScript = art
	var reg := region
	var jobs := []
	for k in art.arena_piece_keys(region):
		var kk: String = k
		jobs.append({"key": kk, "box": art.arena_piece_box(region, kk), "paint": func(ci): a.arena_piece(ci, reg, kk, etat)})
	LieuxBake.request(self, key, jobs, {"trim": true, "scale": PIECE_SCALE, "mipmaps": false})


## Sol cuit d'un état : une seule image douce (résolution FLOOR_SCALE), au lieu de centaines de formes
## redessinées à chaque image.
func _keep_floor_baked(etat: String) -> void:
	var key := bake_key("sol_" + etat)
	if LieuxBake.ready(key):
		return
	var a: GDScript = art
	var proxy := {"center": Vector2.ZERO, "max_radius": max_radius}
	var R := max_radius * 1.06 + 30.0
	LieuxBake.request(self, key, [{"key": "sol", "box": Rect2(-R, -R, 2.0 * R, 2.0 * R), "paint": func(ci): a.arena_floor(ci, proxy, etat)}],
		{"scale": FLOOR_SCALE, "trim": true, "mipmaps": false})


## Place, ouvre, fait trembler et estompe les pièces ; les redessine quand ce qu'elles montrent change.
func _sync_pieces() -> void:
	if pieces.is_empty():
		return
	var etat := _etat()
	_keep_baked(etat)
	if etat == "ravive" and revive_k < 1.0:
		_keep_baked("fletri")
	var fetat := "ravive" if etat == "ravive" and revive_k >= 0.5 else "fletri"
	_keep_floor_baked(fetat)
	var fkey := fetat + str(LieuxBake.ready(bake_key("sol_" + fetat)))
	if fkey != _floor_key:
		_floor_key = fkey
		_floor.queue_redraw()
	var sig := "%s|%s|%d|%d|%d" % [state, etat, int(LieuxBake.ready(bake_key("fletri"))), int(LieuxBake.ready(bake_key("ravive"))), int(revive_k * 20.0)]
	var redraw := sig != _pieces_sig
	_pieces_sig = sig
	# Lueurs du combat : redessinées 15 fois par seconde.
	var live_redraw := false
	if state == "combat" and _live_clock <= 0.0:
		_live_clock = 1.0 / 15.0
		live_redraw = true
	var p = main.player if main != null else null
	var hidden: Array = []
	if p != null:
		hidden.append(p.position)
	if is_instance_valid(boss):
		hidden.append(boss.position)
	# Rien n'a bougé (ni le mur, ni le héros, ni le boss) : les pièces restent comme elles sont.
	var moving := "%.1f|%.3f|%.2f|%.2f|%s|%s" % [radius, gap_open, quake, shiver, str(hidden), str(_pieces_fade_done)]
	if moving == _pieces_move and not redraw:
		if live_redraw:
			for pc in pieces:
				if pc.i % 3 == 0:
					pc.queue_redraw()
		return
	_pieces_move = moving
	_pieces_fade_done = true
	for pc in pieces:
		var d: Dictionary = _descs[pc.i]
		var ang: float = d["ang"]
		var dir := Vector2.from_angle(ang)
		var o := gap_k(ang) if d["ring"] else 0.0
		var r: float = (radius if d["ring"] else max_radius) * (1.0 + float(_wall[pc.i % _wall.size()][0]) * 0.5) + float(d["out"]) + 34.0 * o
		pc.position = center + dir * r
		pc.visible = o < 0.97
		var sz: float = d["size"]
		var fl := -1.0 if d["flip"] else 1.0
		pc.scale = Vector2(fl * sz * (1.0 + 0.12 * o), sz * (1.0 - 0.9 * o))
		# Les bords de la brèche s'écartent ; le mur tremble aux phases, frissonne aux coups.
		var side := signf(wrapf(ang - art.gate_angle(self), -PI, PI))
		var jig := sin(t * 31.0 + pc.i * 1.9) * (0.07 * quake + 0.025 * shiver)
		pc.rotation = side * 0.35 * o + jig
		# Une pièce qui cache le héros ou le boss s'estompe.
		var see := 1.0
		var box: Rect2 = art.arena_piece_box(region, d["key"])
		for h in hidden:
			var rel: Vector2 = h - pc.position
			if rel.y < 0.0 and rel.y > box.position.y * sz * 0.85 and absf(rel.x) < box.size.x * 0.4 * sz:
				see = SEE_THROUGH
		var tint := Color(1.0, 0.82, 0.78) if state == "combat" else Color.WHITE
		var alpha := lerpf(pc.modulate.a, see, 0.25) if not frozen else see
		if absf(alpha - see) > 0.01:
			_pieces_fade_done = false
		else:
			alpha = see
		pc.modulate = Color(tint, alpha)
		if redraw or (live_redraw and pc.i % 3 == 0):
			pc.queue_redraw()


## Dessin d'une pièce : image cuite de l'état (fondue depuis la flétrie après la victoire), dessin direct
## tant qu'elle n'est pas cuite, puis ce qui bouge dessus.
func draw_piece(c: CanvasItem, i: int) -> void:
	var key: String = _descs[i]["key"]
	var etat := _etat()
	if etat == "ravive" and revive_k < 1.0:
		if not LieuxBake.draw(c, bake_key("fletri"), key) and revive_k < 0.5:
			art.arena_piece(c, region, key, "fletri")
		if not LieuxBake.draw(c, bake_key("ravive"), key, Vector2.ZERO, 1.0, Color(1, 1, 1, revive_k)) and revive_k >= 0.5:
			art.arena_piece(c, region, key, "ravive")
	elif not LieuxBake.draw(c, bake_key(etat), key):
		art.arena_piece(c, region, key, etat)
	art.arena_piece_live(c, region, key, self, i)


func draw_floor(c: CanvasItem) -> void:
	var etat := "ravive" if state == "vaincue" and revive_k >= 0.5 else "fletri"
	if not LieuxBake.draw(c, bake_key("sol_" + etat), "sol", center):
		art.arena_floor(c, self, etat)


## Le boss change de phase ou est touché : le mur tremble, le monde vivant réagit (world_life.event).
func _watch_boss(delta: float) -> void:
	if frozen or not is_instance_valid(boss):
		return
	_hit_cd -= delta
	var ph := int(boss.phase)
	if ph > _seen_phase:
		if _seen_phase > 0:
			quake = 1.0
			_life_event("boss_phase", center, {"phase": ph, "r": max_radius * 1.35})
		_seen_phase = ph
	var hp: float = boss.hp
	if _seen_hp >= 0.0 and hp < _seen_hp - 0.001 and _hit_cd <= 0.0:
		_hit_cd = 0.25
		shiver = 1.0
		_life_event("boss_hit", boss.position, {})
	_seen_hp = hp


func _life_event(kind: String, pos: Vector2, data: Dictionary) -> void:
	var wfx = main.get("world_fx") if main != null else null
	var life = wfx.get("life") if wfx != null else null
	if life != null:
		life.event(kind, pos, data)


# --- Robot du mode « -- --autotest=boss » ---

## Prépare le combat : un build de test (niveau 12, points placés dans la branche de la région), le
## Cœur déjà purifié et le joueur posé dans l'arène.
func autotest_begin() -> void:
	autotest_build(12, Regions.branch_of(region))
	Game.flags[Regions.heart_flag(region)] = true
	main.player.hp = Game.stats["max_hp"]
	main.player.position = center + (heart.center - center).normalized() * (max_radius - 110.0)
	main.player.reset_physics_interpolation()
	print("AUTOTEST boss : niveau %d, %d nœuds de la branche, dégâts %.1f, vie %d" % [Game.level, Game.allocated.size() - 1, Game.stats["damage"], int(Game.stats["max_hp"])])


## Build de test des robots de boss : monte au niveau « level » et place tous les points dans la
## branche « branch » (nœuds clés d'abord, puis ceux qui augmentent les dégâts ou la cadence).
static func autotest_build(level: int, branch: String) -> void:
	while Game.level < level:
		Game.add_xp(Game.xp_to_next())
	var bi := maxi(0, Content.tree().get("branches", []).find(branch))
	while Game.points > 0:
		var options: Array = []
		for n in Game.tree.nodes:
			if n["branch"] == bi and n["border"] < 0 and Game.can_allocate(n["id"]):
				options.append(n)
		if options.is_empty():
			break
		options.sort_custom(func(a, b):
			if (a["type"] == "keystone") != (b["type"] == "keystone"):
				return a["type"] == "keystone"
			# Puis les nœuds qui augmentent les dégâts ou la cadence : un robot qui se contente
			# de la première grappe venue allongeait le combat de plusieurs minutes (région Vent).
			var sa := _autotest_node_score(a)
			var sb := _autotest_node_score(b)
			if sa != sb:
				return sa > sb
			return a["ring"] < b["ring"] if a["ring"] != b["ring"] else a["id"] < b["id"])
		Game.allocate(options[0]["id"])


## Intérêt d'un nœud pour le build de test : nombre d'effets qui touchent aux dégâts, à la cadence
## ou à l'attaque de base.
static func _autotest_node_score(n: Dictionary) -> int:
	var score := 0
	for e in n.get("effects", []):
		if e is Dictionary:
			if e.has("attack_form") or e.has("attack_mod"):
				score += 1
			elif str(e.get("stat", "")) in ["damage", "projectile_damage", "fire_rate", "crit_chance", "crit_mult"]:
				score += 1
	return score


## Le robot tourne autour du boss et choisit, parmi quelques pas possibles, l'endroit
## que les attaques annoncées toucheront le plus tard.
func bot_input(p) -> Dictionary:
	if state != "combat" or not is_instance_valid(boss) or boss.dead:
		var mv: Vector2 = center - p.position
		return {"move": mv.normalized() if state == "ouverte" and mv.length() > 60.0 else Vector2.ZERO, "aim": center, "dash": false}
	var target: Vector2 = boss.position
	var best_d := 240.0 * 240.0
	for e in boss.minions:
		if is_instance_valid(e) and not e.dead:
			var d2: float = e.position.distance_squared_to(p.position)
			if d2 < best_d:
				best_d = d2
				target = e.position
	var rel: Vector2 = p.position - center
	var ring: float = boss.bot_ring(radius)
	# Attaque de base au corps à corps (le fouet de Ronce, ~135 px) : le robot se rapproche pour
	# toucher le boss, sauf quand celui-ci annonce une attaque que l'anneau lointain évite.
	var reach: float = p.attack_range()
	if boss.attack == "" or boss.stage == "annonce":
		var melee_ring: float = boss.radius + maxf(reach * 0.4, 60.0)
		if melee_ring < ring:
			ring = maxf(melee_ring, boss.radius + 55.0)
	var pref := center + Vector2.from_angle(rel.angle() + 0.45) * ring
	var here: float = boss.danger_time(p.position)
	var best_pos: Vector2 = p.position
	var best_score := -INF
	var options: Array = [p.position, p.position + (pref - p.position).limit_length(90.0)]
	for i in 12:
		options.append(p.position + Vector2.from_angle(TAU * i / 12.0) * 90.0)
	for o in options:
		var c: Vector2 = o
		var dc := c.distance_to(center)
		if dc > radius - 40.0 or dc < boss.radius + 50.0:
			continue
		var score: float = minf(boss.danger_time(c), 2.0) * 100.0 - c.distance_to(pref) * 0.5
		for e in boss.minions:
			if is_instance_valid(e) and not e.dead and e.position.distance_to(c) < 70.0:
				score -= 60.0
		if score > best_score:
			best_score = score
			best_pos = c
	var move: Vector2 = best_pos - p.position
	return {"move": move.normalized() if move.length() > 4.0 else Vector2.ZERO, "aim": target, "dash": here < 0.2}


## Suit le combat : captures à chaque phase, puis fin sur une victoire, une défaite, ou un échec
## si le combat dure plus de 5 minutes.
func autotest_step(delta: float) -> void:
	if auto_done:
		return
	auto_time += delta
	if state == "combat" and is_instance_valid(boss) and not boss.dead:
		auto_boss_left = boss.hp / boss.max_hp
		if int(auto_time / 10.0) != int((auto_time - delta) / 10.0):
			print("AUTOTEST boss : %3d s  phase %d  vie du boss %d %%  vie du joueur %d" % [int(auto_time), boss.phase, roundi(auto_boss_left * 100.0), int(main.player.hp)])
		var key := "boss_phase%d" % boss.phase
		if not auto_shots.has(key) and boss.attack != "" and boss.stage == "annonce":
			auto_shots[key] = true
			main._capture(key)
	if state == "vaincue":
		_autotest_end("victoire", 0)
	elif defeats > 0:
		_autotest_end("défaite", 0) # i18n: non
	elif auto_time >= auto_max:
		_autotest_end("ÉCHEC, combat non terminé", 1) # i18n: non


func _autotest_end(result: String, code: int) -> void:
	auto_done = true
	var left := 0.0 if state == "vaincue" else auto_boss_left
	print("AUTOTEST boss : %s en %.1f s  (vie du boss %d %%, vie du joueur %d, drapeaux %s)" % [result, auto_time, roundi(left * 100.0), int(main.player.hp), JSON.stringify(Game.flags)])
	await get_tree().create_timer(1.0).timeout
	await main._capture("boss_fin")
	get_tree().quit(code)
