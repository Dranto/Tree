## Attaque de base du Porte-Graine : rendu et zones au sol (attack.gd, data/attack.json).
##
## Deux nœuds partagent les mêmes listes, comme skill_fx.gd :
## - le nœud du SOL (sous les acteurs) tient les zones laissées par l'attaque, logique comprise :
##   ronces vives piégeuses (« piege ») et touffes d'épines de la traînée (« trainee »). Il les fait
##   blesser à pas fixe (_physics_process) et les dessine en un seul lot de triangles (draw_batch.gd) ;
## - le nœud du DESSUS (au-dessus des projectiles) dessine les signatures brèves : coup de fouet en
##   arc, fourche, ricochet, éclat, attaque renforcée, volée, enracinement.
## Les projectiles eux-mêmes sont dessinés par projectile.gd (draw_shot).
##
## Budget de dessin : rien n'est redessiné quand les deux listes sont vides. Au plus MAX_EFFECTS
## signatures, « trap_max » pièges et « max » touffes de traînée (attack.json) ; le sol passe par un
## seul appel de rendu. Les dessins sont statiques (draw_effect, draw_zone) : la galerie les fige.
class_name AttackFx
extends Node2D

const DrawBatch = preload("res://scripts/draw_batch.gd")

const MAX_EFFECTS := 40
## Durée de chaque signature (secondes).
const DUREE := {
	"fouet": 0.22, "fourche": 0.22, "ricochet": 0.2, "eclat": 0.28, "renforcee": 0.32,
	"volee": 0.36, "enracine": 0.4, "saut": 0.24, "eclosion_spore": 0.34,
}
## Pousse d'une zone à sa naissance, et flétrissement avant sa fin (secondes).
const POUSSE := 0.22
const FANE := 0.4

var main
## Vrai pour le nœud du sol (zones et leur logique), faux pour celui du dessus.
var sol := false
var effects: Array = []
var zones: Array = []
var twin: AttackFx
var _dirty := false
var _batch := DrawBatch.new()


## Crée le nœud du dessus et son jumeau du sol (à ajouter sous les acteurs) ; renvoie [sol, dessus].
static func make_pair(m) -> Array:
	var top := AttackFx.new()
	var low := AttackFx.new()
	low.sol = true
	low.effects = top.effects
	low.zones = top.zones
	top.twin = low
	low.twin = top
	top.main = m
	low.main = m
	return [low, top]


## Ajoute une signature : id parmi DUREE ; d : "pos", "dir", "r", "arc", "follow"…
func play(id: String, d := {}) -> Dictionary:
	var e := d.duplicate()
	e["id"] = id
	e["t"] = 0.0
	if not e.has("dur"):
		e["dur"] = DUREE.get(id, VentFx.DUREE.get(id, AubeFx.DUREE.get(id, 0.3)))
	if Settings.reduce_effects and id in ["fourche", "ricochet", "eclat", "enracine"]:
		return e
	while effects.size() >= MAX_EFFECTS:
		effects.pop_front()
	effects.append(e)
	return e


## Ajoute une zone au sol : "kind" (« piege », « trainee » ou « nuage »), "pos", "r", "dur", "tick",
## "dmg" (dégâts de chaque à-coup), "bleed" (saignement, part des dégâts par seconde), "root"
## (immobilisation à l'entrée, secondes), "poison" (poison posé à chaque à-coup, par seconde),
## "branch" (branche du coup, « ronce » par défaut), "max" (zones du même groupe en même temps ;
## "group", la sorte par défaut).
func add_zone(z: Dictionary) -> void:
	var kind := str(z.get("group", z["kind"]))
	var count := 0
	for o in zones:
		if o.get("group", o["kind"]) == kind:
			count += 1
	var cap := int(z.get("max", 10))
	var i := 0
	while count >= cap and i < zones.size():
		if zones[i].get("group", zones[i]["kind"]) == kind:
			zones.remove_at(i)
			count -= 1
		else:
			i += 1
	z["t"] = 0.0
	z["clock"] = 0.0
	z["seen"] = {}
	z["seed"] = int(absf(z["pos"].x * 7.0 + z["pos"].y * 13.0)) % 997
	zones.append(z)


