## Silhouettes des Flétris en cache (docs/performances.md, jalon 7).
##
## Calculer une silhouette (fletri_art.gd) coûte de 50 à 230 µs de GDScript : à 120 Flétris, c'était
## le plus gros poste des scripts. Une silhouette au repos ou en marche ne dépend que de quelques
## valeurs : sa sorte, son rayon, sa teinte d'état, son regard, la phase de sa marche et celle de son
## animation lente (braises, flocons de cendre). Chaque combinaison, arrondie à une étape, est
## calculée une fois puis gardée en maillage (ArrayMesh) : la redessiner ne coûte plus qu'un appel.
##
## Ce qui reste exact : l'écrasement de la marche et la respiration (appliqués par une
## transformation au moment du dessin), la couleur, la forme. Ce qui est arrondi :
##   - le regard, à 1/32 de tour (la silhouette est tournée du reste, comme entre deux dessins) ;
##   - la phase de la marche, à 1/8 de pas ; une silhouette presque arrêtée est dessinée au repos ;
##   - le temps des animations lentes, à 1/6 de respiration (0,4 s).
## Pendant une action (annonce, charge, coup reçu, frappe), la silhouette est calculée à chaque
## dessin comme avant : ces poses sont brèves et doivent rester fluides.
extends RefCounted

const DrawBatch = preload("res://scripts/draw_batch.gd")
const FletriArt = preload("res://scripts/fletri_art.gd")

const FACES := 32
const WALK_STEPS := 8
const TIME_STEPS := 6
## Période des animations lentes : celle de la respiration (Anim.DUREE["respiration"]).
const TIME_LOOP := 2.4
## Au-delà, le cache est vidé (quelques Mo ; jamais atteint en jeu, une région a 3 ou 4 sortes).
const MAX_MESHES := 8000

static var _meshes := {}
static var _codes := {}
static var _batch = _lean_batch()
## Compteurs (banc de performance).
static var hits := 0
static var misses := 0
## Silhouettes calculées hors du cache (pose d'action), comptées par enemy.gd.
static var live := 0


static func _lean_batch():
	var b = DrawBatch.new()
	b.lean = true
	return b


## Vrai si cette pose peut venir du cache (pas d'action en cours, pas de rendu spécial).
static func cacheable(o: Dictionary) -> bool:
	return not (o.has("flash") or o.has("strike") or o.has("ash") or o.has("mono") or o.has("live")) \
		and o.get("state", "") == "" and float(o.get("k", 0.0)) <= 0.0


## Dessine dans ci (depuis son _draw) l'ombre et la silhouette de la sorte kind_id, centrées en 0.
## shadow_r : rayon de l'ombre portée (dessinée sous la silhouette, dans le même maillage).
static func draw(ci: CanvasItem, kind_id: String, r: float, shadow_r: float, face: Vector2, t: float, o: Dictionary) -> void:
	var turns := kind_id != "nid"
	var ang := face.angle() if turns else 0.0
	var fb := posmod(roundi(ang / TAU * FACES), FACES) if turns else 0
	var wb := 0
	if float(o.get("moving", 0.0)) >= 0.5:
		wb = 1 + posmod(roundi(fposmod(float(o.get("walk", 0.0)), TAU) / TAU * WALK_STEPS), WALK_STEPS)
	var tb := mini(int(fposmod(t, TIME_LOOP) / TIME_LOOP * TIME_STEPS), TIME_STEPS - 1)
	var tint: Color = o.get("tint", Color(0, 0, 0, 0))
	var key := kind_id + "|%d|%d|%d|%d|%d|%s" % [roundi(r * 8.0), roundi(shadow_r * 8.0), fb, wb, tb, tint.to_html()]
	var mesh: ArrayMesh = _meshes.get(key)
	if mesh == null:
		misses += 1
		mesh = _build(kind_id, r, shadow_r, fb, wb, tb, tint)
		if _meshes.size() >= MAX_MESHES:
			_meshes.clear()
		_meshes[key] = mesh
	else:
		hits += 1
	if mesh == null:
		return
	if not turns:
		ci.draw_mesh(mesh, null)
		return
	# Écrasement exact de la pose (marche, respiration), dans le repère du regard ; puis le reste
	# de l'angle arrondi.
	var sq := FletriArt.squash(o, t)
	var base := fb * TAU / FACES
	var xf := Transform2D(ang, Vector2.ZERO) * Transform2D(0.0, sq, 0.0, Vector2.ZERO) * Transform2D(-base, Vector2.ZERO)
	ci.draw_mesh(mesh, null, xf)


static func _build(kind_id: String, r: float, shadow_r: float, fb: int, wb: int, tb: int, tint: Color) -> ArrayMesh:
	var o := {"walk": (wb - 1) * TAU / WALK_STEPS if wb > 0 else 0.0, "moving": 1.0 if wb > 0 else 0.0, "state": "", "k": 0.0, "no_squash": true}
	if tint.a > 0.0:
		o["tint"] = tint
	var face := Vector2.from_angle(fb * TAU / FACES)
	var t := (tb + 0.5) * TIME_LOOP / TIME_STEPS
	_batch.draw_colored_polygon(Art.ellipse(Vector2(0, shadow_r * Art.OMBRE_DECALAGE * 0.5), shadow_r * 1.05, shadow_r * 0.75, 14), Art.c("ombre"))
	FletriArt.draw(_batch, kind_id, Vector2.ZERO, r, face, t, o)
	if _batch.indices.is_empty():
		_batch.clear()
		return null
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = _batch.points
	arrays[Mesh.ARRAY_COLOR] = _batch.colors
	arrays[Mesh.ARRAY_INDEX] = _batch.indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_batch.clear()
	return mesh


static func clear() -> void:
	_meshes.clear()
	hits = 0
	misses = 0
	live = 0
