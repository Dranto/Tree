## Banc de lisibilité du monde (refonte « Paysages d'herbier », tâche Q).
##
## Pose le vrai jeu (main.tscn) sur un cadre de chaque région, le héros au centre et trois Flétris autour,
## dans deux états : flétri (le Cœur vit) puis ravivé (Cœur purifié, vie peinte au sol, région apaisée).
## Pour chaque cadre, il prend cinq images du même instant en cachant des couches :
##   sol     le sol et ses fleurs seulement
##   decor   le sol et le décor (arbres, buissons, repères)
##   lieux   le décor et les Cœurs, sanctuaires, autels
##   plein   tout, sans l'interface (le héros, les Flétris)
##   annonce le « lieux » avec trois annonces d'attaque (cercle, cône, ligne) posées autour du héros
## puis mesure en niveaux de gris (CIELAB L*, 0-100) et en couleur. Les mesures décrites ici sont celles de
## tests/paysages_test.gd ; le scénario visuel « paysages » en fait un montage.
##
## Aucune dépendance au rendu du monde : la même mesure sert au jeu d'avant la refonte, à chaque tâche
## de la vague 1 (sol, décor, lieux, lumière, monde vivant) et aux régions de la vague 2.
extends RefCounted

const Regions = preload("res://scripts/regions.gd")

## Les six régions du jeu, dans l'ordre de la carte.
const REGIONS := ["ronce", "spore", "vent", "seve", "aube", "racine"]
const ETATS := ["fletri", "ravive"]
## Taille d'écran logique du jeu : tous les cadres sont mesurés en 1600×900.
const VUE := Vector2i(1600, 900)
## Pas d'échantillonnage (en pixels) des mesures de gradient et écart sur lequel on les prend.
const PAS := 2
const ECART := 3
## Différence (0-255, canal le plus touché) au-delà de laquelle un pixel compte comme « changé » entre deux couches.
const SEUIL_DIFF := 6
## Les Flétris sont des disques de ce rayon autour de leur position (px écran) pour y chercher leurs pixels.
const RAYON_PERSO := 96

## Cadre de chaque région : sorte de Flétri et position relative au héros (px du jeu). Le premier annonce une attaque.
const FLETRIS := {
	"ronce": ["tireur", "chargeur", "fletri"],
	"spore": ["traine_vase", "scissipore", "lichen"],
	"vent": ["plongeur", "souffleur", "menhir"],
	"seve": ["sangsue_vase", "crapaud", "souche"],
	"aube": ["miroitier", "prismeur", "quartz"],
	"racine": ["termite", "scarabee", "tertre"],
}
const POSITIONS := [Vector2(300, 130), Vector2(-290, 60), Vector2(40, -215)]
## Positions des annonces de test (cercle, cône, ligne) autour du héros.
const ANNONCES := [Vector2(-330, -170), Vector2(330, -150), Vector2(-60, 250)]

var tree: SceneTree
var main


## Annonces d'attaque de test : les trois formes de la charte, dessinées par Art.telegraph.
class Annonces extends Node2D:
	var progression := 0.6
	var visible_on := false

	func _draw() -> void:
		if not visible_on:
			return
		Art.telegraph(self, {"type": "cercle", "centre": Vector2(-330, -170), "rayon": 95.0}, progression, -1.0, 0.3)
		Art.telegraph(self, {"type": "cone", "centre": Vector2(330 - 80, -150), "direction": 0.0, "ouverture": 1.2, "rayon": 190.0}, progression, -1.0, 0.3)
		Art.telegraph(self, {"type": "ligne", "de": Vector2(-190, 250), "a": Vector2(80, 250), "largeur": 56.0}, progression, -1.0, 0.3)


var _annonces: Annonces


func _init(p_tree: SceneTree, p_main) -> void:
	tree = p_tree
	main = p_main


# --- Mise en place ---

## Fige le jeu : plus de robot, de vagues, de Flétris, de HUD.
func figer() -> void:
	main.autotest = false
	main.spawn_timer = 1.0e9
	# Monde vivant figé (comme les tests visuels) : la faune, les pétales et les pas fleuris qui passent
	# dans le cadre brouillent la mesure des couleurs ; le banc juge la palette, pas l'animation.
	load("res://scripts/world_life.gd").still = true
	main.player.set_physics_process(false)
	main.hud.glyphs.visible = false
	main.hud.banner_queue = []
	main.hud.banner_time = 0.0
	for h in main.all_hearts:
		h.set_physics_process(false)
	_annonces = Annonces.new()
	main.add_child(_annonces)


