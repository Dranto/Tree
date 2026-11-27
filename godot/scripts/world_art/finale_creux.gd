## Le creux sous la graine (refonte du monde, vague 3 F) : le décor fixe de l'arène de la finale
## (finale_arena.gd), dessiné par le code dans le style des « Paysages d'herbier », puis cuit.
##
## Vu de trois quarts, le creux est un puits de terre :
##   - la paroi du fond (au nord) monte en strates jusqu'à la lèvre ; sur les côtés elle s'abaisse, au
##     sud on ne voit que la lèvre (le sol du combat n'est jamais caché). Dans les strates, un peu de
##     chaque région : ronces, chapeaux, ardoises et plumes, lianes qui suintent la sève, cristaux, bois
##     pétrifié et ambre. La lumière tombe du puits (au sud, là où l'on arrive) et éclaire la paroi du fond ;
##   - les racines de la graine passent la lèvre et pendent sur la paroi ; la racine pivot plonge
##     jusqu'au centre (où dort la Flétrissure) ; d'autres racines couchées au pied de la paroi font le mur ;
##   - le sol en couches : lavis de cendre tassée, matière (fissures, veines de sève éteintes), détails
##     en grappes (éclats des six régions) ;
##   - refleuri (après la victoire) : les veines s'allument, les poches des strates reprennent leurs
##     couleurs ravivées, et sous chacune la terre se couvre de l'herbe et des fleurs de sa région.
##
## Le nœud (deux enfants de l'arène, derrière elle) : « creux » dessine la terre autour, ses racines et
## l'image cuite du creux (flétrie, puis ravivée en fondu pendant la floraison) ; « breche » dessine la
## brèche au pied de la graine (jeu « finale/breche » de lieux_bake.gd). Ils ne se redessinent que
## quand quelque chose change (état, floraison, cuisson finie). Tout ce qui bouge (radicelles qui
## frémissent, poussière, lueurs, gouffre de l'effondrement) reste dessiné en direct par l'arène.
## Sans rendu (--headless) ou avec « -- --no-lieux-cuits », dessin direct, sans cuisson.
##
## Dessin seul : aucune collision, aucun réglage du combat ; le bord du sol reste le cercle du combat.
extends Node2D

const O = preload("res://scripts/world_art/outils.gd")
const Ink = preload("res://scripts/creature_art/ink.gd")
const LieuxBake = preload("res://scripts/world_bake/lieux_bake.gd")
const Abords = preload("res://scripts/world_art/finale_abords.gd")

## Largeur de la lèvre (px du monde) et hauteur de la paroi du fond, au nord.
const T := 38.0
const H := 200.0
## Ombre de la terre autour de la lèvre (px) : l'image cuite s'y fond dans la terre dessinée en direct.
const FADE := 140.0
## Les six poches des strates, d'ouest en est sur la paroi du fond (angle en degrés, -90 : nord).
const POCHES := [["ronce", -166.0], ["spore", -137.0], ["vent", -108.0], ["seve", -72.0], ["aube", -43.0], ["racine", -14.0]]
## Pixels de l'image par pixel du monde, et suréchantillonnage de la cuisson.
const SCALE := 1.0
const SS := 2
## Demi-côté de la terre dessinée autour du creux (px) : l'écran le plus large n'en voit pas le bord.
const EARTH_HALF := 2600.0
## Les abords (world_art/finale_abords.gd) : carreaux opaques de TILE px, sur une grille de demi-taille
## ABORDS_HALF autour du centre du creux. Seuls ceux que la caméra peut montrer pendant le combat (selon
## la taille de l'écran) sont cuits ; ceux que le creux cache entièrement sont sautés. Un pixel de marge
## autour de chaque carreau évite les coutures du filtrage.
const TILE := 256
const ABORDS_HALF := Vector2(1664.0, 1152.0)
const TILES_PER_FRAME := 6

## « breche » ou « creux ».
var mode := "creux"
var arena
var r := 520.0
## Images cuites du creux : "fletri", "ravive" -> ImageTexture.
var tex := {}
var _pending := {}
var _failed := {}
## Mesures (tests, banc).
var bake_usec := 0
var bytes := 0
## Ce qui est dessiné (le nœud ne se redessine que si cela change).
var _bloom := -1.0
var _state := ""
var _has := ""
var _breach_hold
## Carreaux des abords : Vector2i -> ImageTexture ; mémoire (octets) et durée de cuisson (µs).
var tiles := {}
var tile_bytes := 0
var tiles_usec := 0
var _tiles_busy := false
var _tiles_off := false
var _tiles_want: Array = []
var _tiles_view := Vector2.ZERO


func _ready() -> void:
	show_behind_parent = true
	LieuxBake.prepare(self)
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR


func _exit_tree() -> void:
	tex.clear()
	tiles.clear()
	_breach_hold = null


func _process(_delta: float) -> void:
	if arena == null or arena.main == null or arena.main.player == null:
		return
	var b: float = arena.bloom
	var st: String = arena.state
	if mode == "creux":
		var show: bool = arena.holds(arena.main.player.position)
		if show != visible:
			visible = show
		if not show:
			return
		var want := ("ravive" if b > 0.0 or st == "vaincue" else "") + ("fletri" if b < 1.0 else "")
		if want.contains("fletri"):
			request("fletri")
		if want.contains("ravive"):
			request("ravive")
		request_tiles()
		# La floraison finie, l'image flétrie ne sert plus.
		if b >= 1.0 and tex.has("fletri") and tex.has("ravive"):
			tex.erase("fletri")
			_recount()
		var has := ",".join(tex.keys()) + ":%d" % tiles.size()
		if b != _bloom or has != _has:
			_bloom = b
			_has = has
			queue_redraw()
	else:
		var show_b := st != "fermee"
		if show_b != visible:
			visible = show_b
		if st != _state:
			_state = st
			queue_redraw()


func _recount() -> void:
	bytes = 0
	for k in tex:
		bytes += int(tex[k].get_meta("bytes", 0))


# --- Dessin du nœud ---

func _draw() -> void:
	if arena == null:
		return
	if mode == "breche":
		_draw_breche()
		return
	var c: Vector2 = arena.center
	var b := clampf(arena.bloom, 0.0, 1.0)
	_draw_abords(c, b)
	var drew := false
	if tex.has("fletri") and b < 1.0:
		_blit("fletri", c, 1.0)
		drew = true
	if tex.has("ravive") and b > 0.0:
		_blit("ravive", c, b if drew else 1.0)
		drew = true
	if not drew:
		draw_set_transform(c)
		paint_cave(self, r, b >= 0.5)
		draw_set_transform_matrix(Transform2D.IDENTITY)


## La terre autour : les carreaux cuits des abords (teintés vers la vie pendant la floraison) et, au-delà
## de leur grille, la terre unie. Tant qu'ils manquent : la terre unie et ses racines en direct ; sans
## cuisson du tout : les abords dessinés en direct.
func _draw_abords(c: Vector2, b: float) -> void:
	var full := Rect2(c - Vector2.ONE * EARTH_HALF, Vector2.ONE * EARTH_HALF * 2.0)
	if _tiles_off:
		draw_rect(full, terre(b))
		draw_set_transform(c)
		Abords.paint_all(self, r)
		draw_set_transform_matrix(Transform2D.IDENTITY)
		return
	if tiles_ready():
		# Seulement la terre hors de la grille (rien sous les carreaux : rendu logiciel = coût au pixel).
		var g := Rect2(c - ABORDS_HALF, ABORDS_HALF * 2.0)
		draw_rect(Rect2(full.position, Vector2(full.size.x, g.position.y - full.position.y)), terre(b))
		draw_rect(Rect2(Vector2(full.position.x, g.end.y), Vector2(full.size.x, full.end.y - g.end.y)), terre(b))
		draw_rect(Rect2(Vector2(full.position.x, g.position.y), Vector2(g.position.x - full.position.x, g.size.y)), terre(b))
		draw_rect(Rect2(Vector2(g.end.x, g.position.y), Vector2(full.end.x - g.end.x, g.size.y)), terre(b))
	else:
		draw_rect(full, terre(b))
		_far_roots(self, c, r, b)
	var mod := Color.WHITE.lerp(Color(1.16, 1.12, 1.0), b)
	for key in tiles:
		draw_texture_rect_region(tiles[key], Rect2(c + tile_rect(key).position, Vector2.ONE * TILE), Rect2(1, 1, TILE, TILE), mod)


func _blit(key: String, c: Vector2, alpha: float) -> void:
	var rect := bake_rect(r)
	draw_texture_rect(tex[key], Rect2(c + rect.position, rect.size), false, Color(1, 1, 1, alpha))


func _draw_breche() -> void:
	var won: bool = arena.state == "vaincue"
	var key := "vive" if won else "morte"
	var at: Vector2 = arena.descent_point()
	if LieuxBake.draw(self, "finale/breche", key, at):
		# Garde l'image tant qu'elle est dessinée (lieux_bake peut l'oublier au-delà de son budget).
		_breach_hold = LieuxBake.sets.get("finale/breche")
		return
	LieuxBake.request(self, "finale/breche", [
		{"key": "morte", "box": BRECHE_BOX, "paint": func(ci): paint_breche(ci, false)},
		{"key": "vive", "box": BRECHE_BOX, "paint": func(ci): paint_breche(ci, true)}])
	draw_set_transform(at)
	paint_breche(self, won)
	draw_set_transform_matrix(Transform2D.IDENTITY)
	# Redessine quand la cuisson sera finie.
	if not LieuxBake._failed.has("finale/breche"):
		get_tree().create_timer(0.1).timeout.connect(func(): if is_inside_tree(): queue_redraw())


