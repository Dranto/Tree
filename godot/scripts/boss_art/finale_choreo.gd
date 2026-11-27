## Chorégraphie des attaques de la Flétrissure (dessin seul : aucune collision, aucun chiffre de jeu).
##
## Chaque attaque se joue en trois temps, comme un geste : l'élan (pendant l'annonce, le bras se
## ramène et se charge), la frappe (un coup sec, avec dépassement, au moment où le coup part) et le
## retour (un ressort amorti vers le repos). Le corps suit le geste le plus lourd : il se cabre et se
## grandit pendant l'élan, se jette vers le héros à la frappe, puis retombe.
##
## Un bras est articulé en deux (épaule, coude) : sa pose est un Vector3 (rotation de l'épaule,
## pli du coude, allongement), plus la taille du motif au bout (m). Les rotations sont en « vers le
## haut » (rad) : FinaleArt.arm_xf les tourne selon le côté du bras. « aim » vise la direction du héros
## (repère local, retournement compris), en part de l'écart entre le bras au repos et cette direction.
##
## Un bras qui bouge est décrit par un enregistrement {kind, k, s, e[, from]} : kind = l'attaque, k = la part
## de l'annonce écoulée (0 → 1), s = secondes depuis la frappe (< 0 : pas encore), e = secondes depuis
## la fin de l'attaque (< 0 : pas encore), from = la pose d'où part l'élan (repris en plein retour).
## BossFinale tient ces enregistrements (et la planche de
## direction les joue sur une frise).
extends RefCounted

## Durée du coup sec (s), du retour au repos (s).
const SNAP := 0.1
const RECOVER := 0.7

## Poses clés par attaque : wind (fin de l'annonce) et hit (la frappe). aim : part de l'écart vers le
## héros ; up : rotation vers le haut en plus ; el : pli du coude (+ : replié vers le haut) ; st :
## allongement ; m : taille du motif ; dip : le motif pique vers le sol (racines, siphon).
const KEYS := {
	# Ronce : le bras se rejette en arrière, coude replié, la couronne d'épines se hérisse ; puis il
	# fouette vers le héros, tendu, et chaque salve le fait claquer.
	"epines": {"wind": {"aim": -0.3, "up": 0.55, "el": 0.95, "st": 0.92, "m": 1.3},
		"hit": {"aim": 0.75, "up": 0.0, "el": -0.25, "st": 1.2, "m": 1.0}, "flick": 0.16},
	# Spore : le bras se dresse, les chapeaux gonflent ; puis il se courbe vers le héros et les
	# chapeaux se vident d'un coup (bouffée de spores).
	"spores": {"wind": {"aim": 0.0, "up": 0.7, "el": 0.5, "st": 1.05, "m": 1.45},
		"hit": {"aim": 0.5, "up": 0.15, "el": -0.45, "st": 1.12, "m": 0.8}},
	# Sève : le bras se lève, puis le bulbe plonge dans le sol à ses pieds et boit (il bat pendant
	# tout le siphon), puis s'arrache.
	"siphon": {"wind": {"aim": 0.0, "up": 0.6, "el": 0.6, "st": 1.0, "m": 1.2},
		"hit": {"aim": 0.0, "up": -1.05, "el": -0.7, "st": 1.18, "m": 1.0, "dip": 1.0}, "pump": 0.12},
	# Vent : le bras balaie en arrière, plumes ouvertes ; puis il fauche à travers vers le héros et
	# continue sa course (le souffle part de là).
	"rafale": {"wind": {"aim": -0.55, "up": 0.5, "el": 0.7, "st": 0.95, "m": 1.3},
		"hit": {"aim": 1.15, "up": -0.1, "el": -0.35, "st": 1.22, "m": 1.1}},
	# Aube : le bras se dresse droit vers le ciel, les cristaux s'allument ; à l'éclair, il s'abat
	# vers le héros comme une lame.
	"lumiere": {"wind": {"aim": 0.0, "up": 0.95, "el": -0.2, "st": 1.25, "m": 1.35},
		"hit": {"aim": 0.45, "up": 0.25, "el": -0.15, "st": 1.15, "m": 1.15}},
	# Racine : la griffe monte haut, coude plié ; puis elle s'abat dans le sol vers le héros (les
	# racines en jaillissent) et y reste plantée tant qu'elles sortent.
	"racines": {"wind": {"aim": 0.0, "up": 1.0, "el": 1.0, "st": 1.0, "m": 1.25},
		"hit": {"aim": 0.55, "up": -0.75, "el": -0.4, "st": 1.25, "m": 1.0, "dip": 1.0}},
	# Rejetons : la griffe racle le sol, à l'opposé du héros (les Flétris sortent derrière elle).
	"rejetons": {"wind": {"aim": -0.4, "up": 0.35, "el": 0.7, "st": 1.0, "m": 1.1},
		"hit": {"aim": -0.9, "up": -0.7, "el": -0.3, "st": 1.15, "m": 1.0, "dip": 1.0}},
}
## Les attaques combinées : chacun des deux bras joue son propre geste.
const COMBO := {"tempete": ["rafale", "epines"], "floraison": ["spores", "siphon"], "aurore": ["lumiere", "racines"]}
const REST := {"aim": 0.0, "up": 0.0, "el": 0.0, "st": 1.0, "m": 1.0, "dip": 0.0}
## Le corps : se cabre (rear, rotation vers l'arrière) pendant l'élan, se jette (lunge) à la frappe.
const BODY := {"rear": 0.07, "grow": 0.06, "lunge": 0.09, "squash": 0.07}


