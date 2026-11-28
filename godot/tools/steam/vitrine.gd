## Vitrine Steam (jalon 12 H) : met en scène le vrai jeu en milieu de partie (build de Ronce appris
## par le robot d'équilibrage, niveau 22) pour les captures de la page, l'illustration des capsules
## et les plans de la bande-annonce. Ne modifie pas le jeu : tout passe par la scène principale.
##
## Lancer par tools/steam-art.sh (captures, illustration) ou tools/steam-trailer.sh (plans).
## Arguments (après « -- ») :
##   --shots=a,b      captures à prendre (voir SHOTS), toutes par défaut
##   --out=DOSSIER    dossier des images
##   --clip=NOM       un plan de bande-annonce (voir CLIPS), joué en direct (Movie Maker)
extends Node

const MainScene = preload("res://scenes/main.tscn")
const BuildBot = preload("res://scripts/build_bot.gd")
const Content = preload("res://scripts/content.gd")
const Enemy = preload("res://scripts/enemy.gd")
const Regions = preload("res://scripts/regions.gd")

const SHOTS := ["ronce_combat", "ronce_boss", "ronce_coeur", "vague", "arbre", "couronne", "region", "finale"]
## Captures de la page de la démo (Ronce seule, « -- --demo ») : rien hors de la région de Ronce.
const DEMO_SHOTS := ["ronce_combat", "ronce_eveil", "ronce_coeur", "ronce_boss", "ronce_chute", "arbre", "couronne"]
const Demo = preload("res://scripts/demo.gd")
## Illustration des capsules (sans interface), à prendre en 3840x2160 : « --shots=illustration ».
const ART := ["illustration", "succes", "succes_cycle"]
## Succès Steam (un par boss, steam/succes.md) : région du boss, « finale » pour la Flétrissure.
const ACHIEVEMENTS := {"BOSS_RONCE": "ronce", "BOSS_SPORE": "spore", "BOSS_VENT": "vent", "BOSS_SEVE": "seve",
	"BOSS_AUBE": "aube", "BOSS_RACINE": "racine", "BOSS_FINALE": "finale"}
const LEVEL := 22

## Plans de la bande-annonce (secondes), filmés un par un par le Movie Maker de Godot
## (tools/steam-trailer.sh). Chaque plan annonce « VITRINE debut N » à l'image N où il commence
## vraiment (la mise en place qui précède est coupée au montage).
const CLIPS := {"titre": 5.0, "eveil": 9.0, "combat": 13.0, "arbre": 7.0, "coeur": 10.0, "boss": 13.0,
	"spore": 5.0, "vent": 5.0, "aube": 5.0, "finale": 7.0, "fin": 7.0, "fin_demo": 7.0}
## Ligne de la fin (seul texte de la bande-annonce avec le nom du jeu), par langue.
const END_LINE := {
	"fin": {"fr": "Bientôt sur Steam", "en": "Coming soon to Steam"},   # i18n: non (bande-annonce)
	"fin_demo": {"fr": "Démo jouable sur Steam", "en": "Play the demo on Steam"},   # i18n: non (bande-annonce)
}
const FPS := 30
const RONCE_SKILLS := ["fouet", "volee", "racines", "nova", "saignee"]
const TitleScene = preload("res://scenes/title.tscn")
const UiTheme = preload("res://scripts/ui_theme.gd")