# --- Cuisson du creux ---

## Rectangle de l'image cuite autour du centre du creux (px du monde).
static func bake_rect(rr: float) -> Rect2:
	var x := rr + T + FADE
	var top := rr + T + H + FADE
	return Rect2(-x, -top, 2.0 * x, top + x)


class Painter extends Node2D:
	var paint: Callable
	var xf := Transform2D.IDENTITY

	func _draw() -> void:
		draw_set_transform_matrix(xf)
		paint.call(self)


func request(key: String) -> void:
	LieuxBake.configure()
	if tex.has(key) or _pending.has(key) or _failed.has(key):
		return
	if not LieuxBake.enabled or not is_inside_tree() or DisplayServer.get_name() == "headless":
		_failed[key] = true
		return
	_pending[key] = true
	_bake(key)


func _bake(key: String) -> void:
	var t0 := Time.get_ticks_usec()
	var rect := bake_rect(r)
	var k := SCALE * SS
	var vp := SubViewport.new()
	vp.size = Vector2i((rect.size * k).ceil())
	vp.transparent_bg = true
	vp.disable_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	vp.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	var p := Painter.new()
	p.xf = Transform2D(0.0, Vector2(k, k), 0.0, -rect.position * k)
	var rr := r
	var vive := key == "ravive"
	p.paint = func(ci): paint_cave(ci, rr, vive)
	vp.add_child(p)
	var tree := get_tree()
	tree.root.add_child(vp)
	await tree.process_frame
	await RenderingServer.frame_post_draw
	var vt := vp.get_texture()
	var img: Image = vt.get_image() if vt != null else null
	vp.queue_free()
	_pending.erase(key)
	if img == null or img.is_empty() or not is_inside_tree():
		_failed[key] = true
		return
	if SS > 1:
		img.resize(img.get_width() / SS, img.get_height() / SS, Image.INTERPOLATE_TRILINEAR)
	var it := ImageTexture.create_from_image(img)
	it.set_meta("bytes", img.get_data_size())
	tex[key] = it
	_recount()
	bake_usec = Time.get_ticks_usec() - t0
	queue_redraw()


# --- Cuisson des abords ---

## Rectangle d'un carreau (px du monde, centre du creux en (0, 0)).
## Le nœud cache-t-il entièrement « rect » (coordonnées du monde) ? Le sol du monde (ground.gd) ne rend
## pas ses carrés cachés : sous la graine, la terre opaque du creux couvre tout l'écran, et ces carrés
## coûtaient ~7 ms par image en rendu logiciel pour rien. Vrai seulement là où quelque chose d'opaque est
## dessiné à coup sûr : la terre unie (toujours, sauf sur la grille des carreaux une fois ceux-ci prêts),
## un carreau cuit, ou le creux lui-même (carreaux que le creux cache).
func covers_rect(rect: Rect2) -> bool:
	if mode != "creux" or arena == null or not is_visible_in_tree():
		return false
	var c: Vector2 = arena.center
	if not Rect2(c - Vector2.ONE * EARTH_HALF, Vector2.ONE * EARTH_HALF * 2.0).encloses(rect):
		return false
	var f := Engine.get_process_frames()
	if f != _cover_frame:
		_cover_frame = f
		_cover_all = _tiles_off or not tiles_ready()
	if _cover_all:
		return true
	# Carreaux prêts : la grille n'a que les carreaux cuits (et le creux au milieu).
	var rel := Rect2(rect.position - c, rect.size)
	var lo := Vector2i(((rel.position + ABORDS_HALF) / TILE).floor())
	var hi := Vector2i(((rel.end + ABORDS_HALF) / TILE).ceil()) - Vector2i.ONE
	var n := Vector2i((ABORDS_HALF * 2.0 / TILE).ceil())
	for i in range(maxi(lo.x, 0), mini(hi.x, n.x - 1) + 1):
		for j in range(maxi(lo.y, 0), mini(hi.y, n.y - 1) + 1):
			var key := Vector2i(i, j)
			if tiles.has(key):
				continue
			if not _hidden.has(key):
				_hidden[key] = tile_hidden(key, r)
			if not _hidden[key]:
				return false
	return true


var _cover_frame := -1
var _cover_all := false
## Carreaux que le creux cache (tile_hidden, gardé : la recherche dans le contour coûte).
var _hidden := {}


static func tile_rect(key: Vector2i) -> Rect2:
	return Rect2(-ABORDS_HALF + Vector2(key) * TILE, Vector2.ONE * TILE)


## Le creux (paroi, sol) cache-t-il tout le carreau ? Alors il ne sert à rien de le cuire.
static func tile_hidden(key: Vector2i, rr: float) -> bool:
	var inner := contour(rr, 1.0, 3.0, 0.0, -14.0, 90)
	var rect := tile_rect(key)
	for i in 3:
		for j in 3:
			if not Geometry2D.is_point_in_polygon(rect.position + rect.size * Vector2(i, j) * 0.5, inner):
				return false
	return true


## Les carreaux que la caméra peut montrer (le joueur n'importe où dans le creux), les plus proches du
## puits de lumière (là où l'on arrive) d'abord.
func wanted_tiles() -> Array:
	var half := Vector2(800, 450)
	if is_inside_tree():
		half = get_viewport().get_visible_rect().size * 0.5
		# Caméra éloignée (zoom < 1) : elle montre plus loin.
		var cam := get_viewport().get_camera_2d()
		if cam != null and cam.zoom.x > 0.0:
			half /= minf(cam.zoom.x, 1.0)
	if half == _tiles_view and not _tiles_want.is_empty():
		return _tiles_want
	_tiles_view = half
	var zone := Rect2(-Vector2.ONE * r - half - Vector2(64, 64 + H), Vector2.ONE * r * 2.0 + half * 2.0 + Vector2(128, 128 + H))
	var out := []
	var n := Vector2i((ABORDS_HALF * 2.0 / TILE).ceil())
	for i in n.x:
		for j in n.y:
			var key := Vector2i(i, j)
			if tile_rect(key).intersects(zone) and not tile_hidden(key, r):
				out.append(key)
	var land := Vector2(0, r)
	out.sort_custom(func(a, b): return tile_rect(a).get_center().distance_squared_to(land) < tile_rect(b).get_center().distance_squared_to(land))
	_tiles_want = out
	return out


func tiles_ready() -> bool:
	if _tiles_off:
		return true
	for key in wanted_tiles():
		if not tiles.has(key):
			return false
	return true


func request_tiles() -> void:
	LieuxBake.configure()
	if _tiles_busy or _tiles_off:
		return
	if not LieuxBake.enabled or not is_inside_tree() or DisplayServer.get_name() == "headless":
		_tiles_off = true
		queue_redraw()
		return
	var todo := []
	for key in wanted_tiles():
		if not tiles.has(key):
			todo.append(key)
			if todo.size() >= TILES_PER_FRAME:
				break
	if not todo.is_empty():
		_bake_tiles(todo)


func _bake_tiles(keys: Array) -> void:
	_tiles_busy = true
	var t0 := Time.get_ticks_usec()
	var rr := r
	var tree := get_tree()
	var vps := []
	for key in keys:
		var rect := tile_rect(key).grow(1.0)
		var vp := SubViewport.new()
		vp.size = Vector2i((rect.size * SS).ceil())
		vp.transparent_bg = true
		vp.disable_3d = true
		vp.render_target_update_mode = SubViewport.UPDATE_ONCE
		vp.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
		var p := Painter.new()
		p.xf = Transform2D(0.0, Vector2(SS, SS), 0.0, -rect.position * SS)
		p.paint = func(ci): Abords.paint_tile(ci, rect, rr)
		vp.add_child(p)
		tree.root.add_child(vp)
		vps.append(vp)
	await tree.process_frame
	await RenderingServer.frame_post_draw
	for i in keys.size():
		var vt: ViewportTexture = vps[i].get_texture()
		var img: Image = vt.get_image() if vt != null else null
		vps[i].queue_free()
		if img == null or img.is_empty() or not is_inside_tree():
			_tiles_off = true
			continue
		img.convert(Image.FORMAT_RGB8)
		if SS > 1:
			img.resize(img.get_width() / SS, img.get_height() / SS, Image.INTERPOLATE_BILINEAR)
		tiles[keys[i]] = ImageTexture.create_from_image(img)
		tile_bytes += img.get_data_size()
	tiles_usec += Time.get_ticks_usec() - t0
	_tiles_busy = false
	if is_inside_tree():
		queue_redraw()
		# Les suivants, sans attendre que le creux se montre (la cuisson commence pendant la plongée).
		request_tiles()


# --- Couleurs ---

static func cc(key: String) -> Color:
	return Art.MONDE["commun"]["creux"][key]


## Terre autour du creux (flétrie → vivante).
static func terre(b: float) -> Color:
	return cc("terre").lerp(cc("terre_vive"), b)


static func _st(vive: bool) -> String:
	return "ravive" if vive else "fletri"


static func _pal(reg: String, vive: bool, key: String) -> Dictionary:
	return Art.mc(reg, _st(vive), key)


static func _col(reg: String, vive: bool, key: String) -> Color:
	return Art.mc(reg, _st(vive), key)


static func _ecorce(vive: bool) -> Dictionary:
	return Art.mc("commun", "", "ecorce_vive" if vive else "ecorce")


# --- Géométrie de la paroi ---

