## Invite d'interaction commune (sanctuaires, autels, secret) : une seule façon de dire
## « tiens-toi ici ». Dessin seulement, à appeler depuis _draw().
##
## - À l'approche, le cercle respire et un chevron rebondit au-dessus de lui (rien à lire).
## - Une fois dedans, un anneau de progression se remplit, avec une pointe lumineuse en tête.
## - Quand l'interaction se termine, l'appelant joue son éclat (flash) ; ici l'anneau se ferme.
## Couleurs : Art.c("interactif") par défaut (ce qui s'utilise est clair et chaud).
extends RefCounted

## Distance à laquelle l'invite apparaît, en rayons du cercle.
const APPROCHE := 3.2


## Intensité de l'invite (0 à 1) selon la distance du joueur au centre : 0 loin, 1 à portée.
static func nearness(dist: float, r: float) -> float:
	return 1.0 - smoothstep(r * 1.1, r * APPROCHE, dist)


## Dessine l'invite centrée sur l'origine du nœud. progress : avancée de 0 à 1.
## near : 0 à 1 (voir nearness). aplati : rapport de l'ellipse (1 = cercle).
static func draw(ci: CanvasItem, r: float, progress: float, t: float, near: float, col := Color(0, 0, 0, 0)) -> void:
	if col.a == 0.0:
		col = Art.c("interactif")
	var pulse := 0.5 + 0.5 * sin(t * TAU / Anim.DUREE["respiration"] * 1.6)
	if progress <= 0.0:
		if near <= 0.01:
			return
		# Invite : le cercle respire, un chevron indique où se tenir.
		ci.draw_arc(Vector2.ZERO, r * (1.0 + 0.04 * pulse), 0.0, TAU, 48, Color(col, near * (0.25 + 0.3 * pulse)), Art.TRAIT_FIN * 1.4, true)
		var bob := 4.0 * sin(t * 4.0)
		var y := -r - 22.0 + bob
		var chev := PackedVector2Array([Vector2(-8, y - 6), Vector2(0, y + 3), Vector2(8, y - 6)])
		ci.draw_polyline(chev, Color(Art.c("contour"), near * 0.7), Art.TRAIT + 1.5, true)
		ci.draw_polyline(chev, Color(col, near), Art.TRAIT, true)
		return
	var k := clampf(progress, 0.0, 1.0)
	var a0 := -PI / 2.0
	var a1 := a0 + TAU * k
	ci.draw_circle(Vector2.ZERO, r, Color(col, 0.05 + 0.08 * k))
	ci.draw_arc(Vector2.ZERO, r + 6.0, a0, a1, 56, Color(Art.c("contour"), 0.55), Art.TRAIT_FORT + 2.0, true)
	ci.draw_arc(Vector2.ZERO, r + 6.0, a0, a1, 56, col.lerp(Color.WHITE, 0.35 * k), Art.TRAIT_FORT, true)
	# Pointe lumineuse en tête de l'anneau, qui s'élargit quand il est presque fermé.
	var head := Vector2.from_angle(a1) * (r + 6.0)
	ci.draw_circle(head, 7.0 + 4.0 * k * pulse, Color(col, 0.3))
	ci.draw_circle(head, 3.8, Color(Art.c("danger_eclair"), 0.95))
