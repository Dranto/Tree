## Compétence active (classe Skill) : une par fichier, scripts/skills/<id>.gd « extends Skill », où
## <id> est sa clé dans data/skills.json. Le joueur (player.gd › cast) remet la recharge à plein,
## puis appelle cast(joueur) ; tick(delta) est appelé à chaque pas tant que la compétence est acquise
## (pour une compétence qui dure : aura, tornade…). Le registre est player.gd › skill_object(id),
## qui charge le fichier la première fois.
##
## Les réglages viennent de data/skills.json (player.skill(id), mutations comprises), les dégâts de
## player.skill_damage(id) (familles d'attaque et bonus « se battre chez soi » compris), la signature
## visuelle de player._sig(id, …) (skill_fx.gd) et le son de Sfx.play.
class_name Skill
extends RefCounted

## Clé de la compétence dans data/skills.json.
var id := ""
## Le joueur qui l'a acquise.
var player


## Lance la compétence. « s » : statistiques du joueur (Game.stats par défaut).
func cast(_p, _s := {}) -> void:
	pass


## Un pas de jeu (60 par seconde), tant que la compétence est acquise.
func tick(_delta: float) -> void:
	pass


## Branche de l'arbre de la compétence (data/skills.json › branch) : ses coups comptent pour elle
## (résistances des ennemis, « se battre chez soi »).
func branch() -> String:
	return str(player.skill(id).get("branch", "")) if player != null else ""
