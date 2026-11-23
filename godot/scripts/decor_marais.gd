## Décor du marais (région de Spore, « decor » : {"kind": "marais"} dans data/regions/spore.json) :
## les arbres du monde y sont remplacés par des touffes de champignons, et le marais y ajoute des
## flaques d'eau dormante, des roseaux, des troncs pourris (obstacles) et deux champignons géants.
## Mort, tout est gris et violacé, les chapeaux tombent ; quand la vie revient, la mousse gagne, les
## chapeaux se redressent et se colorent, des nénuphars s'ouvrent sur les flaques.
##
## Même contrat que decor_roncier.gd (voir flora.gd › DECOR) : make_tree(p) sans tirage au hasard,
## spawn() avec son propre tirage (graine « seed » de la région).
## Budget de dessin (docs/performances.md) : chaque élément est un DecorTree, dessiné en un appel
## par le lot fidèle et redessiné seulement quand il reverdit. Les flaques, plates, sont posées au
## sol sous les personnages (enfants de flora, pas du calque trié en profondeur).
##
## Charte : le décor reste sourd (Art.c("decor"), proche du sol) pour ne jamais voler la lecture aux
## Flétris ; le violet du poison n'y est qu'une nuance, jamais une lueur.
extends RefCounted

const Regions = preload("res://scripts/regions.gd")
const Flora = preload("res://scripts/flora.gd")

var flora
var region := ""
var cfg: Dictionary = {}


## Les arbres du monde deviennent des touffes de champignons, ou des roseaux (choix fixe selon la
## position : aucun tirage, le reste du monde ne bouge pas).
func make_tree(p: Vector2) -> Node2D:
	if posmod(int(p.x * 0.37 + p.y * 0.61), 3) == 0:
		return DecorReeds.new()
	return DecorMushroom.new()


func spawn() -> void:
	var r := RandomNumberGenerator.new()
	r.seed = int(cfg.get("seed", 21))
	var mid: float = Regions.angle_of(region)
	var half: float = Regions.half_width()
	var h := 2850.0
	var clear_center := float(cfg.get("clear_center", 340.0))
	var clear_seed := float(cfg.get("clear_seed", 560.0))
	var plan := [["mushroom", int(cfg.get("mushrooms", 70))], ["pool", int(cfg.get("pools", 44))],
		["log", int(cfg.get("logs", 26))], ["reeds", int(cfg.get("reeds", 46))]]
	for entry in plan:
		for i in int(entry[1]):
			var kind: String = entry[0]
			var a := mid + r.randf_range(-half, half) * 0.97
			var d := sqrt(r.randf_range(pow(Regions.INNER + 30.0, 2), pow(4000.0, 2)))
			var p := Vector2.from_angle(a) * d
			var sz := r.randf_range(0.8, 1.4)
			var sd := r.randi()
			var rot := r.randf_range(-0.6, 0.6)
			if absf(p.x) > h or absf(p.y) > h or Regions.weight(p, region) < 0.6:
				continue
			if kind == "log" and (Regions.near_heart(region, p, clear_center) or p.length() < clear_seed):
				continue
			var t
			match kind:
				"mushroom":
					t = DecorMushroom.new()
				"pool":
					t = DecorPool.new()
				"log":
					t = DecorLog.new()
					t.angle = rot
					t.radius = 18.0 + 10.0 * (sz - 0.8) / 0.6
				_:
					t = DecorReeds.new()
			_place(t, p, sz, sd, kind == "pool")
			if kind == "log":
				flora.add_obstacle(t)
	# Champignons géants : des repères qu'on reconnaît de loin (ni lueur, ni obstacle).
	for g in cfg.get("giants", []):
		var t := DecorMushroom.new()
		t.giant = true
		_place(t, Regions.place(region, g), float(g.get("size", 1.2)), r.randi(), false)


func _place(t, p: Vector2, sz: float, sd: int, flat: bool) -> void:
	t.position = p
	t.size = sz
	t.tree_seed = sd
	t.alive = flora.ground.life_at(p) > flora.ALIVE
	if flat:
		# Au sol, sous les personnages : une flaque ne passe jamais devant eux.
		flora.add_child(t)
	else:
		flora.trees_parent.add_child(t)
	flora._add_tree(t)


## Couleurs communes du marais : mort (gris violacé) → vivant.
static func dead_tone() -> Color:
	return Art.c("decor").lerp(Art.c("sol_mort"), 0.35).lerp(Art.ec("poison", "sombre"), 0.18)