## Part de la hauteur de la paroi visible à l'angle a : 1 au nord, ~0,35 sur les côtés, 0 au sud.
static func hk(a: float) -> float:
	return pow(0.5 - 0.5 * sin(a), 1.5)


## Point de la paroi : f = 0 au pied (bord du sol), f = 1 à la lèvre.
static func wall_pt(rr: float, a: float, f: float, wob := 0.0) -> Vector2:
	return Vector2.from_angle(a) * (rr + T * f + wob) - Vector2(0.0, H * hk(a) * f)


## Contour fermé de la paroi à la hauteur f (ondulé de amp px), poussé de d px vers l'extérieur.
static func contour(rr: float, f: float, seed: float, amp := 0.0, d := 0.0, n := 180) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * i / n
		var w := amp * O.wave(a * 7.0, seed) if amp > 0.0 else 0.0
		pts.append(wall_pt(rr, a, f, w + d))
	return pts


# --- Le creux (centre en (0, 0)) ---

static func paint_cave(ci: CanvasItem, rr: float, vive: bool) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4021
	_paint_rim(ci, rr, vive)
	_paint_strata(ci, rr, vive)
	_paint_wall_light(ci, rr, vive)
	_paint_wall_fossils(ci, rr, vive)
	_paint_root_curtain(ci, rr, vive)
	for pk in POCHES:
		_paint_poche(ci, rr, str(pk[0]), deg_to_rad(float(pk[1])), vive)
	_paint_lip_growth(ci, rr, vive)
	_paint_graine_roots(ci, rr, vive)
	_paint_floor(ci, rr, vive)
	_paint_seal(ci, rr, vive)
	_paint_floor_regions(ci, rr, vive)
	_paint_foot_rubble(ci, rr, vive)
	_paint_foot_roots(ci, rr, vive)
	_paint_taproot(ci, rr, vive)


## La terre autour de la lèvre : une ombre qui s'épaissit vers le creux, puis la lèvre elle-même.
static func _paint_rim(ci: CanvasItem, rr: float, vive: bool) -> void:
	var dark := cc("terre").darkened(0.45)
	for i in 7:
		var d := FADE * (1.0 - i / 7.0)
		O.poly(ci, contour(rr, 1.0, 3.0, 8.0, d), Color(dark, 0.13))
	var crust := cc("croute_vive" if vive else "croute")
	O.poly(ci, contour(rr, 1.0, 3.0, 8.0, 16.0), crust.darkened(0.25))
	O.poly(ci, contour(rr, 1.0, 3.0, 8.0, 10.0), crust)


## Les strates : de la lèvre au pied, des bandes de terre ondulées, de plus en plus sombres en bas ;
## leurs joints tracés d'un trait fin, des fissures et des cailloux pris dans la terre.
static func _paint_strata(ci: CanvasItem, rr: float, vive: bool) -> void:
	var bands: Array = _strates(vive)
	var n := bands.size()
	for i in n:
		var f := 1.0 - float(i) / n
		O.poly(ci, contour(rr, f, 11.0 + i * 1.7, 5.0 * f, 0.0), bands[i])
	var crack := cc("fissure")
	# Joints des strates (seulement là où la paroi se voit), plus marqués en haut.
	for i in range(1, n):
		var f := 1.0 - float(i) / n
		var pts := PackedVector2Array()
		for j in 121:
			var a := lerpf(-PI + 0.05, -0.05, j / 120.0)
			pts.append(wall_pt(rr, a, f, 5.0 * f * O.wave(a * 7.0, 11.0 + i * 1.7)))
		ci.draw_polyline(pts, Color(crack, 0.45), 1.6, true)
		var hi := Transform2D(0.0, Vector2(0, -2.0)) * pts
		ci.draw_polyline(hi, Color(bands[i - 1].lightened(0.18), 0.35), 1.0, true)
	# Fissures verticales et petits cailloux pris dans la terre.
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	for i in 70:
		var a := deg_to_rad(rng.randf_range(-178.0, -2.0))
		if hk(a) < 0.25:
			continue
		var f0 := rng.randf_range(0.05, 0.5)
		var f1 := minf(1.0, f0 + rng.randf_range(0.15, 0.45))
		var pts := PackedVector2Array()
		for j in 4:
			var u := lerpf(f0, f1, j / 3.0)
			pts.append(wall_pt(rr, a + rng.randf_range(-0.006, 0.006), u))
		ci.draw_polyline(pts, Color(crack, 0.55), rng.randf_range(1.0, 2.2), true)
	var peb: Dictionary = Art.mc("commun", "", "pierre")
	for i in 60:
		var a := deg_to_rad(rng.randf_range(-178.0, -2.0))
		var q := wall_pt(rr, a, rng.randf_range(0.1, 0.9))
		var s := rng.randf_range(2.5, 6.0)
		O.poly(ci, O.blob(q, s, s * 0.6, i, 0.2, 10), Color(peb["ombre"].darkened(0.35 if not vive else 0.1), 0.85))
		O.poly(ci, O.blob(q - Vector2(0.5, 0.8), s * 0.6, s * 0.35, i, 0.2, 8), Color(peb["clair"].darkened(0.4 if not vive else 0.05), 0.7))


static func _strates(vive: bool) -> Array:
	var a: Color = cc("strate_haut_vive" if vive else "strate_haut")
	var b: Color = cc("strate_bas_vive" if vive else "strate_bas")
	var out := []
	for i in 7:
		var u := i / 6.0
		var col := a.lerp(b, u)
		# Une strate sur deux plus claire (le grain de la terre), une plus rouge, une plus grise.
		match i % 3:
			0:
				col = col.lightened(0.1)
			1:
				col = col.lerp(Color("5a3a2c"), 0.18).darkened(0.05)
			2:
				col = col.lerp(Color("4a4a48"), 0.15)
		out.append(col)
	return out

static func _paint_wall_light(ci: CanvasItem, rr: float, vive: bool) -> void:
	var light := cc("lumiere")
	var top := wall_pt(rr, -PI / 2.0, 0.55)
	for i in 4:
		var k := 1.0 - i * 0.22
		O.poly(ci, O.blob(top, rr * 0.75 * k, H * 0.42 * k, 2.0 + i, 0.08, 40), Color(light, (0.05 if not vive else 0.08)))
	# Côtés et pied : la paroi s'enfonce dans l'ombre.
	var n := 96
	var shade := Color(0.03, 0.02, 0.025)
	for i in n:
		var a0 := TAU * i / n
		var a1 := TAU * (i + 1) / n
		var side := 1.0 - hk((a0 + a1) * 0.5)
		if side > 0.05:
			O.poly(ci, PackedVector2Array([wall_pt(rr, a0, 0.0), wall_pt(rr, a1, 0.0), wall_pt(rr, a1, 1.0), wall_pt(rr, a0, 1.0)]), Color(shade, 0.35 * side))
		O.poly(ci, PackedVector2Array([wall_pt(rr, a0, 0.0), wall_pt(rr, a1, 0.0), wall_pt(rr, a1, 0.22), wall_pt(rr, a0, 0.22)]), Color(shade, 0.28))


# --- Ce que la paroi garde entre les poches ---

## Entre les poches, pris dans les strates : os de colosses, coques de graines, spirales fossiles, un
## éclat de menhir gravé (le même sceau que dehors).
static func _paint_wall_fossils(ci: CanvasItem, rr: float, vive: bool) -> void:
	var bone := Art.bc("os").darkened(0.5 if not vive else 0.3)
	var bpal := {"clair": bone, "ombre": bone.darkened(0.4), "reflet": bone.lightened(0.2)}
	var spots := [[-178.0, 0.45, "os"], [-152.0, 0.62, "coque"], [-123.0, 0.3, "spirale"], [-97.0, 0.78, "os"],
		[-80.0, 0.28, "eclat"], [-58.0, 0.6, "spirale"], [-29.0, 0.32, "coque"], [-2.0, 0.5, "os"],
		[-160.0, 0.2, "spirale"], [-115.0, 0.82, "coque"], [-48.0, 0.84, "os"], [-6.0, 0.8, "spirale"], [-174.0, 0.8, "coque"]]
	for sp in spots:
		var a := deg_to_rad(float(sp[0]))
		var p := wall_pt(rr, a, float(sp[1]))
		var s := 0.75 + 0.45 * hk(a)
		O.poly(ci, O.blob(p + Vector2(0, 3), 30.0 * s, 16.0 * s, a * 7.0, 0.2, 18), Color(0.03, 0.02, 0.02, 0.22))
		match str(sp[2]):
			"os":
				var rib := O.curve(p + Vector2(-26, 6) * s, p + Vector2(0, -14) * s, p + Vector2(24, 4) * s, 10)
				O.brush(ci, rib, 8.0 * s, Ink.encre(), 0.3, 0.6)
				O.brush(ci, rib, 5.5 * s, bpal["ombre"], 0.3, 0.6)
				O.brush(ci, Transform2D(0.0, Vector2(-1, -1)) * rib, 2.2 * s, bpal["clair"], 0.3, 0.6)
				O.part(ci, O.blob(p + Vector2(-30, 8) * s, 7.0 * s, 5.0 * s, a, 0.15, 10), bpal, 1.2, 1.0, 0.4)
			"coque":
				var shell := O.blob(p, 20.0 * s, 11.0 * s, a, 0.06, 20, -0.4)
				var husk := _ecorce(vive)
				O.part(ci, shell, husk, 1.4, 1.0, 0.5)
				for j in 4:
					var u := -0.6 + 0.4 * j
					ci.draw_line(p + Vector2(-16 * s, u * 8.0 * s).rotated(-0.4), p + Vector2(16 * s, u * 6.0 * s).rotated(-0.4), Color(husk["ombre"], 0.8), 1.2, true)
			"spirale":
				var pal: Dictionary = Art.mc("commun", "", "pierre")
				var dpal := {"clair": pal["clair"].darkened(0.45), "ombre": pal["ombre"].darkened(0.45), "reflet": pal["reflet"].darkened(0.4)}
				O.part(ci, O.blob(p, 17.0 * s, 13.0 * s, a, 0.1, 18), dpal, 1.3, 1.0, 0.4)
				var sp2 := PackedVector2Array()
				for j in 22:
					var u := j * 0.55
					sp2.append(p + Vector2(cos(u), sin(u) * 0.8) * (1.0 + j * 0.65) * s)
				ci.draw_polyline(sp2, Color(dpal["ombre"].darkened(0.3), 0.9), 1.5, true)
			"eclat":
				var pal: Dictionary = Art.mc("commun", "", "pierre")
				var dpal := {"clair": pal["clair"].darkened(0.4), "ombre": pal["ombre"].darkened(0.4), "reflet": pal["reflet"].darkened(0.35)}
				var frag := PackedVector2Array([p + Vector2(-22, 10) * s, p + Vector2(-16, -18) * s, p + Vector2(4, -24) * s, p + Vector2(10, -6) * s, p + Vector2(24, 2) * s, p + Vector2(18, 12) * s])
				O.part(ci, frag, dpal, 1.4, 1.0, 0.5)
				var glyph := Color(Art.bc("braise").darkened(0.55), 0.8) if not vive else Color(Art.mc("commun", "", "seve"), 0.8)
				var g := PackedVector2Array()
				for j in 14:
					var u := j * 0.62
					g.append(p + Vector2(-2, -4) * s + Vector2(cos(u), sin(u)) * (1.0 + j * 0.6) * s)
				ci.draw_polyline(g, glyph, 1.4, true)