## Les zones blessent à pas fixe (nœud du sol seulement).
func _physics_process(delta: float) -> void:
	if not sol or zones.is_empty() or main == null:
		return
	var i := 0
	while i < zones.size():
		var z: Dictionary = zones[i]
		z["t"] += delta
		if z["t"] >= z["dur"]:
			zones.remove_at(i)
			continue
		i += 1
		z["clock"] -= delta
		var ticking: bool = z["clock"] <= 0.0
		if ticking:
			z["clock"] += float(z["tick"])
		if not ticking and float(z["root"]) <= 0.0:
			continue
		for e in main.enemies_near(z["pos"], z["r"]):
			if e.dead:
				continue
			var id: int = e.get_instance_id()
			if float(z["root"]) > 0.0 and not z["seen"].has(id):
				z["seen"][id] = true
				e.apply_status("enracine", 1.0, float(z["root"]))
			if ticking:
				var dmg: float = float(z["dmg"]) * main.branch_factor(e, str(z.get("branch", "ronce")))
				e.take_damage(dmg, false, true)
				if float(z.get("poison", 0.0)) > 0.0 and not e.dead:
					e.apply_poison(float(z["poison"]), 1.0)
				if float(z["bleed"]) > 0.0 and not e.dead:
					e.apply_status("saignement", dmg / maxf(float(z["tick"]), 0.05) * float(z["bleed"]), 2.0 * float(Game.stats.get("bleed_duration", 1.0)))


func _process(delta: float) -> void:
	if not sol:
		var i := 0
		while i < effects.size():
			var e: Dictionary = effects[i]
			e["t"] += delta
			var f = e.get("follow")
			if f != null:
				if is_instance_valid(f):
					e["pos"] = f.position
				else:
					e.erase("follow")
			if e["t"] >= e["dur"]:
				effects.remove_at(i)
			else:
				i += 1
		if not effects.is_empty() or _dirty:
			queue_redraw()
		_dirty = not effects.is_empty()
		return
	if not zones.is_empty() or _dirty:
		queue_redraw()
	_dirty = not zones.is_empty()


func _draw() -> void:
	if sol:
		for z in zones:
			draw_zone(_batch, z)
		_batch.flush(self)
		return
	for e in effects:
		draw_effect(self, e)


# --- Zones au sol ---

## Dessine une zone à son instant z["t"] (ci : un CanvasItem ou un lot draw_batch.gd).
static func draw_zone(ci, z: Dictionary) -> void:
	var t: float = z["t"]
	var dur: float = z["dur"]
	var grow := Anim.ease_out(clampf(t / POUSSE, 0.0, 1.0))
	var fade := clampf((dur - t) / FANE, 0.0, 1.0)
	if z["kind"] == "piege":
		_piege(ci, z["pos"], z["r"], grow, fade, int(z["seed"]), float(z.get("bleed", 0.0)) > 0.0)
	elif z["kind"] == "nuage":
		_nuage(ci, z["pos"], z["r"], grow, fade, int(z["seed"]), t)
	else:
		_touffe(ci, z["pos"], z["r"], grow, fade, int(z["seed"]))


## Ronce vive : une tache de terre rougie, un cercle de tiges épineuses recourbées vers le centre,
## et des boutons de sang. Pousse en éclosant, se fane en s'affaissant.
static func _piege(ci, p: Vector2, r: float, grow: float, fade: float, seed: int, bleeding: bool) -> void:
	var sang := Art.ec("saignement")
	var clair := Art.ec("saignement", "clair")
	var tige := Art.ec("epine", "sombre")
	var epine := Art.ec("epine")
	ci.draw_circle(p, r * (0.6 + 0.4 * grow), Color(sang.darkened(0.4), 0.28 * fade))
	ci.draw_arc(p, r * grow, 0.0, TAU, 28, Color(sang, 0.55 * fade), 2.0)
	var n := 7
	for i in n:
		var a := (seed % 100) * 0.0628 + i * TAU / n
		var base := p + Vector2.from_angle(a) * r * 0.95
		var pts := PackedVector2Array()
		for j in 5:
			var k := j / 4.0 * grow
			# La tige part du bord et se recourbe vers le centre, comme une griffe.
			pts.append(base + Vector2.from_angle(a + PI + 0.9 * k) * r * 0.75 * k)
		ci.draw_polyline(pts, Color(tige.lightened(0.15), fade), 3.0 * fade + 1.0)
		if grow > 0.5:
			for j in [1, 3]:
				var q: Vector2 = pts[j]
				var d := Vector2.from_angle(a + PI * 0.5 + 0.9 * j / 4.0)
				_spike(ci, q, d, 6.0 * grow, Color(epine, fade))
		ci.draw_circle(pts[pts.size() - 1], 2.6 * grow, Color(clair if bleeding else epine.lightened(0.3), fade))
	ci.draw_circle(p, r * 0.16 * grow, Color(clair, 0.55 * fade))


