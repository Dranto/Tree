## Cocon de sève : un bouclier de « shield » × la vie maximale enveloppe le joueur pendant
## « duration » secondes et absorbe les coups (player.gd › take_hit appelle absorb). À la fin (ou
## quand le bouclier est percé), le cocon éclate : ce qui reste du bouclier soigne (« convert » ×),
## et l'éclatement blesse et repousse autour (« damage », « radius », « knockback »).
## Mutations (data/skills.json) : « reflect » (part des dégâts absorbés renvoyée à l'agresseur).
extends Skill

const TornadeScript = preload("res://scripts/skills/tornade.gd")

## Bouclier restant, et sa valeur de départ (pour le dessin).
var shield := 0.0
var shield_max := 0.0
var left := 0.0
var _fx := {}


func cast(p, s := {}) -> void:
	if s.is_empty():
		s = Game.stats
	var k: Dictionary = p.skill("cocon")
	SeveFx.sound("seve_soin", "seve", p.position)
	if shield > 0.0:
		_burst(p)
	shield_max = float(s["max_hp"]) * float(k["shield"])
	shield = shield_max
	left = float(k["duration"])
	_fx = TornadeScript.fx(p, "cocon", {"pos": p.position, "follow": p, "dur": left + 0.4, "r": float(p.radius) * 2.2, "part": 1.0})


## Absorbe « amount » points de dégâts (déjà réduits par l'armure) ; renvoie ce qui passe.
func absorb(amount: float, source) -> float:
	if shield <= 0.0 or amount <= 0.0:
		return amount
	var took := minf(shield, amount)
	shield -= took
	var k: Dictionary = player.skill("cocon")
	var reflect := float(k.get("reflect", 0.0))
	if reflect > 0.0 and is_instance_valid(source) and "dead" in source and not source.dead and source.has_method("take_damage"):
		source.take_damage(took * reflect * player.main.branch_factor(source, "seve"), false)
	if shield <= 0.0:
		_burst(player)
	return amount - took


func tick(delta: float) -> void:
	if shield <= 0.0 or player == null:
		return
	left -= delta
	if not _fx.is_empty():
		_fx["part"] = shield / maxf(shield_max, 1.0)
	if left <= 0.0:
		_burst(player)


func _burst(p) -> void:
	var k: Dictionary = p.skill("cocon")
	var rest := shield
	shield = 0.0
	left = 0.0
	if not _fx.is_empty():
		_fx["t"] = _fx["dur"]
	_fx = {}
	if rest > 0.0:
		p.heal(rest * float(k["convert"]))
	var r: float = float(k["radius"]) * float(Game.stats.get("area", 1.0))
	SeveFx.sound("seve_eclosion", "nova", p.position)
	TornadeScript.fx(p, "cocon_eclat", {"pos": p.position, "r": r})
	p.main.fx.shake(0.15)
	p.main.damage_area(p.position, r, p.skill_damage("cocon"), float(k["knockback"]), "seve")