var main
var out_dir := "res://tests/visual/out/steam"
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	rng.seed = 1234
	var shots: Array = (DEMO_SHOTS if Demo.active() else SHOTS).duplicate()
	var clip := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			shots = Array(arg.get_slice("=", 1).split(","))
		elif arg.begins_with("--out="):
			out_dir = arg.get_slice("=", 1)
		elif arg.begins_with("--clip="):
			clip = arg.get_slice("=", 1)
	if clip != "":
		await _film(clip)
		get_tree().quit(0)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	Settings.set_move_mode(Settings.MOVE_MODE_DEFAULT)
	Settings.aim_mode = "auto"
	Settings.bindings = Settings.BINDING_DEFAULTS.duplicate()
	Settings.apply_bindings()
	for s in shots:
		if not s in SHOTS and not s in DEMO_SHOTS and not s in ART:
			printerr("VITRINE capture inconnue : ", s)
			continue
		# Portraits des boss : partie neuve, sans build (rien n'est visé ni marqué).
		await _boot("" if s in ["succes", "succes_cycle", "ronce_eveil"] else "fouet")
		await call("_shot_" + str(s))
		main.queue_free()
		await _frames(2)
	get_tree().quit(0)


## Partie neuve en milieu d'aventure : le build « fouet » de Ronce appris jusqu'au niveau LEVEL.
func _boot(build := "fouet") -> void:
	Game.reset()
	main = MainScene.instantiate()
	main.autotest = true
	main.autotest_shots = []
	main.autotest_done = true
	add_child(main)
	main.tree_ui.play_intro = false
	await _frames(3)
	main.autotest = false
	main.spawn_timer = 1e9
	main.hud.glyphs.hide()
	if build == "":
		return
	var all := BuildBot.load_all()
	var bot = BuildBot.new()
	bot.name = build
	bot.targets = all[build].get("opening", []) + all[build].get("targets", [])
	bot.choices = all[build].get("choices", {})
	bot.start_level = LEVEL
	bot.spend(Game)
	Game.recompute()
	main.autotest = false
	main.spawn_timer = 1e9
	main.hud.glyphs.hide()
	main.player.sync_bar()
	await _frames(2)


func _place(pos: Vector2, zoom := 1.0) -> void:
	var p = main.player
	p.position = pos
	p.reset_physics_interpolation()
	main.camera.zoom = Vector2.ONE * zoom
	main.camera.reset_smoothing()


## Laisse le jeu tourner : le héros ne meurt pas, ses recharges suivent le script.
func _run(n: int, each := Callable()) -> void:
	for i in n:
		var p = main.player
		p.invuln = 0.3
		p.hp = Game.stats["max_hp"]
		if each.is_valid():
			each.call(i)
		await get_tree().process_frame


func _cast(id: String, at: Vector2) -> void:
	var p = main.player
	p.aim = (at - p.position).normalized()
	p.aim_point = at
	p.cds[id] = 0.0
	p.cast(id, Game.stats)


func _ring(center: Vector2, n: int, r0: float, r1: float, kinds: Array) -> void:
	for i in n:
		var a := TAU * i / n + rng.randf_range(-0.2, 0.2)
		main.spawn_enemy_at(center + Vector2.from_angle(a) * rng.randf_range(r0, r1), Enemy.kind_index(kinds[i % kinds.size()]))