## Petit nuage de spores (spores lobées, bouffée) : une tache de sol rongé, cinq volutes qui
## respirent et deux bulles qui montent. Plus discret que le Nuage de spores (compétence).
static func _nuage(ci, p: Vector2, r: float, grow: float, fade: float, seed: int, t: float) -> void:
	var col := Art.ec("poison")
	var clair := Art.ec("poison", "clair")
	var sombre := Art.ec("poison", "sombre")
	var g := 0.55 + 0.45 * grow
	ci.draw_circle(p, r * g, Color(sombre, 0.22 * fade))
	for i in 5:
		var a := (seed % 100) * 0.0628 + i * TAU / 5.0 + t * 0.4
		var q := p + Vector2.from_angle(a) * r * 0.45 * g
		ci.draw_circle(q, r * (0.36 + 0.05 * sin(t * 2.2 + i)) * g, Color(col, 0.16 * fade))
	ci.draw_circle(p + Vector2(-r * 0.12, -r * 0.15), r * 0.3 * g, Color(clair, 0.1 * fade))
	for i in 2:
		var bk := fposmod(t * 0.7 + i * 0.5 + seed * 0.01, 1.0)
		var q := p + Vector2((i * 2 - 1) * r * 0.3, r * 0.1 - bk * r * 0.6)
		ci.draw_circle(q, (1.5 + 2.5 * bk) * g, Color(clair, 0.6 * fade * (1.0 - bk)))


## Touffe d'épines de la traînée : trois pointes d'os plantées dans le sol, et leur ombre.
static func _touffe(ci, p: Vector2, r: float, grow: float, fade: float, seed: int) -> void:
	var col := Art.ec("epine")
	ci.draw_circle(p + Vector2(0, r * 0.25), r * 0.7, Color(Art.c("ombre"), 0.5 * fade))
	for i in 3:
		var a := -PI / 2.0 + (i - 1) * 0.55 + (seed % 7 - 3) * 0.05
		var base := p + Vector2((i - 1) * r * 0.45, r * 0.2)
		_spike(ci, base, Vector2.from_angle(a), r * (0.9 + 0.3 * float(i == 1)) * grow, Color(col if i != 1 else Art.ec("epine", "clair"), fade))


## Pointe triangulaire (compatible avec draw_batch.gd).
static func _spike(ci, base: Vector2, d: Vector2, length: float, col: Color) -> void:
	if length <= 0.5:
		return
	var n := Vector2(-d.y, d.x)
	ci.draw_colored_polygon(PackedVector2Array([base + n * length * 0.28, base + d * length, base - n * length * 0.28]), col)


# --- Signatures ---

## Dessine une signature à son instant e["t"].
static func draw_effect(ci: CanvasItem, e: Dictionary) -> void:
	var k: float = clampf(e["t"] / maxf(e["dur"], 0.001), 0.0, 1.0)
	if VentFx.draws(e["id"]):
		VentFx.draw(ci, e, false)
		return
	if AubeFx.draws(e["id"]):
		AubeFx.draw(ci, e, false)
		return
	match e["id"]:
		"fouet":
			_fouet(ci, e, k)
		"fourche":
			_fourche(ci, e, k)
		"ricochet":
			_ricochet(ci, e, k)
		"eclat":
			_eclat(ci, e, k)
		"renforcee":
			_renforcee(ci, e, k)
		"volee":
			_volee(ci, e, k)
		"enracine":
			_enracine(ci, e, k)
		"saut":
			_saut(ci, e, k)
		"eclosion_spore":
			_eclosion_spore(ci, e, k)


