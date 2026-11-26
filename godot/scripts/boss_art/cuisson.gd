## Règles communes aux cuissons des boss « Bestiaire d'herbier » (refonte des personnages, vague 2).
##
## Quatre façons de cuire un grand dessin coexistent, chacune choisie pour son boss (docs/cuisson-boss.md) :
##   - boss_bake.gd : atlas de poses cuites d'avance (Mère-Ronce, Ancien pétrifié) ;
##   - boss_body_cache.gd : une texture par pose, faite à la demande, cache LRU (Amanite-Mère, Saule) ;
##   - pose_cache.gd : une pose = un nœud qui garde ses commandes de dessin, sans texture (Harfang,
##     Phalène : grandes ailes, trop de mémoire en atlas) ;
##   - boss_art/live_bake.gd : une seule texture redessinée ~20 fois par seconde (la Flétrissure, qui
##     change sans cesse avec la musique).
## Ce qui leur est commun est ici : quand cuire (écran présent, cuisson non coupée), à quelle échelle,
## et quand tout refaire (mode daltonien changé : les couleurs du bestiaire passent par Art.bc).
## Apparence seulement : rien ici ne touche au jeu.
extends RefCounted

const SpriteBake = preload("res://scripts/sprite_bake.gd")

## Incrémenté à chaque changement de palette (Settings.set_colorblind_mode → SpriteBake.palette_changed) :
## une cuisson qui a gardé une autre valeur jette ce qu'elle a cuit.
static var epoch := 0


## Sans écran (--headless) : rien n'est rendu, chaque boss se dessine en direct.
static func no_render() -> bool:
	return DisplayServer.get_name() == "headless"


## Cuire ou dessiner en direct : écran présent et cuisson non coupée (« -- --no-sprites », comme les Flétris).
static func active() -> bool:
	return SpriteBake.enabled and not no_render()


## Échelle d'une cuisson d'après la hauteur de la fenêtre (900 px = 1) : × mult, au pas de step, bornée.
static func window_scale(mult: float, lo: float, hi: float, step := 0.25) -> float:
	var hgt := 900.0
	var ml := Engine.get_main_loop()
	if ml is SceneTree:
		hgt = float((ml as SceneTree).root.size.y)
	return clampf(snappedf(hgt / 900.0 * mult, step), lo, hi)


static func palette_changed() -> void:
	epoch += 1