func _save(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	img.save_png(ProjectSettings.globalize_path("%s/%s.png" % [out_dir, shot_name]))
	print("VITRINE ", shot_name)


# --- Captures ---

## Ronce : le héros au milieu d'une horde, fouet et volée d'épines en plein vol, sur la terre ravivée.
func _shot_ronce_combat() -> void:
	var spot: Vector2 = main.region_center("ronce") * 0.55
	_place(spot)
	main.revive(spot + Vector2(-260, 80), 520.0, Game.tree.branch_color(0))
	await _run(200)
	_ring(spot, 16, 170, 330, ["fletri", "fletri", "cendreux", "cracheur", "fletri", "chargeur"])
	await _run(50)
	await _run(40, func(i):
		if i == 10: _cast("volee", spot + Vector2(200, -40))
		if i == 24: _cast("fouet", spot + Vector2(-150, 30)))
	await _save("ronce_combat")


## Illustration des capsules : au bord du Cœur purifié de Ronce, le héros tient tête à une horde
## qui monte de la terre flétrie ; volée d'épines et fouet en vol. Sans interface.
func _shot_illustration() -> void:
	var heart = main.heart
	Game.flags[heart.flag] = true
	heart._set_purified(false)
	main.ground.paint(heart.center, heart.life_radius, 1.0)
	main.flora.spawn_patch(heart.center, heart.life_radius * 0.8, 90, Color("e0675e"))
	var away: Vector2 = (heart.center - main.arena.center).normalized()
	var spot: Vector2 = heart.center + away.rotated(1.2) * heart.life_radius * 0.75
	_place(spot, 0.9)
	main.hud.visible = false
	await _run(120)
	var out: Vector2 = (spot - heart.center).normalized()
	for i in 22:
		var a := rng.randf_range(-1.1, 1.1)
		var d := rng.randf_range(190, 420)
		main.spawn_enemy_at(spot + out.rotated(a) * d, Enemy.kind_index(["fletri", "fletri", "cendreux", "cracheur", "colosse", "chargeur", "fletri"][i % 7]))
	await _run(40, func(i):
		if i == 12: _cast("volee", spot + out * 240)
		if i == 30: _cast("fouet", spot + out.rotated(0.5) * 160))
	await _save("illustration")


## Portraits des boss pour les icônes des succès : chaque boss de près, sans héros ni interface,
## sur le sol de son arène (carré de 600 px au centre de l'écran : succes_<ID>.png).
func _shot_succes() -> void:
	main.hud.visible = false
	main.player.visible = false
	main.player.set_physics_process(false)
	for ach in ACHIEVEMENTS:
		var reg: String = ACHIEVEMENTS[ach]
		if reg == "finale":
			_portrait = ach
			await _replay(load("res://tests/visual/finale.gd"), "finale_arene", "")
			continue
		var arena = main.arenas[reg]
		arena.frozen = true
		arena._start_fight()
		var boss = arena.boss
		boss.intro = 0.0
		boss.t = 0.6
		_place(arena.center + Vector2(0, 30), 2.4)
		await _frames(2)
		boss.frozen = true
		boss.redraw()
		main.fx.rings = []   # l'onde de l'entrée dans l'arène
		await _frames(8)
		await _save_square("succes_" + ach)
		_clear_bosses()


## Portrait des succès du New Game+ (CYCLE_2, CYCLE_3) : la Flétrissure endormie sous la graine, dans
## le monde fané du cycle lancé par « -- --cycle=N » (N = 2 ou 3) : succes_CYCLE_<N>.png.
func _shot_succes_cycle() -> void:
	main.hud.visible = false
	main.player.visible = false
	var n: int = Cycles.current()
	if n < 2:
		printerr("VITRINE succes_cycle demande -- --cycle=2 ou 3")
		return
	_portrait = "CYCLE_%d" % n
	await _replay(load("res://tests/visual/finale.gd"), "finale_arene", "")


var _portrait := ""


func _clear_bosses() -> void:
	for e in main.enemies:
		if is_instance_valid(e):
			e.queue_free()
	main.enemies.clear()
	main.big_enemies.clear()
	for id in main.arenas:
		main.arenas[id].state = "fermee"


func _save_square(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	var side := mini(img.get_width(), img.get_height()) * 5 / 9
	img = img.get_region(Rect2i((img.get_width() - side) / 2, (img.get_height() - side) / 2, side, side))
	img.save_png(ProjectSettings.globalize_path("%s/%s.png" % [out_dir, shot_name]))
	print("VITRINE ", shot_name)


## Ronce : la Mère-Ronce en phase 2, ses fouets en plein balayage, le héros qui lui répond.
func _shot_ronce_boss() -> void:
	var arena = main.arena
	var spot: Vector2 = arena.center + Vector2(130, 150)
	_place(spot)
	arena._start_fight()
	arena.gap_open = 0.0
	var boss = arena.boss
	boss.intro = 0.0
	boss.hp = boss.max_hp * 0.55
	boss.phase = 2
	await _run(150, func(i):
		if i == 40: _cast("racines", boss.position)
		if i == 120: _cast("volee", boss.position)
		if i == 138: _cast("fouet", boss.position)
		if i >= 140:
			boss.hit_flash = -1.0
			boss.poison_time = 0.0)
	main.hud.banner_time = 0.0
	await _save("ronce_boss")


## Ronce : le Cœur de flétrissure assiégé, une vague qui déferle, la nova du héros.
func _shot_ronce_coeur() -> void:
	var heart = main.heart
	var spot: Vector2 = heart.center + Vector2(-70, 90)
	_place(spot)
	heart.state = "siege"
	heart.progress = 17.0
	heart.update_bar(true)
	_ring(heart.center, 14, heart.zone + 20.0, heart.zone + 160.0, ["fletri", "cendreux", "fletri", "colosse", "fletri", "cracheur", "chargeur"])
	await _run(70, func(i):
		heart.progress = 17.0
		if i == 30: _cast("volee", heart.center + Vector2(200, -60))
		if i == 58: _cast("nova", spot))
	await _save("ronce_coeur")


## Ronce encore morte (niveau 1) : le héros ranime un sanctuaire, la vague de vie gagne la terre
## grise sous les Flétris.
func _shot_ronce_eveil() -> void:
	var spot: Vector2 = main.region_center("ronce") * 0.6
	_place(spot)
	_ring(spot, 7, 230, 400, ["fletri", "fletri", "cendreux"])
	await _run(30)
	main.revive(spot + Vector2(-120, 50), 620.0, Game.tree.branch_color(0))
	await _run(22)
	await _save("ronce_eveil")


## La Mère-Ronce vient de tomber : ses restes, l'arène qui refleurit sous le héros.
func _shot_ronce_chute() -> void:
	var arena = main.arena
	var spot: Vector2 = arena.center + Vector2(130, 150)
	_place(spot)
	arena._start_fight()
	arena.gap_open = 0.0
	var boss = arena.boss
	boss.intro = 0.0
	boss.hp = boss.max_hp * 0.3
	await _run(60, func(i):
		if i == 20: _cast("racines", boss.position)
		if i == 40: _cast("volee", boss.position))
	boss.take_damage(boss.hp + 1.0, false)
	await _run(int(boss.death_time * 60.0) + 90)
	main.hud.banner_time = 0.0
	await _save("ronce_chute")


## Le marais de Spore encore mort : un sanctuaire ravivé, la vague de vie qui gagne la terre.
## (Ronce est déjà verte au niveau 22 : chaque nœud appris ravive sa région.)
func _shot_vague() -> void:
	var spot: Vector2 = main.region_center("spore") * 0.62
	_place(spot)
	_ring(spot, 7, 260, 420, ["sporule", "lichen", "scissipore"])
	await _run(30)
	main.revive(spot + Vector2(-140, 60), 620.0, Art.ec("poison", "clair"))
	await _run(22)
	await _save("vague")


## L'Arbre de vie : 900 nœuds, le build appris en surbrillance, la couronne de greffes.
func _shot_arbre() -> void:
	_give_grafts()
	main.tree_ui.toggle()
	await _frames(4)
	main.tree_ui.zoom = 0.32
	main.tree_ui.cam = Vector2(0, 0)
	await _frames(20)
	await _save("arbre")


func _shot_couronne() -> void:
	_give_grafts()
	main.tree_ui.toggle()
	await _frames(4)
	main.tree_ui.zoom = 1.1
	await _frames(20)
	await _save("couronne")


func _give_grafts() -> void:
	var ids: Array = Content.grafts().keys()
	ids.sort()
	for g in ids.slice(0, 16):
		Game.give_graft(g)
	for k in Game.crown_max():
		Game.place_graft(k, ids[k * 2])
	Game.recompute()


## Les autres régions : reprises des mises en scène du banc visuel (moments figés).
func _shot_region() -> void:
	await _replay(load("res://tests/visual/plateaux.gd"), "harfang_tempete", "region")


func _shot_finale() -> void:
	await _replay(load("res://tests/visual/finale.gd"), "finale_colosse", "finale")


var _want := ""
var _as := ""
var _done := false


func _replay(script, want: String, as_name: String) -> void:
	_want = want
	_as = as_name
	_done = false
	main.player.set_physics_process(false)
	var sc = script.new()
	await sc.run(self)


## Interface attendue par les scénarios du banc visuel (runner.gd).
func _shot(shot_name: String, _screen := "") -> void:
	if shot_name == _want and not _done:
		_done = true
		main.hud.glyphs.hide()
		if _portrait != "":
			# La Flétrissure endormie au fond du creux, de près.
			main.player.visible = false
			main.hud.visible = false
			main.player.position = main.finale.center + Vector2(0, 30)
			main.player.reset_physics_interpolation()
			main.camera.zoom = Vector2.ONE * 2.0
			main.camera.reset_smoothing()
			await _frames(6)
			await _save_square("succes_" + _portrait)
			_portrait = ""
			return
		if _as == "finale":
			# La Flétrissure agrandie : la caméra recule pour garder sa ramure à l'écran.
			main.moments.zoom_base = 0.8
			main.camera.zoom = Vector2.ONE * 0.8
			await _frames(3)
		await _save(_as)


# --- Bande-annonce ---

func _film(clip: String) -> void:
	if not CLIPS.has(clip):
		printerr("VITRINE plan inconnu : ", clip)
		return
	Settings.set_move_mode(Settings.MOVE_MODE_DEFAULT)
	Settings.aim_mode = "auto"
	Settings.bindings = Settings.BINDING_DEFAULTS.duplicate()
	Settings.apply_bindings()
	# La musique est posée au montage (pistes du jeu, assets/music) : seuls bruitages et ambiance restent.
	var bus := AudioServer.get_bus_index(Music.BUS)
	if bus >= 0:
		AudioServer.set_bus_mute(bus, true)
	await call("_clip_" + clip.trim_suffix("_demo"), clip)


func _mark() -> void:
	print("VITRINE debut ", Engine.get_frames_drawn())


func _secs(clip: String) -> int:
	return int(float(CLIPS[clip]) * FPS)


## Le jeu tourne et le héros se déplace selon « moves » ([seconde, direction], la dernière tient).
func _play(clip: String, each := Callable(), moves: Array = []) -> void:
	_mark()
	var n := _secs(clip)
	await _run(n, func(i):
		var t := float(i) / FPS
		var dir := Vector2.ZERO
		for m in moves:
			if t >= m[0]:
				dir = m[1]
		_steer(dir)
		if each.is_valid():
			each.call(i))
	_steer(Vector2.ZERO)


func _steer(dir: Vector2) -> void:
	for a in ["move_left", "move_right", "move_up", "move_down"]:
		Input.action_release(a)
	if dir.x < 0: Input.action_press("move_left", -dir.x)
	if dir.x > 0: Input.action_press("move_right", dir.x)
	if dir.y < 0: Input.action_press("move_up", -dir.y)
	if dir.y > 0: Input.action_press("move_down", dir.y)


func _all_ronce_skills() -> void:
	Game.test_skills = {}
	for id in RONCE_SKILLS:
		Game.test_skills[id] = true
	Game.recompute()
	Game.flags["barre"] = "fouet,volee,racines,nova"
	main.player.sync_bar()


## Lance les compétences de Ronce à tour de rôle, vers le Flétri le plus proche.
func _skill_cycle(i: int, every := 20) -> void:
	if i % every != 0 or main.enemies.is_empty():
		return
	var p = main.player
	var best = null
	var bd := 1e12
	for e in main.enemies:
		if is_instance_valid(e) and not e.dead:
			var d: float = e.position.distance_squared_to(p.position)
			if d < bd:
				bd = d
				best = e
	if best == null:
		return
	_cast(RONCE_SKILLS[(i / every) % RONCE_SKILLS.size()], best.position)


## Écran titre du jeu, sans ses entrées : le nom, l'arbre gravé. « fin » : avec une seule ligne.
func _clip_titre(clip: String) -> void:
	var title = TitleScene.instantiate()
	add_child(title)
	await _frames(2)
	title.menu.visible = false
	title.controls_card.visible = false
	if END_LINE.has(clip):
		var l := Label.new()
		l.text = END_LINE[clip].get(Loc.lang(), END_LINE[clip]["en"])
		l.add_theme_font_override("font", UiTheme.serif(600, 2))
		l.add_theme_font_size_override("font_size", 40)
		l.add_theme_color_override("font_color", UiTheme.GOLD)
		l.position = Vector2(title.size.x * title.MENU_X, 470)
		title.add_child(l)
	_mark()
	await _frames(_secs(clip))


func _clip_fin(clip: String) -> void:
	await _clip_titre(clip)


## La terre morte de Ronce : le héros (niveau 1) marche, ranime la terre ; la vague de vie gagne.
func _clip_eveil(clip: String) -> void:
	await _boot("")
	var spot: Vector2 = main.region_center("ronce") * 0.6
	_place(spot + Vector2(-220, 60))
	await _run(20)
	_ring(spot + Vector2(200, 0), 4, 140, 260, ["fletri"])
	await _play(clip, func(i):
		if i == 75:
			main.revive(main.player.position, 640.0, Game.tree.branch_color(0))
		if i == 220:
			Game.add_xp(Game.xp_to_next() + 1.0),
		[[0.0, Vector2(1, -0.2)], [2.2, Vector2.ZERO], [3.2, Vector2(0.8, 0.3)], [6.0, Vector2(0.2, -0.6)]])


## En pleine horde : le build du fouet au niveau 22, toutes les compétences de Ronce.
func _clip_combat(clip: String) -> void:
	await _boot()
	_all_ronce_skills()
	var spot: Vector2 = main.region_center("ronce") * 0.75
	_place(spot)
	await _run(10)
	_ring(spot, 12, 220, 380, ["fletri", "cendreux", "fletri", "cracheur", "chargeur", "colosse"])
	await _play(clip, func(i):
		if i % 36 == 0 and main.enemies.size() < 30:
			_ring(main.player.position, 5, 330, 420, ["fletri", "cendreux", "cracheur", "fletri", "chargeur"])
		_skill_cycle(i, 22),
		[[0.0, Vector2(0.5, 0.2)], [3.0, Vector2(-0.3, 0.5)], [6.0, Vector2(-0.5, -0.3)], [9.0, Vector2(0.4, -0.4)]])


## L'Arbre de vie : du nœud tout juste appris à la vue des 900 nœuds.
func _clip_arbre(clip: String) -> void:
	await _boot()
	_give_grafts()
	main.tree_ui.toggle()
	main.tree_ui.zoom = 1.5
	await _frames(6)
	var n := _secs(clip)
	_mark()
	for i in n:
		var k := clampf(float(i - 20) / (n - 40), 0.0, 1.0)
		k = k * k * (3.0 - 2.0 * k)
		main.tree_ui.zoom = lerpf(1.5, 0.2, k)
		await get_tree().process_frame


## Le Cœur de flétrissure : les dernières secondes du siège, puis la purification.
func _clip_coeur(clip: String) -> void:
	await _boot()
	_all_ronce_skills()
	var heart = main.heart
	var spot: Vector2 = heart.center + Vector2(-70, 90)
	_place(spot)
	heart.state = "siege"
	heart.progress = heart.hold_time - 6.5
	heart.wave_timer = 0.2
	_ring(heart.center, 10, heart.zone + 20.0, heart.zone + 140.0, ["fletri", "cendreux", "colosse", "cracheur", "chargeur"])
	await _play(clip, func(i): _skill_cycle(i, 24),
		[[0.0, Vector2(0.3, -0.2)], [2.0, Vector2(-0.3, -0.3)], [4.0, Vector2(0.3, 0.1)], [6.5, Vector2.ZERO]])


## La Mère-Ronce : sa phase 2, puis sa chute et l'arène qui refleurit.
func _clip_boss(clip: String) -> void:
	await _boss_fight(clip, "ronce", 0.62, 8.5)


func _clip_spore(clip: String) -> void:
	await _boss_fight(clip, "spore", 0.55, -1.0)


func _clip_vent(clip: String) -> void:
	await _boss_fight(clip, "vent", 0.3, -1.0)


func _clip_aube(clip: String) -> void:
	await _boss_fight(clip, "aube", 0.5, -1.0)


## Un combat de boss en direct ; « fall » : seconde où il tombe (négatif : il reste debout).
func _boss_fight(clip: String, region: String, hp: float, fall: float) -> void:
	await _boot()
	_all_ronce_skills()
	var arena = main.arenas[region]
	var spot: Vector2 = arena.center + Vector2(140, 170)
	_place(spot)
	arena._start_fight()
	arena.gap_open = 0.0
	var boss = arena.boss
	boss.intro = 0.0
	boss.hp = boss.max_hp * hp
	await _run(int(1.5 * FPS))
	main.fx.rings = []
	main.hud.banner_time = 0.0
	await _play(clip, func(i):
		if is_instance_valid(boss) and not boss.dead:
			if fall < 0.0:
				boss.hp = maxf(boss.hp, boss.max_hp * hp * 0.8)
			elif i == int(fall * FPS):
				boss.take_damage(boss.hp + 1.0, false)
			_skill_cycle(i, 26),
		[[0.0, Vector2(-0.4, 0.3)], [2.5, Vector2(-0.4, -0.4)], [5.0, Vector2(0.4, -0.3)], [7.5, Vector2(0.4, 0.4)], [10.0, Vector2(-0.2, 0.3)]])


## La Flétrissure, sous la graine, dans sa seconde forme.
func _clip_finale(clip: String) -> void:
	await _boot()
	_all_ronce_skills()
	var finale = main.finale
	for id in Regions.ids():
		Game.flags[Regions.heart_flag(id)] = true
		Game.flags[Regions.boss_flag(id)] = true
	finale._open()
	finale.descend()
	await _run(30)
	var p = main.player
	p.position = finale.center + Vector2(150, 160)
	p.reset_physics_interpolation()
	finale._start_fight()
	var boss = finale.boss
	boss.intro = 0.0
	# Sans l'attente calée sur le morceau (le plan est trop court pour la partition entière).
	if finale.sync != null:
		finale.sync.stop()
	# La seconde forme, d'emblée (comme le banc visuel) : l'île au-dessus du gouffre, la ramure de braise.
	boss.phase = 3
	boss.unbound = true
	boss.morph_time = -1.0
	finale.collapse_t = -1.0
	finale.collapse_k = 1.0
	finale.radius = finale.collapse_radius
	boss.hp = boss.max_hp * 0.25
	p.position = finale.center + Vector2(130, 140)
	p.reset_physics_interpolation()
	# La ramure entière à l'écran : la caméra recule un peu.
	main.moments.zoom_base = 0.72
	main.camera.zoom = Vector2.ONE * 0.72
	await _run(int(1.5 * FPS))
	main.fx.rings = []
	await _play(clip, func(i):
		if is_instance_valid(boss):
			boss.hp = maxf(boss.hp, boss.max_hp * 0.2)
		_skill_cycle(i, 26),
		[[0.0, Vector2(-0.4, 0.2)], [2.5, Vector2(0.3, -0.4)]])


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