## Un rideau de racines fines qui pendent de la lèvre sur la paroi du fond, de longueurs inégales.
static func _paint_root_curtain(ci: CanvasItem, rr: float, vive: bool) -> void:
	var bark := _ecorce(vive)
	var rng := RandomNumberGenerator.new()
	rng.seed = 919
	for i in 46:
		var a := deg_to_rad(rng.randf_range(-176.0, -4.0))
		var k := hk(a)
		if k < 0.2:
			continue
		var top := wall_pt(rr, a, 1.0) + Vector2(0, 4)
		var l := H * k * rng.randf_range(0.25, 0.8)
		var sway := rng.randf_range(-10.0, 10.0)
		var pts := PackedVector2Array([top, top + Vector2(sway * 0.3, l * 0.35), top + Vector2(sway * 0.8, l * 0.7), top + Vector2(sway, l)])
		var w := rng.randf_range(1.6, 4.2)
		O.brush(ci, pts, w + 1.2, Color(Ink.encre(), 0.8), 1.0, 0.0)
		O.brush(ci, pts, w, bark["ombre"].lightened(0.06), 1.0, 0.0)
		if w > 3.0:
			O.brush(ci, Transform2D(0.0, Vector2(-0.6, 0)) * pts, w * 0.35, bark["clair"], 1.0, 0.0)
		# Radicelles qui s'en détachent.
		var q := pts[2]
		ci.draw_polyline(PackedVector2Array([q, q + Vector2(5, 6), q + Vector2(7, 14)]), Color(bark["ombre"], 0.9), 1.0, true)


## Sur la lèvre, tout autour : herbe sèche, brindilles de ronce, cailloux ; des tiges mortes pendent
## sur la paroi du fond. Ravivée : l'herbe reverdit.
static func _paint_lip_growth(ci: CanvasItem, rr: float, vive: bool) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 313
	var dry1: Color = Art.mc("ronce", "fletri", "touffe")
	var dry2: Color = Art.mc("ronce", "fletri", "touffe_2")
	var live1: Color = Art.mc("commun", "", "seve").darkened(0.35)
	var live2: Color = Art.mc("commun", "", "seve_sombre")
	var thorn: Dictionary = Art.mc("ronce", "ravive" if vive else "fletri", "ronce")
	var peb: Dictionary = Art.mc("commun", "", "pierre")
	var dim := {"clair": peb["clair"].darkened(0.45), "ombre": peb["ombre"].darkened(0.45), "reflet": peb["reflet"].darkened(0.5)}
	for i in 72:
		var a := TAU * i / 72.0 + rng.randf_range(-0.03, 0.03)
		var q := wall_pt(rr, a, 1.0, 12.0 + rng.randf_range(-3.0, 6.0))
		if i % 2 == 0:
			O.tuft(ci, q, rng.randf_range(9.0, 15.0), live1 if vive else dry1, live2 if vive else dry2, i, not vive)
		elif i % 5 == 1:
			var to := q + Vector2.from_angle(rng.randf_range(-PI, 0.0)) * rng.randf_range(16.0, 28.0)
			var pts := O.curve(q, q.lerp(to, 0.5) + Vector2(0, -6), to, 6)
			O.brush(ci, pts, 3.5, Ink.encre(), 1.0, 0.3)
			O.brush(ci, pts, 2.2, thorn["ombre"], 1.0, 0.3)
			for j in [2, 4]:
				var d := (pts[j + 1] - pts[j - 1]).normalized()
				O.poly(ci, PackedVector2Array([pts[j] - d * 1.5, pts[j] + d * 1.5, pts[j] + d.orthogonal() * 4.0]), thorn["ombre"])
		else:
			O.pebble(ci, q + Vector2(0, 2), rng.randf_range(2.5, 5.0), dim, i)
		# Une tige morte qui pend sur la paroi.
		var k := hk(a)
		if k > 0.35 and i % 3 == 0:
			var top := wall_pt(rr, a, 1.0, 2.0)
			var l := rng.randf_range(12.0, 30.0) * k
			ci.draw_polyline(PackedVector2Array([top, top + Vector2(2, l * 0.5), top + Vector2(-1, l)]), Color(dry2.darkened(0.3) if not vive else live2, 0.9), 1.4, true)


# --- Les six poches des strates ---

static func _paint_poche(ci: CanvasItem, rr: float, reg: String, a: float, vive: bool) -> void:
	var p := wall_pt(rr, a, 0.5)
	var s := 1.15 + 0.35 * hk(a)
	# Un creux plus sombre dans la terre, où la chose est prise (bord fondu).
	for i in 3:
		var k := 1.0 - 0.25 * i
		O.poly(ci, O.blob(p + Vector2(0, 4), 64.0 * s * k, 34.0 * s * k, a * 10.0, 0.2, 28), Color(0.03, 0.02, 0.02, 0.14))
	match reg:
		"ronce":
			_poche_ronce(ci, p, s, vive)
		"spore":
			_poche_spore(ci, p, s, vive)
		"vent":
			_poche_vent(ci, p, s, vive)
		"seve":
			_poche_seve(ci, p, s, vive, rr, a)
		"aube":
			_poche_aube(ci, p, s, vive)
		"racine":
			_poche_racine(ci, p, s, vive)
	if vive:
		# Ravivée : sa lueur, et ses fleurs sur la lèvre au-dessus.
		var glow: Color = _col(reg, true, "fleur")
		for i in 3:
			var k := 1.0 - 0.28 * i
			O.poly(ci, O.blob(p, 72.0 * s * k, 42.0 * s * k, a, 0.15, 24), Color(glow, 0.06))
		var lip := wall_pt(rr, a, 1.0)
		var tf: Array = [_col(reg, true, "touffe"), _col(reg, true, "touffe_2")]
		for i in 5:
			var q := lip + Vector2((i - 2.0) * 20.0 * s, 5.0 + 3.0 * (i % 2))
			O.tuft(ci, q, 13.0 * s, tf[0], tf[1], 31 * i + int(a * 100.0))
		O.flower(ci, lip + Vector2(-10.0 * s, 4.0), 5.5 * s, _col(reg, true, "fleur"), Color(1.0, 0.92, 0.7))
		O.flower(ci, lip + Vector2(16.0 * s, 6.0), 4.5 * s, _col(reg, true, "fleur"), Color(1.0, 0.92, 0.7), 0.8)


static func _poche_ronce(ci: CanvasItem, p: Vector2, s: float, vive: bool) -> void:
	var pal := _pal("ronce", vive, "ronce")
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for i in 5:
		var a := -PI * 0.9 + i * 0.45 + rng.randf_range(-0.15, 0.15)
		var l := rng.randf_range(40.0, 70.0) * s
		var from := p + Vector2(rng.randf_range(-14, 14), rng.randf_range(-6, 6)) * s
		var mid := from + Vector2.from_angle(a + 0.4) * l * 0.5
		var to := from + Vector2.from_angle(a) * l
		var pts := O.curve(from, mid, to, 8)
		O.brush(ci, pts, 7.0 * s, Ink.encre(), 1.0, 0.0)
		O.brush(ci, pts, 5.0 * s, pal["ombre"], 1.0, 0.0)
		O.brush(ci, pts, 2.2 * s, pal["clair"], 1.0, 0.0)
		for j in range(1, 8, 2):
			var q := pts[j]
			var d := (pts[j + 1] - pts[j - 1]).normalized()
			var nrm := d.orthogonal() * (1.0 if j % 4 == 1 else -1.0)
			O.poly(ci, PackedVector2Array([q - d * 2.5 * s, q + d * 2.5 * s, q + (nrm * 6.0 + d * 2.0) * s]), pal["ombre"].darkened(0.3))
	if vive:
		O.flower(ci, p + Vector2(-18, -16) * s, 7.0 * s, _col("ronce", true, "fleur"), _col("ronce", true, "fleur_coeur"))
		O.flower(ci, p + Vector2(20, -4) * s, 6.0 * s, _col("ronce", true, "fleur"), _col("ronce", true, "fleur_coeur"), 0.7)
	else:
		for i in 3:
			ci.draw_circle(p + Vector2(-20 + 18 * i, -10 + 6 * (i % 2)) * s, 2.6 * s, _col("ronce", false, "fruit"))


