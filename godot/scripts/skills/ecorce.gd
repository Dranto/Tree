## Bouclier d'écorce : des plaques d'écorce couvrent le joueur pendant « duration » secondes et
## absorbent « shield » × sa vie maximale (après l'armure et le cocon : player.gd › _bark_absorb).
## Chaque coup absorbé renvoie des échardes à l'agresseur : « riposte » × les dégâts de la
## compétence (au plus une fois tous les RIPOSTE_EVERY s). À la fin, ou percé, le bouclier éclate :
## « damage », « radius », « knockback ». Mutations (data/skills.json) : « regrow » (le bouclier
## repousse de « regrow » × la vie maximale par seconde, sans dépasser sa valeur de départ).
extends Skill

const TornadeScript = preload("res://scripts/skills/tornade.gd")
const RIPOSTE_EVERY := 0.2

## Bouclier restant, et sa valeur de départ (pour le dessin).
var shield := 0.0
var shield_max := 0.0
var left := 0.0
var _riposte_cd := 0.0
var _fx := {}


func cast(p, s := {}) -> void:
	if s.is_empty():
		s = Game.stats
	var k: Dictionary = p.skill("ecorce")
	RacineFx.sound("racine_ecorce", "racines", p.position)
	if shield > 0.0:
		_burst(p)
	shield_max = float(s["max_hp"]) * float(k["shield"])
	shield = shield_max
	left = float(k["duration"])
	_fx = TornadeScript.fx(p, "ecorce", {"pos": p.position, "follow": p, "dur": left + 0.4, "r": float(p.radius) * 2.0, "part": 1.0,
		"seed": int(p.t * 1000.0) % 997})


## Absorbe « amount » points de dégâts (déjà réduits par l'armure) ; renvoie ce qui passe.
func absorb(amount: float, source) -> float:
	if shield <= 0.0 or amount <= 0.0:
		return amount
	var took := minf(shield, amount)
	shield -= took
	_riposte(source)
	if shield <= 0.0:
		_burst(player)
	return amount - took


## Échardes renvoyées à l'agresseur d'un coup absorbé.
func _riposte(source) -> void:
	if _riposte_cd > 0.0 or player == null:
		return
	if not (is_instance_valid(source) and "dead" in source and not source.dead and "position" in source):
		return
	var part := float(player.skill("ecorce").get("riposte", 0.0))
	if part <= 0.0:
		return
	_riposte_cd = RIPOSTE_EVERY
	TornadeScript.fx(player, "ecorce_riposte", {"pos": player.position, "to": source.position})
	player.main.player_hit_enemy(source, player.skill_damage("ecorce") * part, false, "racine")


func tick(delta: float) -> void:
	_riposte_cd = maxf(0.0, _riposte_cd - delta)
	if shield <= 0.0 or player == null:
		return
	left -= delta
	var regrow := float(player.skill("ecorce").get("regrow", 0.0))
	if regrow > 0.0:
		shield = minf(shield_max, shield + float(Game.stats["max_hp"]) * regrow * delta)
	if not _fx.is_empty():
		_fx["part"] = shield / maxf(shield_max, 1.0)
	if left <= 0.0:
		_burst(player)


func _burst(p) -> void:
	var k: Dictionary = p.skill("ecorce")
	shield = 0.0
	left = 0.0
	if not _fx.is_empty():
		_fx["t"] = _fx["dur"]
	_fx = {}
	var r: float = float(k["radius"]) * float(Game.stats.get("area", 1.0))
	RacineFx.sound("racine_ecorce", "nova", p.position)
	TornadeScript.fx(p, "ecorce_eclat", {"pos": p.position, "r": r, "seed": int(p.t * 1000.0) % 997})
	p.main.fx.shake(0.12)
	p.main.damage_area(p.position, r, p.skill_damage("ecorce"), float(k["knockback"]), "racine")