## Touffe de champignons : deux à quatre pieds, le plus grand au milieu. Morts, ils sont gris et
## leurs chapeaux pendent ; vivants, ils se redressent, se colorent (crème ou brun clair, quelques
## taches) et de la mousse gagne leur pied. Un géant (giant) est un seul grand pied, repère du marais.
class DecorMushroom extends Flora.DecorTree:
	var giant := false

	func _paint() -> void:
		var r := RandomNumberGenerator.new()
		r.seed = tree_seed
		var g := growth()
		var s := size * (2.6 if giant else 1.0)
		var dead: Color = DecorMushroom.dead_tone_of()
		var n := 1 if giant else 2 + r.randi() % 3
		flat_shadow(_b, Vector2(0, 1), (16.0 if n > 1 else 11.0) * s)
		var feet: Array = []
		for i in n:
			var off: float = 0.0 if i == 0 else (-1.0 if i % 2 else 1.0) * r.randf_range(8.0, 15.0) * ceil(i / 2.0)
			var hh := r.randf_range(18.0, 26.0) * (1.0 if i == 0 else r.randf_range(0.55, 0.8))
			var w := r.randf_range(10.0, 14.0) * (1.0 if i == 0 else 0.75)
			feet.append([Vector2(off, r.randf_range(-2.0, 3.0)) * s, hh * s, w * s, r.randf() < 0.5])
		# Du plus loin au plus proche (le plus bas à l'écran devant).
		feet.sort_custom(func(a, b): return a[0].y < b[0].y)
		for i in feet.size():
			var f: Array = feet[i]
			var base: Vector2 = f[0]
			var hh: float = f[1]
			var w: float = f[2]
			# Mort : le pied penche et le chapeau retombe ; vivant : il se redresse.
			var droop := (1.0 - g) * (0.35 if f[3] else -0.35)
			var top := base + Vector2(droop * hh, -hh * (0.82 + 0.18 * g))
			var stem := dead.lightened(0.12).lerp(Art.c("interactif").darkened(0.45), g)
			_b.draw_colored_polygon(limb(base, top, w * 0.22, w * 0.16), stem)
			_b.draw_line(base + Vector2(-w * 0.16, -1.0), top + Vector2(-w * 0.12, 0), stem.lightened(0.12), maxf(1.0, w * 0.06))
			var cap_dead := dead.lerp(Art.ec("poison", "sombre"), 0.3)
			var cap_alive := Art.c("interactif").darkened(0.38) if (i + tree_seed) % 2 == 0 else Art.c("decor_vivant").lerp(Art.ec("vent", "sombre"), 0.25)
			var cap := cap_dead.lerp(cap_alive, g)
			_cap(top, w, droop, cap, g)
		if g <= 0.0:
			return
		# Mousse au pied et petites taches sur les chapeaux, qui éclosent à leur tour.
		var moss := Art.c("decor_vivant")
		for i in 4:
			var k := bud(i, 6)
			if k <= 0.01:
				continue
			var p := Vector2(r.randf_range(-14.0, 14.0), r.randf_range(-1.0, 3.0)) * s
			_b.draw_colored_polygon(Art.ellipse(p, 5.0 * s * k, 2.2 * s * k, 10), moss.darkened(0.1 * (i % 2)))
		if leaf < 1.0:
			drift_leaves(_b, Vector2(0, -20) * s, 12.0 * s, leaf, tree_seed)

	## Chapeau en dôme vu de trois quarts (dessus et lamelles), penché de « droop ».
	func _cap(top: Vector2, w: float, droop: float, col: Color, g: float) -> void:
		var dome := PackedVector2Array()
		var tilt := droop * 0.6
		for j in 11:
			var a := PI + PI * j / 10.0
			var q := Vector2(cos(a) * w, sin(a) * w * 0.72)
			dome.append(top + q.rotated(tilt))
		var rim := PackedVector2Array()
		for j in 11:
			var a := PI * j / 10.0
			rim.append(top + Vector2(cos(a) * w, sin(a) * w * 0.22).rotated(tilt))
		# Lamelles (dessous, plus sombre) puis le dôme en volume.
		var under := PackedVector2Array(rim)
		under.reverse()
		_b.draw_colored_polygon(under + PackedVector2Array([top + Vector2(-w, 0).rotated(tilt)]), col.darkened(0.45))
		_b.draw_colored_polygon(dome, Color(Art.c("contour"), 0.4))
		Art.volume(_b, dome, col, 0.6)
		if g > 0.0:
			for j in 3:
				var k := bud(j + 2, 6)
				if k > 0.01:
					var p := top + Vector2((j - 1) * w * 0.42, -w * (0.3 + 0.12 * (j % 2))).rotated(tilt)
					_b.draw_circle(p, w * 0.1 * k, Color(Art.c("interactif").lightened(0.2), 0.75))

	static func dead_tone_of() -> Color:
		return Art.c("decor").lerp(Art.c("sol_mort"), 0.35).lerp(Art.ec("poison", "sombre"), 0.18)