static func _poche_spore(ci: CanvasItem, p: Vector2, s: float, vive: bool) -> void:
	var pal := _pal("spore", vive, "chapeau")
	var foot := _pal("spore", vive, "pied")
	# Trois chapeaux en console, pris dans la paroi, du plus grand au plus petit.
	var spots := [[Vector2(-16, 6), 30.0], [Vector2(18, -10), 22.0], [Vector2(-2, -24), 15.0]]
	for sp in spots:
		var c: Vector2 = p + sp[0] * s
		var w: float = sp[1] * s
		var shelf := PackedVector2Array()
		for i in 13:
			var u := PI + PI * i / 12.0
			shelf.append(c + Vector2(cos(u) * w, sin(u) * w * 0.55))
		shelf.append(c + Vector2(w * 0.7, w * 0.12))
		shelf.append(c + Vector2(-w * 0.7, w * 0.12))
		O.part(ci, shelf, pal, 1.6, 1.0, 0.7)
		# Lames sous le chapeau.
		ci.draw_line(c + Vector2(-w * 0.6, w * 0.08), c + Vector2(w * 0.6, w * 0.08), foot["ombre"], 2.0 * s, true)
		if vive:
			for j in 3:
				ci.draw_circle(c + Vector2((j - 1) * w * 0.35, -w * 0.3), 1.8 * s, Color(_col("spore", true, "lueur"), 0.9))


static func _poche_vent(ci: CanvasItem, p: Vector2, s: float, vive: bool) -> void:
	var pal := _pal("vent", vive, "pierre")
	# Ardoises en lits penchés, aux bords cassés, qui se chevauchent.
	var rng := RandomNumberGenerator.new()
	rng.seed = 23
	for i in 4:
		var c := p + Vector2(-20 + 13 * i, -18 + 11 * i) * s
		var w := rng.randf_range(30.0, 42.0) * s
		var h := rng.randf_range(7.0, 11.0) * s
		var tilt := rng.randf_range(-0.28, -0.08)
		var slab := PackedVector2Array()
		for v in 7:
			var u := v / 6.0
			slab.append(c + Vector2(lerpf(-w, w, u), -h * (0.6 + 0.4 * rng.randf())).rotated(tilt))
		for v in 6:
			var u := 1.0 - (v + 0.5) / 6.0
			slab.append(c + Vector2(lerpf(-w, w, u), h * (0.5 + 0.5 * rng.randf())).rotated(tilt))
		O.part(ci, slab, pal, 1.2, 1.0, 0.5)
		ci.draw_line(c + Vector2(-w * 0.7, -h * 0.1).rotated(tilt), c + Vector2(w * 0.6, -h * 0.25).rotated(tilt), Color(pal["reflet"], 0.4), 1.0, true)
	# Une plume coincée entre deux lits.
	var plume: Color = _col("vent", vive, "plume")
	var shadow: Color = _col("vent", vive, "plume_ombre")
	var base := p + Vector2(10, -4) * s
	var tip := base + Vector2(30, -28) * s
	var pts := O.curve(base, base.lerp(tip, 0.5) + Vector2(-5, -3) * s, tip, 6)
	O.brush(ci, pts, 10.0 * s, shadow, 0.6, 0.0)
	O.brush(ci, pts, 7.0 * s, plume, 0.6, 0.0)
	ci.draw_polyline(pts, shadow.darkened(0.2), 1.0 * s, true)


static func _poche_seve(ci: CanvasItem, p: Vector2, s: float, vive: bool, rr: float, a: float) -> void:
	var pal := _pal("seve", vive, "liane")
	var sap := _pal("seve", vive, "seve")
	var leaf: Color = _col("seve", vive, "feuille")
	# Une fente d'où sortent des lianes qui pendent en boucles, et la sève qui suinte jusqu'au pied.
	O.poly(ci, O.blob(p + Vector2(0, -18) * s, 34.0 * s, 7.0 * s, 4.0, 0.3, 20), Color(0.02, 0.015, 0.015, 0.8))
	var rng := RandomNumberGenerator.new()
	rng.seed = 41
	for i in 5:
		var from := p + Vector2(-26 + 13 * i, -18 + rng.randf_range(-3, 3)) * s
		var drop := rng.randf_range(28.0, 52.0) * s
		var sway := rng.randf_range(-16.0, 16.0) * s
		var pts := PackedVector2Array([from, from + Vector2(sway * 0.4, drop * 0.35), from + Vector2(sway, drop * 0.7), from + Vector2(sway * 0.6 + 4.0 * s, drop)])
		O.brush(ci, pts, 6.0 * s, Ink.encre(), 1.0, 0.0)
		O.brush(ci, pts, 4.4 * s, pal["ombre"], 1.0, 0.0)
		O.brush(ci, Transform2D(0.0, Vector2(-1, -1) * s) * pts, 1.8 * s, pal["clair"], 1.0, 0.0)
		for j in 2:
			var q := pts[1 + j]
			var side := 1.0 if (i + j) % 2 else -1.0
			O.poly(ci, O.blob(q + Vector2(side * 5.0, 0) * s, 5.0 * s, 2.4 * s, i + j, 0.1, 10, side * 0.6), leaf)
	var drip_top := p + Vector2(4, -14) * s
	var foot := wall_pt(rr, a + 0.02, 0.02)
	var drip := PackedVector2Array([drip_top, drip_top.lerp(foot, 0.5) + Vector2(3, 0), foot])
	O.brush(ci, drip, 5.0 * s, sap["ombre"], 1.0, 0.6)
	O.brush(ci, drip, 2.4 * s, sap["clair"], 1.0, 0.6)
	O.poly(ci, O.blob(foot + Vector2(0, 6), 22.0 * s, 7.0 * s, a, 0.15, 18), Color(sap["clair"], 0.6 if vive else 0.4))
	O.poly(ci, O.blob(foot + Vector2(-3, 5), 11.0 * s, 3.0 * s, a, 0.1, 12), Color(sap["reflet"], 0.6))


static func _poche_aube(ci: CanvasItem, p: Vector2, s: float, vive: bool) -> void:
	var pal := _pal("aube", vive, "verre")
	var nacre := _pal("aube", vive, "nacre")
	O.part(ci, O.blob(p + Vector2(0, 10) * s, 34.0 * s, 12.0 * s, 3.0, 0.2, 18), nacre, 1.2, 1.0, 0.5)
	# Prismes de cristal, pointe vers le haut et vers la lumière.
	var spikes := [[-18.0, 30.0, -0.35], [-4.0, 46.0, -0.08], [12.0, 36.0, 0.2], [24.0, 22.0, 0.45], [-28.0, 18.0, -0.6]]
	for sp in spikes:
		var b := p + Vector2(float(sp[0]), 8.0) * s
		var h: float = float(sp[1]) * s
		var dir := Vector2.UP.rotated(float(sp[2]))
		var side := dir.orthogonal() * h * 0.17
		var pr := PackedVector2Array([b - side, b - side + dir * h * 0.75, b + dir * h, b + side + dir * h * 0.75, b + side])
		O.part(ci, pr, pal, 1.2, 1.0, 0.9)
		ci.draw_line(b + dir * h * 0.05, b + dir * h * 0.9, Color(pal["reflet"], 0.7), 1.2 * s, true)


static func _poche_racine(ci: CanvasItem, p: Vector2, s: float, vive: bool) -> void:
	var pal := _pal("racine", vive, "bois")
	var amber: Color = _col("racine", vive, "ambre")
	# Bout d'un tronc pétrifié pris dans la terre : ses cernes, et de l'ambre qui a coulé.
	var c := p + Vector2(-4, -2) * s
	O.part(ci, O.blob(c + Vector2(10, 2) * s, 40.0 * s, 16.0 * s, 1.0, 0.08, 22, -0.15), pal, 1.4, 1.0, 0.4)
	O.part(ci, O.blob(c - Vector2(16, 0) * s, 20.0 * s, 18.0 * s, 2.0, 0.1, 22), pal, 1.4, 1.0, 0.6)
	for i in 3:
		ci.draw_arc(c - Vector2(16, 0) * s, (5.0 + 5.0 * i) * s, 0.0, TAU, 20, Color(pal["ombre"], 0.8), 1.2 * s, true)
	for i in 3:
		var q := c + Vector2(6 + 12 * i, 12 + 3 * (i % 2)) * s
		O.poly(ci, O.blob(q, 4.0 * s, 5.0 * s, i, 0.1, 10), amber.darkened(0.3))
		ci.draw_circle(q - Vector2(1, 1.5) * s, 1.6 * s, amber.lightened(0.3 if vive else 0.0))


# --- Racines de la graine ---

