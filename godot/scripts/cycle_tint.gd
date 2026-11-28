## Monde fané du cycle (New Game+, jalon 14 W) : teinte des images du monde selon le cycle, palette
## plus sombre et plus grise, une pointe de cendre, encre plus marquée. Réglages dans data/cycles.json ›
## cycles › "<n>" › tint (lus par Cycles.value, le dernier cycle décrit vaut pour les suivants) :
##   dark  part de lumière retirée (0 à 1)        grey  part de désaturation (0 à 1)
##   ink   assombrissement des tons sombres       ash   part de la teinte de cendre (0 à 1)
##   ash_color  teinte de cendre (« #rrggbb »)
## Le cycle 1 n'a pas de réglage : la première aventure ne change pas d'un pixel.
##
## La teinte n'est pas cuite dans les images : elle est appliquée à leur rendu par les shaders du monde
## (shaders/cycle_tint.gdshaderinc, inclus par le décor cuit, les carrés du sol, les lieux et le bord du
## monde, la petite vie), à partir de quatre paramètres globaux posés ici. Un seul cache disque pour
## tous les cycles, rien à recuire au changement de cycle, et la vague de flétrissure (cycle_wave.gd)
## fait avancer la teinte d'un front net depuis la graine.
extends RefCounted

const KEYS := ["dark", "grey", "ink", "ash"]
const ASH_DEFAULT := "#8a8478"
## Rayon du front « partout » (hors de toute vague).
const EVERYWHERE := 1.0e7

## Réglage en cours (tests) : de part et d'autre du front, et le front.
static var from_grade := Vector4.ZERO
static var to_grade := Vector4.ZERO
static var wave := Vector4(0.0, 0.0, EVERYWHERE, 1.0)
static var ash := Vector3(0.5, 0.5, 0.5)


## Réglage du cycle n (x sombre, y gris, z encre, w cendre ; zéro au cycle 1).
static func grade(n: int) -> Vector4:
	var t = Cycles.value("tint", {}, maxi(1, n))
	if not t is Dictionary:
		return Vector4.ZERO
	return Vector4(_k(t, "dark"), _k(t, "grey"), _k(t, "ink"), _k(t, "ash"))


static func _k(t: Dictionary, key: String) -> float:
	return clampf(float(t.get(key, 0.0)), 0.0, 1.0)


## Teinte de cendre du cycle n.
static func ash_color(n: int) -> Color:
	var t = Cycles.value("tint", {}, maxi(1, n))
	var hex := str(t.get("ash_color", ASH_DEFAULT)) if t is Dictionary else ASH_DEFAULT
	return Color.from_string(hex, Color(ASH_DEFAULT))


## Tout le monde à la teinte du cycle n.
static func apply(n: int) -> void:
	var g := grade(n)
	set_state(g, g, Vector2.ZERO, EVERYWHERE, 1.0, ash_color(n))


## Vague : dans le disque (centre, rayon) la teinte « to », au-delà « from », fondue sur « band » px.
static func set_state(from_g: Vector4, to_g: Vector4, center: Vector2, radius: float, band: float, ash_col: Color) -> void:
	from_grade = from_g
	to_grade = to_g
	wave = Vector4(center.x, center.y, radius, maxf(band, 1.0))
	ash = Vector3(ash_col.r, ash_col.g, ash_col.b)
	RenderingServer.global_shader_parameter_set("cycle_tint_from", from_grade)
	RenderingServer.global_shader_parameter_set("cycle_tint_to", to_grade)
	RenderingServer.global_shader_parameter_set("cycle_tint_wave", wave)
	RenderingServer.global_shader_parameter_set("cycle_tint_ash", ash)


## Retour à la première aventure (fin de partie, écran titre).
static func clear() -> void:
	set_state(Vector4.ZERO, Vector4.ZERO, Vector2.ZERO, EVERYWHERE, 1.0, Color(ASH_DEFAULT))


## Même calcul que shaders/cycle_tint.gdshaderinc, côté script (tests, planches) : couleur droite c au
## point « world ».
static func tint_rgb(c: Color, world: Vector2) -> Color:
	var g := to_grade
	var edge := 0.0
	if from_grade != to_grade:
		var d := world.distance_to(Vector2(wave.x, wave.y))
		var w := maxf(wave.w, 1.0)
		g = to_grade.lerp(from_grade, smoothstep(wave.z - w, wave.z, d))
		edge = maxf(0.0, 1.0 - absf(d - wave.z + w * 0.5) / (w * 0.5))
	if g.x + g.y + g.z + g.w + edge <= 0.0:
		return c
	var v := Vector3(c.r, c.g, c.b)
	var luma := Vector3(0.299, 0.587, 0.114)
	var l := v.dot(luma)
	v = v.lerp(Vector3(l, l, l), g.y)
	var la := maxf(ash.dot(luma), 0.01)
	v = v.lerp(ash * (l / la), g.w)
	v *= 1.0 - g.x
	v *= 1.0 - clampf(g.z + edge * 0.35, 0.0, 1.0) * (1.0 - smoothstep(0.06, 0.42, l))
	return Color(v.x, v.y, v.z, c.a)