## Le geste d'un bras pour l'attaque « kind » (la clé dans KEYS ; une attaque combinée donne celle
## du bras).
static func keys_for(kind: String, arm_trait: String) -> Dictionary:
	if COMBO.has(kind):
		var pair: Array = COMBO[kind]
		return KEYS.get(arm_trait if arm_trait in pair else pair[0], {})
	return KEYS.get(kind, {})


## Pose d'un bras (dictionnaire comme REST) d'après son enregistrement ; t : horloge (frémissements).
static func arm_pose(rec: Dictionary, arm_trait: String, t: float) -> Dictionary:
	if rec.is_empty():
		return REST
	var keys := keys_for(str(rec.get("kind", "")), arm_trait)
	if keys.is_empty():
		return REST
	var s: float = rec.get("s", -1.0)
	var e: float = rec.get("e", -1.0)
	var wind: Dictionary = keys["wind"]
	var hit: Dictionary = keys["hit"]
	if s < 0.0:
		# L'élan : lent au début, il se tend, puis tremble à la fin (l'énergie retenue).
		var k: float = clampf(rec.get("k", 0.0), 0.0, 1.0)
		var u := ease_in_out(k)
		var p := mix(rec.get("from", REST), wind, u)
		var shake := smooth(0.6, 1.0, k) * 0.035
		p["up"] += shake * sin(t * 47.0)
		p["el"] += shake * 0.7 * sin(t * 39.0 + 1.0)
		return p
	var held := _hit_at(keys, wind, hit, s if e < 0.0 else s - e, t)
	if e < 0.0:
		return held
	if e >= RECOVER:
		return REST
	return mix(held, REST, spring(e / RECOVER))


## Pendant la frappe : coup sec de l'élan vers la pose de frappe (dépassement), puis tenue (claquement
## à chaque salve pour les épines, battement pour le siphon).
static func _hit_at(keys: Dictionary, wind: Dictionary, hit: Dictionary, s: float, t: float) -> Dictionary:
	var u := clampf(s / SNAP, 0.0, 1.0)
	var p := mix(wind, hit, back_out(u))
	if s > SNAP:
		if keys.has("flick"):
			# Un claquement par salve (~ un temps à 180 BPM).
			var f := fposmod(s - SNAP, 0.333) / 0.333
			var w: float = keys["flick"] * exp(-f * 6.0) * sin(f * 18.0)
			p["el"] -= w
			p["up"] += w * 0.5
		if keys.has("pump"):
			var w: float = keys["pump"] * (0.5 + 0.5 * sin(t * 9.0))
			p["st"] += w * 0.5
			p["m"] += w * 1.5
	return p