## Les grosses racines de la graine qui passent la lèvre au nord et pendent sur la paroi.
static func _paint_graine_roots(ci: CanvasItem, rr: float, vive: bool) -> void:
	var bark := _ecorce(vive)
	var spots := [-152.0, -121.0, -57.0, -27.0]
	for i in spots.size():
		var a := deg_to_rad(float(spots[i]))
		var side := 1.0 if i % 2 else -1.0
		var lip := wall_pt(rr, a, 1.0)
		var out := lip + Vector2.from_angle(a) * 70.0 + Vector2(side * 20.0, -30.0)
		var over := lip + Vector2(side * 6.0, -10.0)
		var down := wall_pt(rr, a + side * 0.06, 0.08)
		var bend := lip.lerp(down, 0.5) + Vector2(side * 18.0, 0)
		_root(ci, PackedVector2Array([out, over, lip + Vector2(0, 14), bend, down]), 26.0 - 4.0 * (i % 2), bark)
		# Une racine plus fine qui se détache et pend.
		var from := lip.lerp(bend, 0.6)
		_root(ci, PackedVector2Array([from, from + Vector2(-side * 24.0, 20.0), from + Vector2(-side * 30.0, 62.0)]), 8.0, bark)
	# Les racines de la graine dans la terre, au-delà de la lèvre (vues d'en haut).
	for i in 9:
		var a := deg_to_rad(-170.0 + i * 20.0)
		var lip := wall_pt(rr, a, 1.0, 14.0)
		var far := lip + Vector2.from_angle(a + 0.15) * (FADE * 0.9)
		_root(ci, PackedVector2Array([far, lip.lerp(far, 0.4) + Vector2(0, -8), lip]), 12.0, {"clair": bark["clair"].darkened(0.3), "ombre": bark["ombre"].darkened(0.35), "reflet": bark["reflet"].darkened(0.35)})

static func _root(ci: CanvasItem, pts: PackedVector2Array, w: float, pal: Dictionary) -> void:
	O.brush(ci, pts, w + 3.0, Ink.encre(), 0.9, 0.0)
	O.brush(ci, pts, w, pal["ombre"], 0.9, 0.0)
	var lit := Transform2D(0.0, Vector2(-w * 0.18, -w * 0.22)) * pts
	O.brush(ci, lit, w * 0.55, pal["clair"], 0.9, 0.0)
	var hi := Transform2D(0.0, Vector2(-w * 0.28, -w * 0.32)) * pts
	O.brush(ci, hi, w * 0.16, Color(pal["reflet"], 0.7), 0.6, 0.0)


## Les racines couchées au pied de la paroi : le mur qui tient le combat.
static func _paint_foot_roots(ci: CanvasItem, rr: float, vive: bool) -> void:
	var bark := _ecorce(vive)
	var rng := RandomNumberGenerator.new()
	rng.seed = 61
	var n := 34
	for i in n:
		var a := TAU * i / n + rng.randf_range(-0.03, 0.03)
		var a2 := a + TAU / n * 1.55
		var d := rr + 10.0 + rng.randf_range(-3.0, 5.0)
		var p1 := Vector2.from_angle(a) * d
		var p2 := Vector2.from_angle(a2) * (d + rng.randf_range(-2.0, 6.0))
		var mid := Vector2.from_angle((a + a2) * 0.5) * (d + 4.0) + Vector2(0, -3)
		_root(ci, PackedVector2Array([p1, mid, p2]), rng.randf_range(12.0, 17.0), bark)
		if vive and i % 3 == 0:
			var q := mid + Vector2(0, -8)
			O.tuft(ci, q, 10.0, Art.mc("commun", "", "seve").darkened(0.35), Art.mc("commun", "", "seve_sombre"), i)
	# Lueurs de sève prises dans les racines : éteintes, puis claires (le direct les fait battre).
	for i in 12:
		var a := TAU * (i + 0.5) / 12.0
		var q := Vector2.from_angle(a) * (rr + 12.0)
		ci.draw_circle(q, 4.0, Color(Art.mc("commun", "", "seve_clair") if vive else Art.ec("cendre", "sombre"), 0.55 if vive else 0.35))


## La racine pivot de la graine : elle descend la paroi du fond et rampe jusqu'au centre, où ses
## branches s'enfoncent dans le sol.
static func _paint_taproot(ci: CanvasItem, rr: float, vive: bool) -> void:
	var bark := _ecorce(vive)
	var top := wall_pt(rr, -PI / 2.0, 1.0) + Vector2(10, -50)
	var pts := PackedVector2Array([top, Vector2(-14, -rr - H * 0.55), Vector2(12, -rr - 6), Vector2(-16, -rr * 0.62), Vector2(8, -rr * 0.3), Vector2(0, -90)])
	# Branches qui s'en détachent, de longueurs et d'angles différents.
	var branches := [[2, -1.0, 120.0, 0.5], [3, 1.0, 160.0, 0.2], [3, -1.0, 90.0, -0.3], [4, 1.0, 110.0, -0.1], [4, -1.0, 140.0, 0.35]]
	for b in branches:
		var from: Vector2 = pts[int(b[0])].lerp(pts[int(b[0]) + 1], 0.3)
		var dir := Vector2(float(b[1]), float(b[3])).normalized()
		var l: float = b[2]
		var mid := from + dir * l * 0.5 + Vector2(0, 14).rotated(float(b[1]) * 0.5)
		_root(ci, PackedVector2Array([from, mid, from + dir * l]), 13.0, bark)
	_root(ci, pts, 48.0, bark)
	# Le collet, là où elle se fend sous le boss.
	O.poly(ci, O.blob(Vector2(0, -84), 30.0, 10.0, 5.0, 0.2, 18), Color(0.03, 0.02, 0.02, 0.4))


# --- Le sol ---

static func _paint_floor(ci: CanvasItem, rr: float, vive: bool) -> void:
	var lav0: Color = cc("sol_vif" if vive else "sol")
	var lav1: Color = cc("sol_vif_clair" if vive else "sol_clair")
	# Lavis : le disque, puis de grandes formes plus claires vers le centre et le puits.
	ci.draw_circle(Vector2.ZERO, rr, lav0)
	O.poly(ci, O.blob(Vector2(0, 30), rr * 0.82, rr * 0.74, 1.3, 0.1, 64), lav0.lerp(lav1, 0.35))
	O.poly(ci, O.blob(Vector2(-20, 60), rr * 0.55, rr * 0.48, 2.1, 0.14, 48), lav0.lerp(lav1, 0.6))
	var rng := RandomNumberGenerator.new()
	rng.seed = 314
	for i in 14:
		var q := Vector2.from_angle(rng.randf() * TAU) * sqrt(rng.randf()) * rr * 0.8
		O.poly(ci, O.blob(q, rng.randf_range(40.0, 110.0), rng.randf_range(24.0, 60.0), i, 0.2, 28), Color(lav1 if i % 2 else lav0.darkened(0.12), 0.35))
	# Le puits de lumière (où l'on arrive) éclaire le sol au sud.
	var light := cc("lumiere")
	var lp := Vector2(0, rr - 95.0)
	for i in 10:
		var k := 1.0 - i * 0.085
		O.poly(ci, O.blob(lp + Vector2(0, -20 + 4 * i), 230.0 * k, 130.0 * k, 4.0 + i * 0.3, 0.12, 40), Color(light, 0.022 if not vive else 0.028))
	# Matière : cendre tassée en plaques, fissures.
	var crack := cc("fissure")
	for i in 26:
		var q := Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(80.0, rr - 40.0)
		var pts := PackedVector2Array([q])
		var a := rng.randf() * TAU
		for j in 5:
			a += rng.randf_range(-0.7, 0.7)
			pts.append(pts[pts.size() - 1] + Vector2.from_angle(a) * rng.randf_range(8.0, 20.0))
		ci.draw_polyline(pts, Color(crack, 0.5 if not vive else 0.3), rng.randf_range(1.0, 2.0), true)
		if j_branch(i):
			var m := pts[2]
			ci.draw_polyline(PackedVector2Array([m, m + Vector2.from_angle(a + 1.2) * 14.0, m + Vector2.from_angle(a + 0.9) * 26.0]), Color(crack, 0.4 if not vive else 0.25), 1.0, true)
	if not vive:
		var ash := cc("cendre")
		for i in 22:
			var q := Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(90.0, rr * 0.88)
			O.poly(ci, O.blob(q, rng.randf_range(14.0, 34.0), rng.randf_range(7.0, 15.0), i, 0.25, 16), Color(ash, 0.16))
	else:
		var moss := cc("mousse")
		for i in 26:
			var q := Vector2.from_angle(rng.randf() * TAU) * sqrt(rng.randf()) * rr * 0.9
			O.poly(ci, O.blob(q, rng.randf_range(18.0, 46.0), rng.randf_range(9.0, 22.0), i, 0.25, 18), Color(moss, 0.32))
	# Veines de sève qui convergent vers le centre : éteintes, puis allumées.
	var vein: Color = Art.mc("commun", "", "seve_sombre").darkened(0.72).lerp(cc("sol"), 0.35) if not vive else Art.mc("commun", "", "seve")
	for i in 12:
		var a := TAU * i / 12.0 + 0.13
		var pts := PackedVector2Array()
		for j in 9:
			var u := j / 8.0
			pts.append(Vector2.from_angle(a + 0.25 * sin(u * 4.0 + i)) * lerpf(rr * 0.95, 70.0, u))
		O.brush(ci, pts, 5.0 if not vive else 6.0, Color(vein.darkened(0.3), 0.8), 0.2, 0.6)
		O.brush(ci, pts, 2.4 if not vive else 3.0, vein, 0.2, 0.6)
		if vive:
			ci.draw_polyline(pts, Color(Art.mc("commun", "", "seve_clair"), 0.45), 1.0, true)
	# Détails en grappes : galets et éclats des six régions, tombés de la paroi.
	var peb: Dictionary = Art.mc("commun", "", "pierre")
	var dim := {"clair": peb["clair"].darkened(0.45), "ombre": peb["ombre"].darkened(0.45), "reflet": peb["reflet"].darkened(0.5)}
	for g in 12:
		var gc := Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(120.0, rr - 60.0)
		for k in rng.randi_range(3, 6):
			var q := gc + Vector2(rng.randf_range(-26, 26), rng.randf_range(-14, 14))
			O.pebble(ci, q, rng.randf_range(2.5, 5.5), peb if vive else dim, g * 10.0 + k)
	# Le pied de la paroi assombrit le bord du sol.
	for i in 4:
		var w := 26.0 - i * 6.0
		ci.draw_arc(Vector2.ZERO, rr - w * 0.5, 0.0, TAU, 128, Color(0.03, 0.02, 0.02, 0.12), w, true)