## Centre du cadre d'une région : un peu en retrait du Cœur, vers le centre du monde, pour que le Cœur soit
## à l'écran et que la vie peinte autour de lui couvre presque tout le cadre.
func centre(region: String) -> Vector2:
	var heart = coeur(region)
	var spot: Vector2 = heart.center
	return spot - spot.normalized() * 260.0 + Vector2(0, 40)


## Le Cœur de la région le plus proche du centre de sa tranche (un seul suffit au cadre).
func coeur(region: String):
	var best = null
	for h in main.region_hearts.get(region, []):
		if best == null or h.center.length() < best.center.length():
			best = h
	return best


func _frames(n: int) -> void:
	for i in n:
		await tree.process_frame


## Pose un cadre : héros au centre, trois Flétris autour, région dans l'état demandé. Renvoie un dictionnaire
## {region, etat, centre, persos: [{pos, rayon, kind}], coeur: Vector2}.
func poser(region: String, etat: String) -> Dictionary:
	var c := centre(region)
	var p = main.player
	p.position = c
	p.reset_physics_interpolation()
	main.camera.reset_smoothing()
	p.aim = Vector2(1, -0.2).normalized()
	p.invuln = 1.0e6
	await _frames(10)
	_vider()
	var h = coeur(region)
	if etat == "ravive":
		h._set_purified(false)
		main.ground.set_purified(region, 1.0)
		main.ground.paint(h.center, h.life_radius, 1.0)
		main.ground.finish_waves()
		await _frames(20)
	var persos := []
	var liste := []
	for i in 3:
		var e = main.spawn_enemy_kind(FLETRIS[region][i], c + POSITIONS[i], 1.0)
		e.t = 0.5
		if i == 0:
			e.state = "windup"
			e.state_t = 0.25
		else:
			e.walk = [0.6, 2.2][i - 1]
			e.moving = 1.0
		e.attack_dir = (c - e.position).normalized()
		e.face = e.attack_dir
		e.cd = 99.0
		e.set_process(false)
		e.set_physics_process(false)
		liste.append(e)
	await _frames(6)
	main.hud.banner_queue = []
	main.hud.banner_time = 0.0
	for e in liste:
		persos.append({"pos": e.position, "rayon": e.radius, "kind": FLETRIS[region][liste.find(e)]})
	return {"region": region, "etat": etat, "centre": c, "persos": persos, "coeur": h.center,
		"region_ici": main.region_at(c), "zone_vie": h.life_radius}


func _vider() -> void:
	for e in main.enemies:
		if is_instance_valid(e):
			e.queue_free()
	main.enemies = []


# --- Prise d'images ---

func _grab() -> Image:
	await RenderingServer.frame_post_draw
	var img: Image = main.get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	return img


## Cache puis rend visible chaque enfant de main qui ne fait pas partie de « garde » (les calques de l'interface
## compris), prend l'image, remet tout. « garde » : noms de variables de main ou nœuds.
func _prendre(visibles: Array, ennemis: bool, heros: bool, lieux: bool, annonces: bool) -> Image:
	var saved := []
	for n in main.get_children():
		if n is CanvasItem or n is CanvasLayer:
			saved.append([n, n.visible])
			n.visible = n in visibles
	var sv_en: bool = main.enemies_layer.visible
	var sv_pl: bool = main.player.visible
	main.enemies_layer.visible = ennemis
	main.player.visible = heros
	var sv_lieux := []
	for l in _lieux():
		sv_lieux.append([l, l.visible])
		l.visible = lieux
	_annonces.position = main.player.position
	_annonces.visible_on = annonces
	_annonces.queue_redraw()
	await _frames(1)
	var img := await _grab()
	for s in saved:
		s[0].visible = s[1]
	main.enemies_layer.visible = sv_en
	main.player.visible = sv_pl
	for s in sv_lieux:
		s[0].visible = s[1]
	_annonces.visible_on = false
	_annonces.queue_redraw()
	return img


func _lieux() -> Array:
	var out := []
	out.append_array(main.all_hearts)
	out.append_array(main.sanctuaries)
	out.append_array(main.altars)
	return out