## Coup de fouet : la lanière balaie l'arc d'un bord à l'autre, hérissée d'épines ; derrière elle,
## le secteur balayé luit puis s'efface. Renforcé : liseré doré.
static func _fouet(ci: CanvasItem, e: Dictionary, k: float) -> void:
	var p: Vector2 = e["pos"]
	var dir: Vector2 = e.get("dir", Vector2.RIGHT)
	var r: float = e.get("r", 130.0)
	var arc: float = e.get("arc", 1.9)
	var flip := -1.0 if e.get("flip", false) else 1.0
	var sweep := Anim.ease_out(clampf(k / 0.7, 0.0, 1.0))
	var a0 := dir.angle() - flip * arc / 2.0
	var head := a0 + flip * arc * sweep
	var fade := 1.0 - clampf((k - 0.6) / 0.4, 0.0, 1.0)
	var clair := Art.ec("epine", "clair")
	var col := Art.ec("epine")
	# Secteur balayé.
	var wedge := PackedVector2Array([p])
	var steps := maxi(4, int(arc * 8.0))
	for i in steps + 1:
		wedge.append(p + Vector2.from_angle(lerpf(a0, head, float(i) / steps)) * r)
	if absf(head - a0) > 0.02:
		ci.draw_colored_polygon(wedge, Color(col, 0.16 * fade))
	# Lanière : de la main jusqu'à la pointe, qui suit le bord de l'arc.
	var pts := PackedVector2Array()
	var tail := maxf(a0, head - 1.1) if flip > 0.0 else minf(a0, head + 1.1)
	for i in 9:
		var a := lerpf(tail, head, i / 8.0)
		pts.append(p + Vector2.from_angle(a) * r * (0.55 + 0.45 * i / 8.0))
	if e.get("empowered", false):
		ci.draw_polyline(pts, Color(Art.c("or"), 0.8 * fade), 9.0, true)
	ci.draw_polyline(pts, Color(Art.c("contour"), 0.85 * fade), 6.5, true)
	ci.draw_polyline(pts, Color(col, fade), 4.0, true)
	for i in range(2, 9, 2):
		var a := lerpf(tail, head, i / 8.0)
		var q: Vector2 = pts[i]
		_spike(ci, q, Vector2.from_angle(a + flip * PI / 2.0 * -1.0), 7.0, Color(clair, fade))
	ci.draw_arc(p, r, head - flip * 0.25, head, 6, Color(clair, 0.9 * fade), 3.0, true)
	ci.draw_circle(pts[8], 4.0 * fade + 1.0, Color(clair, fade))


## Fourche : le projectile se divise ; un éclat en Y s'ouvre au point d'impact.
static func _fourche(ci: CanvasItem, e: Dictionary, k: float) -> void:
	var p: Vector2 = e["pos"]
	var dir: Vector2 = e.get("dir", Vector2.RIGHT)
	var col := Art.ec(str(e.get("element", "seve")), "clair")
	var g := Anim.ease_out(k)
	var a := 1.0 - k
	var n: int = int(e.get("n", 1))
	ci.draw_circle(p, 5.0 + 6.0 * g, Color(col, 0.45 * a))
	for i in n + 1:
		var side := 0.0 if i == 0 else (-1.0 if i % 2 == 1 else 1.0) * float((i + 1) / 2)
		var d := dir.rotated(side * float(e.get("a", 0.42)))
		ci.draw_line(p, p + d * (10.0 + 26.0 * g), Color(col, a), 2.5 * a + 0.5, true)


## Ricochet : un trait clair relie les deux ennemis, et une étincelle au point de rebond.
static func _ricochet(ci: CanvasItem, e: Dictionary, k: float) -> void:
	var p: Vector2 = e["pos"]
	var to: Vector2 = e.get("to", p)
	var col := Art.ec(str(e.get("element", "seve")), "clair")
	var a := 1.0 - k
	var mid := p.lerp(to, minf(1.0, k * 2.5))
	ci.draw_line(p, mid, Color(col, 0.55 * a), 2.0, true)
	for i in 4:
		var d := Vector2.from_angle(i * TAU / 4.0 + 0.6)
		ci.draw_line(p + d * 3.0, p + d * (5.0 + 10.0 * Anim.ease_out(k)), Color(col, a), 2.0, true)


## Éclat : l'ennemi tué éclate ; un anneau d'os et des pointes partent en étoile.
static func _eclat(ci: CanvasItem, e: Dictionary, k: float) -> void:
	var p: Vector2 = e["pos"]
	var g := Anim.ease_out(k)
	var a := 1.0 - k
	var col := Art.ec("epine", "clair")
	ci.draw_circle(p, 8.0 + 10.0 * g, Color(Art.ec("saignement", "clair"), 0.3 * a))
	ci.draw_arc(p, 6.0 + 26.0 * g, 0.0, TAU, 20, Color(col, 0.8 * a), 2.5 * a + 0.5, true)
	for i in 8:
		var d := Vector2.from_angle(i * TAU / 8.0 + 0.2)
		_spike(ci, p + d * (6.0 + 20.0 * g), d, 8.0 * a, Color(col, a))


## Attaque renforcée : un anneau doré se resserre sur le héros puis éclate.
static func _renforcee(ci: CanvasItem, e: Dictionary, k: float) -> void:
	var p: Vector2 = e["pos"]
	var col := Art.c("or")
	var el := Art.ec(str(e.get("element", "seve")), "clair")
	var a := 1.0 - k
	if k < 0.4:
		var q := k / 0.4
		ci.draw_arc(p, 46.0 - 24.0 * Anim.ease_in(q), 0.0, TAU, 28, Color(col, 0.85), 3.0, true)
	else:
		var q := (k - 0.4) / 0.6
		ci.draw_circle(p, 20.0 + 14.0 * q, Color(el, 0.3 * (1.0 - q)))
		ci.draw_arc(p, 22.0 + 30.0 * Anim.ease_out(q), 0.0, TAU, 28, Color(col, a), 3.0 * a + 0.5, true)
		for i in 6:
			var d := Vector2.from_angle(i * TAU / 6.0)
			ci.draw_line(p + d * (24.0 + 20.0 * q), p + d * (32.0 + 28.0 * q), Color(col, a), 2.0, true)