## Flaque d'eau dormante, au sol : vase huileuse et violacée tant que la terre est morte ; vivante,
## une eau sombre et claire, quelques nénuphars et une fleur. Elle ne fait pas obstacle et ne blesse
## pas (les flaques toxiques du Traîne-vase sont marsh_puddles.gd, bordées de rouge).
class DecorPool extends Flora.DecorTree:
	func _paint() -> void:
		var r := RandomNumberGenerator.new()
		r.seed = tree_seed
		var g := growth()
		var rr := 34.0 * size
		var bank := Art.c("sol_mort").darkened(0.25).lerp(Art.c("sol_vivant").darkened(0.3), g)
		var water := Art.ec("poison", "sombre").lerp(Art.c("decor"), 0.7).lerp(Art.ec("vent", "sombre").darkened(0.2), g)
		var shape := _blob(Vector2.ZERO, rr, tree_seed % 97)
		_b.draw_colored_polygon(_blob(Vector2(0, 2), rr * 1.1, tree_seed % 97), Color(bank, 0.7))
		_b.draw_colored_polygon(shape, water)
		# Reflet du ciel (haut à gauche) : terne et violacé mort, plus net vivant.
		var sheen := Art.ec("poison", "clair").lerp(Art.ec("vent", "clair"), g)
		_b.draw_colored_polygon(Art.ellipse(Vector2(-rr * 0.32, -rr * 0.18), rr * 0.32, rr * 0.07, 12), Color(sheen, 0.12 + 0.1 * g))
		if g <= 0.0:
			# Écume morte : quelques bulles grises immobiles.
			for i in 3:
				var p := Vector2(r.randf_range(-0.5, 0.5) * rr, r.randf_range(-0.2, 0.2) * rr)
				_b.draw_circle(p, 1.6 * size, Color(Art.c("brume"), 0.5))
			return
		var pad := Art.c("decor_vivant")
		var n := 2 + r.randi() % 3
		for i in n:
			var k := bud(i, n + 1)
			if k <= 0.01:
				continue
			var p := Vector2(r.randf_range(-0.55, 0.55) * rr, r.randf_range(-0.22, 0.22) * rr)
			var pr := r.randf_range(5.0, 8.0) * size * k
			var a := r.randf() * TAU
			var pts := PackedVector2Array([p])
			for j in 11:
				var u := a + 0.5 + (TAU - 1.0) * j / 10.0
				pts.append(p + Vector2(cos(u), sin(u) * 0.6) * pr)
			_b.draw_colored_polygon(pts, pad.darkened(0.08 * (i % 2)))
		var kf := bud(n, n + 1)
		if kf > 0.01:
			var p := Vector2(r.randf_range(-0.3, 0.3) * rr, r.randf_range(-0.1, 0.1) * rr)
			for q in 5:
				_b.draw_circle(p + Vector2.from_angle(TAU * q / 5.0) * 2.4 * size * kf, 1.8 * size * kf, Art.c("joueur").lerp(Art.ec("poison", "clair"), 0.4))
			_b.draw_circle(p, 1.2 * size * kf, Art.c("or"))

	static func _blob(pos: Vector2, r: float, sd: int) -> PackedVector2Array:
		var pts := PackedVector2Array()
		for i in 20:
			var a := TAU * i / 20.0
			var w := 1.0 + 0.1 * sin(a * 3.0 + sd) + 0.06 * sin(a * 5.0 + sd * 1.3)
			pts.append(pos + Vector2(cos(a), sin(a) * 0.5) * r * w)
		return pts


