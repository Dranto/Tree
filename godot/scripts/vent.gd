## Outils communs de la branche Vent (compétences tornade, ruée, appel d'air ; formes « lame » et
## « bourrasque » de l'attaque de base) : pousser et aspirer les ennemis.
##
## Un ennemi ne se déplace pas s'il est ancré (nid, boss : « anchored »), trop gros (main.big_enemies)
## ou marqué "no_push": true dans data/enemies.json (le Menhir des hauts plateaux, par exemple).
class_name Vent
extends RefCounted

const Enemy = preload("res://scripts/enemy.gd")


## Vrai si le vent peut déplacer cet ennemi.
static func can_push(e) -> bool:
	if e == null or not is_instance_valid(e) or e.dead:
		return false
	if e.get("anchored") == true:
		return false
	if float(e.get("radius")) > Enemy.MAX_RADIUS:
		return false
	var d = e.get("data")
	return not (d is Dictionary and d.get("no_push", false))


## Déplace l'ennemi de « by » pixels (s'il peut l'être).
static func push(e, by: Vector2) -> void:
	if can_push(e):
		e.position += by


## Rapproche l'ennemi du point « to » d'au plus « step » pixels, sans passer plus près que « keep ».
static func pull(e, to: Vector2, step: float, keep := 0.0) -> void:
	if not can_push(e):
		return
	var d: Vector2 = to - e.position
	var room := d.length() - keep
	if room <= 0.0:
		return
	e.position += d / d.length() * minf(step, room)