## Les cinq images d'un cadre déjà posé.
func prendre(cadre: Dictionary) -> Dictionary:
	var sol_et_fleurs := [main.ground, main.flora]
	var tout := sol_et_fleurs + [main.actors_layer]
	var out := {}
	out["sol"] = await _prendre(sol_et_fleurs, false, false, false, false)
	out["decor"] = await _prendre(tout, false, false, false, false)
	out["lieux"] = await _prendre(tout, false, false, true, false)
	out["plein"] = await _prendre(tout, true, true, true, false)
	out["annonce"] = await _prendre(tout + [_annonces], false, false, true, true)
	return out


# --- Mesures ---

static var _lut_lin := PackedFloat32Array()
static var _lut_l := PackedFloat32Array()


static func _init_lut() -> void:
	if not _lut_lin.is_empty():
		return
	_lut_lin.resize(256)
	for i in 256:
		_lut_lin[i] = Color(i / 255.0, 0, 0).srgb_to_linear().r
	_lut_l.resize(4097)
	for i in 4097:
		var y := i / 4096.0
		_lut_l[i] = 116.0 * (pow(y, 1.0 / 3.0) if y > 0.008856 else 7.787 * y + 16.0 / 116.0) - 16.0


## Luminosité CIELAB L* (0-100) de chaque pixel d'une image RGB8.
static func luminosites(img: Image) -> PackedFloat32Array:
	_init_lut()
	var d := img.get_data()
	var n := d.size() / 3
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var y := 0.2126 * _lut_lin[d[i * 3]] + 0.7152 * _lut_lin[d[i * 3 + 1]] + 0.0722 * _lut_lin[d[i * 3 + 2]]
		out[i] = _lut_l[int(clampf(y, 0.0, 1.0) * 4096.0)]
	return out


## Masque (1 = pixel différent) entre deux images, élargi de « grow » pixels (disque approché par un carré).
static func masque_diff(a: Image, b: Image, grow := 0, disque := Vector2i(-1, -1), rayon := 0) -> PackedByteArray:
	var w := a.get_width()
	var h := a.get_height()
	var da := a.get_data()
	var db := b.get_data()
	var m := PackedByteArray()
	m.resize(w * h)
	var x0 := 0
	var x1 := w
	var y0 := 0
	var y1 := h
	if disque.x >= 0:
		x0 = maxi(0, disque.x - rayon)
		x1 = mini(w, disque.x + rayon + 1)
		y0 = maxi(0, disque.y - rayon)
		y1 = mini(h, disque.y + rayon + 1)
	for y in range(y0, y1):
		for x in range(x0, x1):
			var i := (y * w + x) * 3
			if absi(da[i] - db[i]) > SEUIL_DIFF or absi(da[i + 1] - db[i + 1]) > SEUIL_DIFF or absi(da[i + 2] - db[i + 2]) > SEUIL_DIFF:
				if disque.x >= 0 and Vector2(x - disque.x, y - disque.y).length() > rayon:
					continue
				m[y * w + x] = 1
	if grow > 0:
		m = dilater(m, w, h, grow)
	return m


static func dilater(m: PackedByteArray, w: int, h: int, r: int) -> PackedByteArray:
	# Deux passes (horizontale puis verticale) : un carré de côté 2r+1.
	var t := PackedByteArray()
	t.resize(w * h)
	for y in h:
		var run := 0
		for x in w:
			if m[y * w + x] == 1:
				for k in range(maxi(0, x - r), mini(w, x + r + 1)):
					t[y * w + k] = 1
	var o := PackedByteArray()
	o.resize(w * h)
	for x in w:
		for y in h:
			if t[y * w + x] == 1:
				for k in range(maxi(0, y - r), mini(h, y + r + 1)):
					o[k * w + x] = 1
	return o


static func masque_compte(m: PackedByteArray) -> int:
	var n := 0
	for v in m:
		n += v
	return n