static func j_branch(i: int) -> bool:
	return i % 3 == 0


## Le sceau gravé dans le sol : un double cercle brisé et ses glyphes, à peine visibles ; des fentes
## qui partent du centre, et la tache de la Flétrissure où elle dort (veines noires, braise éteinte).
## Ravivé : les gravures prennent la sève, la tache s'efface. Tout reste peu contrasté (le combat lit
## ses annonces par-dessus).
static func _paint_seal(ci: CanvasItem, rr: float, vive: bool) -> void:
	var line := Color(cc("fissure"), 0.5) if not vive else Color(Art.mc("commun", "", "seve"), 0.28)
	var lift := Color(cc("sol_clair").lightened(0.1), 0.18) if not vive else Color(Art.mc("commun", "", "seve_clair"), 0.12)
	var rng := RandomNumberGenerator.new()
	rng.seed = 707
	for ring in [0.6, 0.67]:
		var rad := rr * float(ring)
		var a := rng.randf() * TAU
		var end := a + TAU
		while a < end:
			var span := rng.randf_range(0.5, 1.3)
			var stop := minf(a + span, end)
			ci.draw_arc(Vector2(0, 1.5), rad, a, stop, 48, lift, 2.0, true)
			ci.draw_arc(Vector2.ZERO, rad, a, stop, 48, line, 2.4, true)
			a = stop + rng.randf_range(0.06, 0.22)
	for i in 16:
		var a := TAU * (i + 0.5) / 16.0
		var q := Vector2.from_angle(a) * rr * 0.635
		var t := Vector2.from_angle(a)
		var n := t.orthogonal()
		match i % 4:
			0:
				var sp := PackedVector2Array()
				for j in 12:
					var u := j * 0.7
					sp.append(q + (t * cos(u) + n * sin(u)) * (1.0 + j * 0.55))
				ci.draw_polyline(sp, line, 1.8, true)
			1:
				ci.draw_line(q - n * 8.0 - t * 6.0, q + n * 8.0 - t * 6.0, line, 2.0, true)
				ci.draw_line(q - n * 5.0 + t * 4.0, q + n * 5.0 + t * 4.0, line, 2.0, true)
			2:
				ci.draw_polyline(PackedVector2Array([q - t * 8.0 - n * 7.0, q + t * 6.0, q - t * 8.0 + n * 7.0]), line, 2.0, true)
			3:
				ci.draw_circle(q, 3.0, line)
				ci.draw_line(q - t * 9.0, q + t * 9.0, line, 1.6, true)
	# Fentes qui partent du centre.
	var crack := cc("fissure")
	for i in 11:
		var a := TAU * i / 11.0 + rng.randf_range(-0.15, 0.15)
		var pts := PackedVector2Array([Vector2.from_angle(a) * rng.randf_range(80.0, 120.0)])
		var dir := Vector2.from_angle(a)
		for j in rng.randi_range(6, 11):
			dir = dir.rotated(rng.randf_range(-0.45, 0.45)).lerp(Vector2.from_angle(a), 0.3).normalized()
			pts.append(pts[pts.size() - 1] + dir * rng.randf_range(22.0, 38.0))
		O.brush(ci, pts, 4.5, Color(crack, 0.55 if not vive else 0.3), 0.6, 1.0)
		O.brush(ci, Transform2D(0.0, Vector2(-1, -2)) * pts, 1.4, lift, 0.6, 1.0)
	if vive:
		return
	# La tache de la Flétrissure, et ses veines noires où la braise s'est éteinte.
	var stain: Color = Art.bc("ronge").darkened(0.3)
	for i in 4:
		var k := 1.0 - 0.2 * i
		O.poly(ci, O.blob(Vector2(0, -20), rr * 0.36 * k, rr * 0.28 * k, 4.0 + i, 0.18, 40), Color(stain, 0.12))
	for i in 9:
		var a := TAU * i / 9.0 + 0.3
		var pts := PackedVector2Array([Vector2.from_angle(a) * 70.0 + Vector2(0, -20)])
		var dir := Vector2.from_angle(a)
		for j in rng.randi_range(5, 8):
			dir = dir.rotated(rng.randf_range(-0.5, 0.5)).lerp(Vector2.from_angle(a), 0.3).normalized()
			pts.append(pts[pts.size() - 1] + dir * rng.randf_range(18.0, 30.0))
		O.brush(ci, pts, 6.0, Color(stain, 0.6), 0.4, 1.0)
		O.brush(ci, pts.slice(0, 4), 1.4, Color(Art.bc("braise").darkened(0.45), 0.5), 0.6, 1.0)


## Au pied de la paroi, des éboulis tombés des strates (pas au sud, où l'on arrive), et des os.
static func _paint_foot_rubble(ci: CanvasItem, rr: float, vive: bool) -> void:
	var heaps := [-155.0, -118.0, -84.0, -36.0, -8.0, 22.0, 158.0, 186.0, 142.0, 38.0]
	var strata := _strates(vive)
	for i in heaps.size():
		var a := deg_to_rad(float(heaps[i]))
		var q := Vector2.from_angle(a) * (rr - 30.0)
		Abords._rubble(ci, q, 0.55 + 0.1 * (i % 3), strata[1 + i % 3], 0.0 if vive else 0.25, 50 + i)
	var bone := Art.bc("os").darkened(0.45 if not vive else 0.25)
	var rng := RandomNumberGenerator.new()
	rng.seed = 271
	for i in 9:
		var a := rng.randf_range(-PI, PI)
		if absf(wrapf(a - PI / 2.0, -PI, PI)) < 0.6:
			continue
		Abords._bone(ci, Vector2.from_angle(a) * rng.randf_range(rr * 0.7, rr - 50.0), rng.randf() * TAU, rng.randf_range(14.0, 24.0), bone)


## Sous chaque poche, la terre de sa région : éclats morts, puis herbe et fleurs ravivées.
static func _paint_floor_regions(ci: CanvasItem, rr: float, vive: bool) -> void:
	for pk in POCHES:
		var reg := str(pk[0])
		var a := deg_to_rad(float(pk[1]))
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(reg)
		var base := Vector2.from_angle(a) * (rr - 70.0)
		if not vive:
			var chip: Color = _col(reg, false, "feuille")
			for i in 7:
				var q := base + Vector2(rng.randf_range(-50, 50), rng.randf_range(-24, 24))
				O.poly(ci, O.blob(q, rng.randf_range(3.0, 6.0), rng.randf_range(2.0, 3.5), i, 0.3, 8), Color(chip.darkened(0.25), 0.7))
			continue
		var sol: Color = _col(reg, true, "sol")
		var rot := a + PI / 2.0
		for i in 5:
			var k := 1.0 - 0.17 * i
			O.poly(ci, O.blob(base + Vector2.from_angle(a) * 8.0 * i, 110.0 * k, 52.0 * k, a + i, 0.25, 32, rot), Color(sol.lerp(_col(reg, true, "sol_clair"), i / 4.0), 0.12))
		var t1: Color = _col(reg, true, "touffe")
		var t2: Color = _col(reg, true, "touffe_2")
		for i in 14:
			var q := base + Vector2(rng.randf_range(-90, 90), rng.randf_range(-40, 40)).rotated(rot - PI / 2.0) * Vector2(1.0, 1.0)
			O.tuft(ci, q, rng.randf_range(8.0, 15.0), t1, t2, i + int(a * 50.0))
		var fl: Color = _col(reg, true, "fleur")
		var heart: Color = _col(reg, true, "fleur_coeur") if Art.MONDE[reg]["ravive"].has("fleur_coeur") else Color(1.0, 0.93, 0.72)
		for i in 6:
			var q := base + Vector2(rng.randf_range(-60, 60), rng.randf_range(-26, 26))
			O.flower(ci, q, rng.randf_range(3.5, 5.5), fl, heart, rng.randf() * TAU)


# --- La brèche au pied de la graine (centre de la fente en (0, 0)) ---

const BRECHE_BOX := Rect2(-110.0, -78.0, 220.0, 136.0)


