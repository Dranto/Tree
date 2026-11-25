## Les sortes de Flétris et leurs dessins « Bestiaire d'herbier » (scripts/creature_art/<région>/<id>.gd), vus
## par le banc de lisibilité : planche du scénario visuel « bestiaire », tests/bestiaire_test.gd et
## tools/bestiaire.sh. Aucun état ; rien ici ne touche au jeu.
##
## Une sorte a un script de créature quand le fichier existe (même chemin que le moteur) ; les autres sont
## listées « sans script » : ce n'est pas un échec, c'est le travail qui reste.
extends RefCounted

const Ink = preload("res://scripts/creature_art/ink.gd")

## Échelle du jeu en 1080p (projet en 1600×900, étiré).
const S1080 := 1080.0 / 900.0

## Dossiers de scripts, dans l'ordre des planches : « commun » (sortes sans région) puis les régions.
const REGIONS := ["commun", "ronce", "spore", "vent", "seve", "aube", "racine"]

## Hauteur minimale du dessin à l'écran en 1080p, par rôle (direction V3 : « essaim 28, tireur/chargeur 44,
## soutien 56, lourd 72 »). Ce sont des planchers : un dessin peut être plus grand.
const MIN_PX := {"essaim": 28.0, "tireur": 44.0, "chargeur": 44.0, "soutien": 56.0, "lourd": 72.0}

## Rôle selon le `behavior` de enemies.json. « chase » est ambigu (essaim ou colosse) : voir role_of().
const ROLE_DE_COMPORTEMENT := {
	"flutter": "essaim",
	"shooter": "tireur", "kite": "tireur", "blower": "tireur", "glider": "tireur", "dazzler": "tireur",
	"beamer": "tireur", "puddler": "tireur",
	"charger": "chargeur", "diver": "chargeur", "leech": "chargeur", "hopper": "chargeur",
	"burrower": "chargeur", "bomber": "chargeur", "splitter": "chargeur",
	"nest": "soutien", "healer": "soutien", "guard": "soutien",
	"slam": "lourd", "shatter": "lourd", "lichen": "lourd",
}
## « chase » : à partir de ce rayon de collision (px du jeu), la sorte est un lourd (menhir 24, colosse 25) ;
## en dessous, un essaim (fletri 14, cendreux 10, rejeton 8…).
const RAYON_LOURD := 20.0

## Pose de repos des mesures : regard vers la droite, un peu levé.
const REPOS := {"t": 0.4, "look": 0.25}


## Toutes les sortes de enemies.json, dans l'ordre des planches (commun d'abord, puis chaque région) :
## { id, nom, behavior, region ("commun" sans région), r, role, min_px, path, script (ou null) }.
static func kinds() -> Array:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/enemies.json"))
	var out := []
	for k in data["kinds"]:
		var region: String = k.get("region", "commun")
		var e := {
			"id": k["id"], "nom": k["name"], "behavior": k["behavior"], "region": region, "r": float(k["radius"]),
			"path": "res://scripts/creature_art/%s/%s.gd" % [region, k["id"]],
		}
		e["role"] = role_of(k)
		e["min_px"] = MIN_PX[e["role"]]
		e["script"] = load(e["path"]) if ResourceLoader.exists(e["path"]) else null
		out.append(e)
	var sorted := []
	for reg in REGIONS:
		for e in out:
			if e["region"] == reg:
				sorted.append(e)
	return sorted


static func role_of(kind: Dictionary) -> String:
	var b: String = kind["behavior"]
	if b == "chase":
		return "lourd" if float(kind["radius"]) >= RAYON_LOURD else "essaim"
	return ROLE_DE_COMPORTEMENT.get(b, "chargeur")


## Sol d'une région pour les fonds : une sorte commune se montre sur le sol de Ronce.
static func ground_region(region: String) -> String:
	return "ronce" if region == "commun" else region


## Pose d'une phase : « repos », « marche », « annonce », « frappe », « coup » ; u : avancement 0 → 1 ;
## time : horloge du dessin (s). Même vocabulaire que le contrat de dessin.
static func pose(phase: String, u: float, time := 0.4, look := 0.25) -> Dictionary:
	var o := {"t": time, "look": look}
	match phase:
		"marche":
			o["walk"] = u * TAU * 2.0
			o["moving"] = 1.0
		"annonce":
			o["k"] = u
			o["state"] = "windup"
		"frappe":
			o["strike"] = u
			o["state"] = "charge"
		"coup":
			o["hit"] = 1.0 - u
	return o


## Dessin d'une sorte sur un CanvasItem : pieds en feet, échelle s, pose o. La silhouette noire passe par
## Ink.mono (comme le moteur) et l'éclair par Ink.flash : toujours remis à zéro après.
static func paint(ci: CanvasItem, script, feet: Vector2, s: float, o := {}, mono := false) -> void:
	Ink.mono = mono
	script.draw(ci, feet, script.HEIGHT * s, o)
	Ink.mono = false
	Ink.flash = 0.0


## Silhouette noire d'une image : tout pixel assez opaque devient noir (ombres et halos disparaissent).
static func silhouette(img: Image, threshold := 0.55) -> Image:
	var out := Image.create(img.get_width(), img.get_height(), false, Image.FORMAT_RGBA8)
	for yy in img.get_height():
		for xx in img.get_width():
			if img.get_pixel(xx, yy).a > threshold:
				out.set_pixel(xx, yy, Color(0.05, 0.04, 0.04, 1.0))
	return out


static func gray(img: Image) -> Image:
	var out := img.duplicate()
	for yy in img.get_height():
		for xx in img.get_width():
			var c := img.get_pixel(xx, yy)
			var l := c.get_luminance()
			out.set_pixel(xx, yy, Color(l, l, l, c.a))
	return out


## Masque d'une image : un octet par pixel (1 : opaque), dans le rectangle du dessin.
static func mask(img: Image, threshold := 0.5) -> PackedByteArray:
	var w := img.get_width()
	var m := PackedByteArray()
	m.resize(w * img.get_height())
	for yy in img.get_height():
		for xx in w:
			m[yy * w + xx] = 1 if img.get_pixel(xx, yy).a > threshold else 0
	return m


## Boîte du masque : Rect2i (position, taille), vide si rien n'est dessiné.
static func bbox(img: Image, threshold := 0.5) -> Rect2i:
	var x0 := img.get_width()
	var y0 := img.get_height()
	var x1 := -1
	var y1 := -1
	for yy in img.get_height():
		for xx in img.get_width():
			if img.get_pixel(xx, yy).a > threshold:
				x0 = mini(x0, xx)
				x1 = maxi(x1, xx)
				y0 = mini(y0, yy)
				y1 = maxi(y1, yy)
	if x1 < 0:
		return Rect2i()
	return Rect2i(x0, y0, x1 - x0 + 1, y1 - y0 + 1)


## Recouvrement de deux silhouettes (intersection sur union, 0 → 1), pieds alignés sur le même point : la
## taille compte, comme à l'écran. Les images ont la même taille.
static func overlap(a: Image, b: Image) -> float:
	var inter := 0
	var uni := 0
	for yy in a.get_height():
		for xx in a.get_width():
			var pa := a.get_pixel(xx, yy).a > 0.5
			var pb := b.get_pixel(xx, yy).a > 0.5
			if pa and pb:
				inter += 1
			if pa or pb:
				uni += 1
	return float(inter) / float(maxi(uni, 1))