## Pose du corps : {lean (rad, + vers le héros), grow (étirement vertical), squash}. recs : les
## enregistrements des bras qui bougent ; le corps suit le plus avancé dans son geste.
static func body_pose(recs: Array) -> Dictionary:
	var lean := 0.0
	var grow := 0.0
	for rec: Dictionary in recs:
		if rec.is_empty():
			continue
		var s: float = rec.get("s", -1.0)
		var e: float = rec.get("e", -1.0)
		var l := 0.0
		var g := 0.0
		if s < 0.0:
			var u := ease_in_out(clampf(rec.get("k", 0.0), 0.0, 1.0))
			l = -BODY["rear"] * u
			g = BODY["grow"] * u
		else:
			var hs := s if e < 0.0 else s - e
			var u := back_out(clampf(hs / (SNAP * 1.6), 0.0, 1.0))
			var hold := 1.0 - 0.5 * smooth(0.2, 0.8, hs)
			l = lerpf(-BODY["rear"], BODY["lunge"], u) * (hold if u >= 1.0 else 1.0)
			g = lerpf(BODY["grow"], -BODY["squash"], u) * (hold if u >= 1.0 else 1.0)
			if e >= 0.0:
				var r := 1.0 - spring(clampf(e / RECOVER, 0.0, 1.0))
				l *= r
				g *= r
		if absf(l) > absf(lean):
			lean = l
			grow = g
	return {"lean": lean, "grow": grow}


## Les effets d'un geste (FinaleArt._gesture_fx) : wind (l'élan qui se charge, 0 → 1), hit (l'éclat
## de la frappe, 1 → 0 en HIT_FX s), hold (la frappe tenue : 1, puis s'éteint au retour).
const HIT_FX := 0.45


static func arm_fx(rec: Dictionary) -> Dictionary:
	if rec.is_empty():
		return {}
	var s: float = rec.get("s", -1.0)
	var e: float = rec.get("e", -1.0)
	if s < 0.0:
		return {"wind": smooth(0.1, 0.9, float(rec.get("k", 0.0))), "kind": rec.get("kind", "")}
	var hold := 1.0 if e < 0.0 else maxf(0.0, 1.0 - e / 0.3)
	return {"hit": maxf(0.0, 1.0 - s / HIT_FX), "hold": hold, "kind": rec.get("kind", "")}


## Tout le geste pour FinaleArt.compose (anim) : recs[i] = l'enregistrement du bras i ({} : au repos),
## arms = BossFinale.ARMS, aim = direction du héros (écran).
static func build(recs: Array, arms: Array, aim: Vector2, t: float) -> Dictionary:
	var poses: Array = []
	var fxs: Array = []
	for i in arms.size():
		var rec: Dictionary = recs[i] if i < recs.size() else {}
		poses.append(arm_pose(rec, str(arms[i]["trait"]), t))
		fxs.append(arm_fx(rec))
	return {"arms": poses, "fx": fxs, "body": body_pose(recs), "aim": aim}


## Un enregistrement est fini (le bras est revenu au repos).
static func done(rec: Dictionary) -> bool:
	return rec.is_empty() or float(rec.get("e", -1.0)) >= RECOVER


static func mix(a: Dictionary, b: Dictionary, u: float) -> Dictionary:
	var out := {}
	for key in REST:
		out[key] = lerpf(float(a.get(key, REST[key])), float(b.get(key, REST[key])), u)
	return out


## Ressort amorti 0 → 1 (dépasse un peu, puis se pose).
static func spring(u: float) -> float:
	if u >= 1.0:
		return 1.0
	return 1.0 - exp(-5.5 * u) * cos(8.5 * u) * (1.0 - u * u * u)


static func back_out(u: float) -> float:
	var c := 2.2
	var v := u - 1.0
	return 1.0 + (c + 1.0) * v * v * v + c * v * v


static func ease_in_out(u: float) -> float:
	return u * u * (3.0 - 2.0 * u)


static func smooth(a: float, b: float, x: float) -> float:
	return ease_in_out(clampf((x - a) / (b - a), 0.0, 1.0))