static func paint_breche(ci: CanvasItem, vive: bool) -> void:
	var rd := 52.0
	var soil: Color = cc("croute_vive" if vive else "croute")
	# Terre retournée autour de la fente, ombre portée.
	O.cast_shadow(ci, Vector2(0, 10), rd * 2.4, 14.0, 0.25)
	O.poly(ci, O.blob(Vector2(0, 2), rd * 1.65, rd * 0.86, 1.0, 0.16, 40), soil.darkened(0.3))
	O.poly(ci, O.blob(Vector2(-4, -2), rd * 1.5, rd * 0.74, 1.6, 0.16, 40), soil)
	# La fente : on voit le fond de la paroi nord, en strates, puis le noir.
	var hole := O.blob(Vector2(0, 2), rd * 0.98, rd * 0.44, 2.4, 0.12, 36)
	O.poly(ci, hole, _strates(vive)[2].darkened(0.1))
	O.poly(ci, O.blob(Vector2(0, 8), rd * 0.92, rd * 0.36, 2.4, 0.12, 36), _strates(vive)[5].darkened(0.3))
	O.poly(ci, O.blob(Vector2(0, 13), rd * 0.82, rd * 0.27, 2.4, 0.12, 32), Color(0.02, 0.015, 0.012))
	ci.draw_polyline(hole + PackedVector2Array([hole[0]]), Color(Ink.encre(), 0.8), 1.6, true)
	# Mottes sur le bord.
	var rng := RandomNumberGenerator.new()
	rng.seed = 150
	var clod := {"clair": soil.lightened(0.12), "ombre": soil.darkened(0.35), "reflet": soil.lightened(0.3)}
	for i in 11:
		var a := TAU * i / 11.0 + rng.randf_range(-0.2, 0.2)
		var q := Vector2(cos(a) * rd * 1.22, sin(a) * rd * 0.6 + 2.0)
		O.pebble(ci, q, rng.randf_range(4.0, 7.5), clod, i)
	# Les racines de la graine qui enjambent la fente.
	var bark := _ecorce(vive)
	_root(ci, PackedVector2Array([Vector2(-rd * 1.8, -rd * 0.9), Vector2(-rd * 0.9, -rd * 0.55), Vector2(-rd * 0.3, -2), Vector2(rd * 0.05, rd * 0.2)]), 11.0, bark)
	_root(ci, PackedVector2Array([Vector2(rd * 1.7, -rd * 0.75), Vector2(rd * 1.0, -rd * 0.5), Vector2(rd * 0.7, 0), Vector2(rd * 0.75, rd * 0.35)]), 9.0, bark)
	_root(ci, PackedVector2Array([Vector2(-rd * 0.2, -rd * 1.2), Vector2(-rd * 0.1, -rd * 0.7), Vector2(rd * 0.25, -rd * 0.3)]), 7.0, bark)
	# Radicelles qui pendent dans le noir.
	for i in 5:
		var q := Vector2(-rd * 0.55 + i * rd * 0.28, -2.0 + 2.0 * (i % 2))
		ci.draw_polyline(PackedVector2Array([q, q + Vector2(2, 8), q + Vector2(-1, 14.0 + 3.0 * (i % 3))]), bark["ombre"], 1.6, true)
	if vive:
		var cols: Array = []
		for pk in POCHES:
			cols.append(_col(str(pk[0]), true, "fleur"))
		for i in 6:
			var a := PI + PI * (i + 0.5) / 6.0
			var q := Vector2(cos(a) * rd * 1.35, sin(a) * rd * 0.72 + 4.0)
			O.tuft(ci, q + Vector2(0, 4), 10.0, Art.mc("commun", "", "seve").darkened(0.3), Art.mc("commun", "", "seve_sombre"), i)
			O.flower(ci, q, 4.5, cols[i], Color(1.0, 0.93, 0.72), i)


# --- La terre autour du creux (dessinée en direct par le nœud, sans cuisson) ---

static func _far_roots(ci: CanvasItem, c: Vector2, rr: float, b: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var deep := cc("racine_terre").lerp(cc("racine_terre_vive"), b)
	var pal := {"clair": deep, "ombre": deep.darkened(0.35), "reflet": deep.lightened(0.15)}
	for i in 16:
		var a := TAU * i / 16.0 + rng.randf_range(-0.12, 0.12)
		var bend := rng.randf_range(-0.25, 0.25)
		var pts := PackedVector2Array()
		for j in 5:
			var u := j / 4.0
			pts.append(c + Vector2.from_angle(a + bend * u * u) * (rr + 60.0 + u * rng.randf_range(1200.0, 1800.0)))
		_root_flat(ci, pts, rng.randf_range(16.0, 30.0), pal)
		# Une branche.
		var k := rng.randi_range(1, 2)
		var from := pts[k]
		var dir := (pts[k + 1] - pts[k]).normalized().rotated(rng.randf_range(0.5, 0.9) * (1.0 if i % 2 else -1.0))
		_root_flat(ci, PackedVector2Array([from, from + dir * 200.0, from + dir.rotated(0.2) * 420.0]), 10.0, pal)
	var stone := cc("terre").lightened(0.08)
	for i in 70:
		var q := c + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(rr + 80.0, rr + 1800.0)
		var s := rng.randf_range(3.0, 9.0)
		ci.draw_colored_polygon(Art.ellipse(q, s, s * 0.65, 10), Color(stone, 0.6))


## Racine de la terre (vue d'en haut, peu contrastée) : un coup de pinceau sombre, sa face éclairée.
static func _root_flat(ci: CanvasItem, pts: PackedVector2Array, w: float, pal: Dictionary) -> void:
	O.brush(ci, pts, w, pal["ombre"], 1.0, 0.0)
	O.brush(ci, Transform2D(0.0, Vector2(-w * 0.12, -w * 0.15)) * pts, w * 0.6, pal["clair"], 1.0, 0.0)
	O.brush(ci, Transform2D(0.0, Vector2(-w * 0.22, -w * 0.26)) * pts, w * 0.14, Color(pal["reflet"], 0.5), 0.8, 0.0)


# --- En direct (arène) : radicelles qui frémissent, poussière ---

## Radicelles pendues à la lèvre de la paroi du fond. shake : 0 → 1 (coup de phase, percussion).
static func draw_hanging(ci: CanvasItem, c: Vector2, rr: float, t: float, shake: float, bloom: float) -> void:
	var col: Color = _ecorce(bloom > 0.5)["ombre"]
	var tipc: Color = Art.mc("commun", "", "seve_clair")
	for i in 16:
		var a := deg_to_rad(-165.0 + i * 10.0 + 3.0 * sin(i * 2.7))
		var top := c + wall_pt(rr, a, 0.97)
		var l := (34.0 + 30.0 * fposmod(i * 0.618, 1.0)) * (0.6 + 0.4 * hk(a))
		var sway := 1.6 * sin(t * 1.1 + i * 1.7) + shake * 7.0 * sin(t * 23.0 + i * 2.3)
		var pts := PackedVector2Array([top, top + Vector2(sway * 0.3, l * 0.4), top + Vector2(sway * 0.7, l * 0.75), top + Vector2(sway, l)])
		ci.draw_polyline(pts, col, 2.4 - 0.6 * (i % 2), true)
		if bloom > 0.0:
			ci.draw_circle(pts[3], 2.6 * bloom, Color(tipc, 0.8 * bloom))


## Braises des veines de la Flétrissure, autour du creux : elles battent, plus fort aux secousses, et
## des étincelles en montent. Éteintes à mesure que le creux refleurit.
static func draw_embers(ci: CanvasItem, c: Vector2, rr: float, t: float, shake: float, bloom: float) -> void:
	var off := 1.0 - clampf(bloom, 0.0, 1.0)
	if off <= 0.0:
		return
	var ember := Art.bc("braise")
	var hot := Art.bc("braise_coeur")
	var pts: Array = Abords.glows(rr)
	for i in pts.size():
		var q: Vector2 = c + pts[i]
		var beat := 0.5 + 0.5 * sin(t * (1.3 + 0.17 * (i % 5)) + i * 2.1)
		var a := (0.1 + 0.12 * beat + 0.25 * shake) * off
		ci.draw_circle(q, 9.0 + 4.0 * beat, Color(ember, a * 0.6))
		ci.draw_circle(q, 3.0 + 1.5 * beat, Color(hot, a * 1.6))
		var f := fposmod(t * 0.35 + i * 0.381, 1.0)
		ci.draw_circle(q + Vector2(6.0 * sin(t * 1.7 + i), -f * 70.0), 1.6 * (1.0 - f) + 0.6, Color(hot, 0.7 * sin(PI * f) * off))


## Poussière et grains de terre qui tombent de la lèvre après une secousse (since : secondes depuis).
static func draw_dust(ci: CanvasItem, c: Vector2, rr: float, since: float, power: float) -> void:
	if since < 0.0 or since > 2.0 or power <= 0.0:
		return
	var col := cc("poussiere")
	for i in 28:
		var a := deg_to_rad(-170.0 + i * 5.7 + 7.0 * sin(i * 3.3))
		var f0 := 0.75 + 0.25 * fposmod(i * 0.37, 1.0)
		var delay := 0.25 * fposmod(i * 0.61, 1.0)
		var u := since - delay
		if u < 0.0:
			continue
		var start := c + wall_pt(rr, a, f0)
		var fall := 260.0 * u * u + 30.0 * u
		var foot_y := (c + wall_pt(rr, a, 0.0)).y
		var q := start + Vector2(4.0 * sin(u * 3.0 + i), fall)
		if q.y > foot_y + 6.0:
			continue
		var fade := clampf(1.0 - u / 1.6, 0.0, 1.0) * power
		if i % 3 == 0:
			ci.draw_circle(q, 2.2, Color(col.darkened(0.3), 0.9 * fade))
		else:
			ci.draw_circle(q, 3.5 + 3.0 * u, Color(col, 0.28 * fade))