## Volée : une onde part du héros, tout autour, à la couleur de la forme.
static func _volee(ci: CanvasItem, e: Dictionary, k: float) -> void:
	var p: Vector2 = e["pos"]
	var r: float = e.get("r", 60.0)
	var col := Art.ec(str(e.get("element", "seve")))
	var clair := Art.ec(str(e.get("element", "seve")), "clair")
	var g := Anim.ease_out(k)
	var a := 1.0 - k
	ci.draw_circle(p, r * (0.3 + 1.2 * g), Color(col, 0.14 * a))
	ci.draw_arc(p, r * (0.3 + 1.6 * g), 0.0, TAU, 36, Color(clair, 0.8 * a), 3.0 * a + 0.5, true)
	ci.draw_arc(p, r * (0.2 + 1.1 * g), 0.0, TAU, 36, Color(col, 0.6 * a), 1.5, true)


## Enracinement : trois racines jaillissent du sol et se referment sur l'ennemi.
static func _enracine(ci: CanvasItem, e: Dictionary, k: float) -> void:
	var p: Vector2 = e["pos"]
	var r: float = e.get("r", 12.0)
	var col := Art.ec("racine", "clair")
	var g := Anim.ease_out(clampf(k / 0.5, 0.0, 1.0))
	var a := 1.0 - clampf((k - 0.6) / 0.4, 0.0, 1.0)
	for i in 3:
		var base := p + Vector2.from_angle(PI * 0.15 + i * PI * 0.35) * r * 1.5 + Vector2(0, r * 0.4)
		var tip := p + Vector2.from_angle(-PI / 2.0 + (i - 1) * 0.6) * r * 0.6
		var mid := base.lerp(tip, 0.5) + Vector2((i - 1) * r * 0.5, -r * 0.3)
		var pts := PackedVector2Array([base, base.lerp(mid, g), mid.lerp(tip, g)])
		ci.draw_polyline(pts, Color(Art.ec("racine"), a), 3.5, true)
		ci.draw_circle(pts[2], 2.0, Color(col, a))


## Saut : un filament de mycélium relie l'ennemi touché au suivant, empoisonné, et une spore
## claire file le long du fil.
static func _saut(ci: CanvasItem, e: Dictionary, k: float) -> void:
	var p: Vector2 = e["pos"]
	var to: Vector2 = e.get("to", p)
	var col := Art.ec("poison")
	var clair := Art.ec("poison", "clair")
	var a := 1.0 - k
	var d := to - p
	var n := d.orthogonal().normalized() * minf(14.0, d.length() * 0.12)
	var pts := PackedVector2Array()
	for i in 7:
		var u := i / 6.0
		pts.append(p + d * u + n * sin(u * PI) * (1.0 if i % 2 == 0 else 0.6))
	ci.draw_polyline(pts, Color(col, 0.7 * a), 2.0, true)
	ci.draw_circle(p.lerp(to, minf(1.0, k * 1.6)) + n * sin(minf(1.0, k * 1.6) * PI), 3.5, Color(clair, a))
	ci.draw_circle(p, 3.0 + 6.0 * Anim.ease_out(k), Color(clair, 0.4 * a))


## Spore lobée qui éclate au sol : une collerette de poussière s'ouvre, six spores partent en étoile.
static func _eclosion_spore(ci: CanvasItem, e: Dictionary, k: float) -> void:
	var p: Vector2 = e["pos"]
	var r: float = e.get("r", 56.0)
	var col := Art.ec("poison")
	var clair := Art.ec("poison", "clair")
	var g := Anim.ease_out(k)
	var a := 1.0 - k
	ci.draw_circle(p, r * (0.3 + 0.7 * g), Color(col, 0.22 * a))
	ci.draw_arc(p, r * (0.3 + 0.7 * g), 0.0, TAU, 28, Color(clair, 0.85 * a), 2.5 * a + 0.5, true)
	for i in 6:
		var d := Vector2.from_angle(i * TAU / 6.0 + 0.3)
		ci.draw_circle(p + d * r * (0.2 + 0.75 * g), 3.0 * a + 1.0, Color(clair, a))