## Gradient « p95 » : 95e centile de |L(x) − L(x + ECART)| (horizontal et vertical) sur les pixels du masque
## (ou de l'image entière), échantillonnés tous les PAS pixels. C'est la force du contraste fin de l'image.
static func gradient_p95(lum: PackedFloat32Array, w: int, h: int, masque := PackedByteArray(), pourcent := 95.0) -> float:
	var hist := PackedInt32Array()
	hist.resize(201)   # 0,5 L* par case
	var total := 0
	var use := not masque.is_empty()
	for y in range(0, h - ECART, PAS):
		for x in range(0, w - ECART, PAS):
			var i := y * w + x
			if use and masque[i] == 0:
				continue
			var l := lum[i]
			var a := absf(l - lum[i + ECART])
			var b := absf(l - lum[i + ECART * w])
			hist[mini(200, int(a * 2.0))] += 1
			hist[mini(200, int(b * 2.0))] += 1
			total += 2
	if total == 0:
		return 0.0
	var cible := total * pourcent / 100.0
	var acc := 0
	for k in 201:
		acc += hist[k]
		if acc >= cible:
			return k / 2.0
	return 100.0


## Couleur moyenne et luminosité moyenne des pixels d'un masque (image RGB8).
static func moyenne(img: Image, masque: PackedByteArray) -> Color:
	var d := img.get_data()
	var r := 0.0
	var g := 0.0
	var b := 0.0
	var n := 0
	for i in masque.size():
		if masque[i] == 1:
			r += d[i * 3]
			g += d[i * 3 + 1]
			b += d[i * 3 + 2]
			n += 1
	if n == 0:
		return Color.MAGENTA
	return Color(r / n / 255.0, g / n / 255.0, b / n / 255.0)


## Couleur moyenne d'un rectangle de l'image (un pixel sur 4).
static func moyenne_rect(img: Image, rect: Rect2i) -> Color:
	var w := img.get_width()
	var d := img.get_data()
	var r := 0.0
	var g := 0.0
	var b := 0.0
	var n := 0
	for y in range(rect.position.y, rect.end.y, PAS * 2):
		for x in range(rect.position.x, rect.end.x, PAS * 2):
			var i := (y * w + x) * 3
			r += d[i]
			g += d[i + 1]
			b += d[i + 2]
			n += 1
	return Color(r / n / 255.0, g / n / 255.0, b / n / 255.0)


## Écran du point monde « pos » (la caméra suit le héros au centre de l'écran, zoom 1).
func ecran(pos: Vector2, cadre: Dictionary) -> Vector2i:
	var cam: Vector2 = main.camera.get_screen_center_position()
	var off := pos - cam
	return Vector2i(int(VUE.x / 2 + off.x), int(VUE.y / 2 + off.y))


## Nombre d'éléments de décor dans l'écran (mesure de densité). Utilise main.flora.decor_on_screen(rect) si le
## moteur du décor l'expose (tâche D), sinon compte les nœuds de flora.trees visibles.
func densite(cadre: Dictionary) -> int:
	var cam: Vector2 = main.camera.get_screen_center_position()
	var rect := Rect2(cam - Vector2(VUE) / 2.0, Vector2(VUE))
	var flora = main.flora
	if flora.has_method("decor_on_screen"):
		return int(flora.decor_on_screen(rect))
	var n := 0
	for t in flora.trees:
		if is_instance_valid(t) and t.visible and rect.has_point(t.global_position):
			n += 1
	return n