## Tronc pourri couché : obstacle (cercle de rayon « radius »). Mort, une écorce grise couverte de
## chapeaux en console violacés ; vivant, la mousse le gagne et les consoles deviennent brunes.
class DecorLog extends Flora.DecorTree:
	var radius := 22.0
	var angle := 0.0

	func _paint() -> void:
		var r := RandomNumberGenerator.new()
		r.seed = tree_seed
		var g := growth()
		var len := radius * 2.3
		var thick := radius * 0.62
		var d := Vector2.from_angle(angle)
		var a := -d * len * 0.5 + Vector2(0, -thick * 0.4)
		var b := d * len * 0.5 + Vector2(0, -thick * 0.4)
		var bark := Art.c("decor").lerp(Art.ec("racine", "sombre"), 0.35).lerp(Art.ec("poison", "sombre"), 0.12 * (1.0 - g))
		bark = bark.lerp(Art.c("decor_vivant").darkened(0.35), g * 0.5)
		flat_shadow(_b, Vector2(0, 1), len * 0.55)
		var body := limb(a, b, thick, thick * 0.85)
		_b.draw_colored_polygon(limb(a, b, thick + 1.5, thick * 0.85 + 1.5), Color(Art.c("contour"), 0.5))
		Art.volume(_b, body, bark, 0.5)
		# Bout scié : les cernes.
		var end_c := b
		_b.draw_colored_polygon(Art.ellipse(end_c, thick * 0.55, thick * 0.85, 14), bark.lightened(0.12))
		_b.draw_arc(end_c, thick * 0.4, 0.0, TAU, 12, bark.darkened(0.2), 1.0)
		# Fentes de pourriture le long du tronc.
		for i in 2:
			var u := 0.3 + 0.35 * i
			var p := a.lerp(b, u)
			_b.draw_line(p + Vector2(0, -thick * 0.2), p + d * len * 0.12 + Vector2(0, -thick * 0.1), bark.darkened(0.4), 1.4)
		# Chapeaux en console sur le dessus.
		var shelf := DecorMushroom.dead_tone_of().lerp(Art.ec("poison", "sombre"), 0.35).lerp(Art.c("interactif").darkened(0.5), g)
		for i in 3:
			var p := a.lerp(b, 0.22 + 0.27 * i) + Vector2(0, -thick * 0.75)
			var w := r.randf_range(5.0, 8.0) * size
			var pts := PackedVector2Array()
			for j in 9:
				var u := PI + PI * j / 8.0
				pts.append(p + Vector2(cos(u) * w, sin(u) * w * 0.55))
			Art.volume(_b, pts, shelf, 0.5)
		if g <= 0.0:
			return
		var moss := Art.c("decor_vivant")
		for i in 4:
			var k := bud(i, 5)
			if k <= 0.01:
				continue
			var p := a.lerp(b, 0.15 + 0.22 * i) + Vector2(0, -thick * r.randf_range(0.2, 0.7))
			_b.draw_colored_polygon(Art.ellipse(p, 7.0 * k * size, 3.5 * k * size, 10), moss.darkened(0.08 * (i % 2)))


## Touffe de roseaux : tiges fines qui partent du pied ; mortes, brunes, cassées et couchées ;
## vivantes, droites et vertes, avec leurs massettes.
class DecorReeds extends Flora.DecorTree:
	func _paint() -> void:
		var r := RandomNumberGenerator.new()
		r.seed = tree_seed
		var g := growth()
		var s := size
		var stem := DecorMushroom.dead_tone_of().lightened(0.08).lerp(Art.c("decor_vivant").lightened(0.05), g)
		flat_shadow(_b, Vector2(0, 1), 9.0 * s)
		var n := 5 + r.randi() % 4
		for i in n:
			var x := (i - (n - 1) / 2.0) * 2.6 * s
			var hh := r.randf_range(22.0, 34.0) * s
			# Mort : la tige se couche et se casse à mi-hauteur.
			var bend := (1.0 - g) * r.randf_range(0.5, 1.1) * (1.0 if i % 2 else -1.0) + r.randf_range(-0.12, 0.12)
			var mid := Vector2(x + bend * hh * 0.15, -hh * 0.55)
			var tip := mid + Vector2.from_angle(-PI / 2.0 + bend * (0.5 + 0.6 * (1.0 - g))) * hh * 0.5
			_b.draw_polyline(PackedVector2Array([Vector2(x, 0), mid, tip]), stem.darkened(0.05 * (i % 3)), maxf(1.0, 1.6 * s))
			if g > 0.0 and i % 2 == 0:
				var k := bud(i / 2, n / 2 + 1)
				if k > 0.01:
					var dir := (tip - mid).normalized()
					_b.draw_colored_polygon(Flora.DecorTree.limb(tip - dir * 9.0 * s * k, tip - dir * 1.5 * s, 2.0 * s * k, 1.6 * s * k), Art.ec("racine", "sombre").lightened(0.1))
		if leaf < 1.0:
			drift_leaves(_b, Vector2(0, -24) * s, 10.0 * s, leaf, tree_seed)
