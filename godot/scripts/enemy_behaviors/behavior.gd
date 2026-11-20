## Comportement d'ennemi (classe EnemyBehavior) : un par fichier,
## scripts/enemy_behaviors/<nom>.gd « extends EnemyBehavior », choisi par le champ « behavior » de
## la sorte dans data/enemies.json (registre : enemy.gd › behavior_of). Un seul objet par
## comportement, partagé par tous les ennemis qui l'ont : tout l'état vit dans l'ennemi (state,
## state_t, cd, attack_dir…), et chaque méthode le reçoit en premier paramètre.
##
## - step(e, delta, dir, dist, slow) : un pas de jeu (60 par seconde), sauf quand l'ennemi est
##   enraciné. dir : direction du joueur, dist : sa distance, slow : 0,6 sur la terre vivante ;
## - draw_attack(e, k, hit) : annonce de l'attaque (k de 0 à 1 pendant l'annonce) puis éclair de la
##   frappe (hit de 0 à 1, -1 sinon), toujours avec Art.telegraph (charte, § 6), dans le dessin de
##   l'ennemi ;
## - on_death(e) : à sa mort, avant ses restes (la poche de spores du Boursouflé) ;
## - dodge(e) : vrai si l'ennemi esquive un coup direct (le Planeur de cendre en vol haut) ; il en
##   montre lui-même le signe. Le poison et le saignement passent toujours ;
## - calm(e) : vrai si l'état en cours dure longtemps sans action (le vol haut du Planeur) : la
##   silhouette est alors redessinée au rythme ordinaire, pas à chaque image ;
## - pose(e, o) : ajoute à la pose de dessin (dictionnaire o de enemy.pose) ce que le comportement
##   seul connaît (la hauteur du bond du Crapaud…) ; mettre o["live"] = true si la silhouette doit
##   alors être dessinée image par image (hors du cache des silhouettes) ;
## - harmless(e) : vrai tant que l'ennemi ne blesse pas au contact (la Mandragore sous terre) ;
## - hidden(e) : vrai tant que l'ennemi est caché (la Mandragore sous terre) : le tir automatique du
##   joueur ne le choisit pas pour cible ;
## - anchored : vrai pour un ennemi qui ne bouge pas (le Nid).
## Les réglages de la sorte sont dans e.data (enemies.json), mis à l'échelle par e.damage_scale.
class_name EnemyBehavior
extends RefCounted

var anchored := false


## Par défaut : marche droit sur le joueur.
func step(e, delta: float, dir: Vector2, _dist: float, slow: float) -> void:
	e.position += dir * e.speed * slow * delta


func draw_attack(_e, _k: float, _hit: float) -> void:
	pass


func on_death(_e) -> void:
	pass


func dodge(_e) -> bool:
	return false


func calm(_e) -> bool:
	return false


func pose(_e, _o: Dictionary) -> void:
	pass


func harmless(_e) -> bool:
	return false


func hidden(_e) -> bool:
	return false