## Toutes les mesures d'un cadre posé, à partir de ses images. Voir la liste des clés dans paysages_test.gd.
func mesurer(cadre: Dictionary, im: Dictionary) -> Dictionary:
	var w := VUE.x
	var h := VUE.y
	var lum_sol := luminosites(im["sol"])
	var lum_decor := luminosites(im["decor"])
	var lum_plein := luminosites(im["plein"])
	var lum_lieux := luminosites(im["lieux"])
	var m := {"region": cadre["region"], "etat": cadre["etat"], "region_ici": cadre["region_ici"]}
	m["sol_p95"] = gradient_p95(lum_sol, w, h)
	# Couleur du sol au centre du cadre (400×300 autour du héros) : l'état de la région, sans les bords.
	m["sol_centre"] = moyenne_rect(im["sol"], Rect2i(VUE.x / 2 - 200, VUE.y / 2 - 150, 400, 300))
	# Décor : les pixels qui changent entre « sol » et « decor », élargis de 3 px (le contour compte).
	var md := masque_diff(im["sol"], im["decor"], 3)
	m["decor_pixels"] = masque_compte(md)
	m["decor_p95"] = gradient_p95(lum_decor, w, h, md) if m["decor_pixels"] > 400 else -1.0
	# Lieux : ce que l'on ajoute entre « decor » et « lieux ».
	var ml := masque_diff(im["decor"], im["lieux"], 3)
	m["lieux_pixels"] = masque_compte(ml)
	m["lieux_p95"] = gradient_p95(lum_lieux, w, h, ml) if m["lieux_pixels"] > 400 else -1.0
	m["densite"] = densite(cadre)
	# Personnages : le héros puis les trois Flétris.
	var persos := []
	var liste := [{"pos": main.player.position, "rayon": 16.0, "kind": "heros"}]
	liste.append_array(cadre["persos"])
	for pe in liste:
		var c := ecran(pe["pos"], cadre)
		var mp := masque_diff(im["lieux"], im["plein"], 0, c, RAYON_PERSO)
		var n := masque_compte(mp)
		var r := {"kind": pe["kind"], "pixels": n}
		if n < 40:
			r["trouve"] = false
			persos.append(r)
			continue
		r["trouve"] = true
		var mg := dilater(mp, w, h, 3)
		# Sol voisin : les pixels du disque autour du personnage qui ne changent pas, vus sans personnage.
		var anneau := PackedByteArray()
		anneau.resize(w * h)
		var x0 := maxi(0, c.x - RAYON_PERSO)
		var x1 := mini(w, c.x + RAYON_PERSO + 1)
		var y0 := maxi(0, c.y - RAYON_PERSO)
		var y1 := mini(h, c.y + RAYON_PERSO + 1)
		for y in range(y0, y1):
			for x in range(x0, x1):
				if mg[y * w + x] == 0 and Vector2(x - c.x, y - c.y).length() <= RAYON_PERSO:
					anneau[y * w + x] = 1
		var col_p := moyenne(im["plein"], mp)
		var col_s := moyenne(im["lieux"], anneau)
		r["couleur"] = col_p
		r["sol"] = col_s
		r["dl"] = absf(Art.lab(col_p).x - Art.lab(col_s).x)
		r["de"] = Art.delta_e(col_p, col_s)
		r["p95"] = gradient_p95(lum_plein, w, h, mg)
		persos.append(r)
	m["persos"] = persos
	# Annonces d'attaque : les pixels ajoutés entre « lieux » et « annonce », ΔE médian avec ce qu'ils recouvrent.
	var annonces := []
	for i in 3:
		var c := ecran(main.player.position + ANNONCES[i], cadre)
		var ma := masque_diff(im["lieux"], im["annonce"], 0, c, 200)
		var vals := _delta_e_pixels(im["lieux"], im["annonce"], ma)
		var r := {"pixels": vals.size()}
		if vals.size() < 200:
			r["de_median"] = 0.0
			r["de_p10"] = 0.0
		else:
			vals.sort()
			r["de_median"] = vals[vals.size() / 2]
			r["de_p10"] = vals[vals.size() / 10]
		annonces.append(r)
	m["annonces"] = annonces
	return m


static func _delta_e_pixels(a: Image, b: Image, masque: PackedByteArray) -> PackedFloat32Array:
	var da := a.get_data()
	var db := b.get_data()
	var out := PackedFloat32Array()
	var k := 0
	for i in masque.size():
		if masque[i] == 1:
			k += 1
			if k % 3 != 0:
				continue
			var ca := Color(da[i * 3] / 255.0, da[i * 3 + 1] / 255.0, da[i * 3 + 2] / 255.0)
			var cb := Color(db[i * 3] / 255.0, db[i * 3 + 1] / 255.0, db[i * 3 + 2] / 255.0)
			out.append(Art.delta_e(ca, cb))
	return out


## Image « plein » d'un cadre posé (tout sauf l'interface) : le montage du scénario visuel « paysages ».
func image_pleine() -> Image:
	return await _prendre([main.ground, main.flora, main.actors_layer], true, true, true, false)


## Montage de plusieurs images « plein » : colonnes × lignes, chaque tuile à « tuile » px.
static func montage(images: Array, colonnes: int, tuile: Vector2i) -> Image:
	var lignes := ceili(images.size() / float(colonnes))
	var out := Image.create(colonnes * tuile.x, lignes * tuile.y, false, Image.FORMAT_RGB8)
	for i in images.size():
		var im: Image = images[i].duplicate()
		im.resize(tuile.x, tuile.y, Image.INTERPOLATE_LANCZOS)
		out.blit_rect(im, Rect2i(Vector2i.ZERO, tuile), Vector2i((i % colonnes) * tuile.x, (i / colonnes) * tuile.y))
	return out
