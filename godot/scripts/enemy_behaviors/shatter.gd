## Colosse de quartz (région d'Aube) : lourd et lent, il marche droit sur le joueur (champ
## « no_push » : le recul ne le déplace pas). En mourant il vole en éclats : « shards » éclats de
## verre partent en étoile (« shard_speed », « shard_damage », « shard_life »), assez lents pour
## qu'on les voie venir.
extends EnemyBehavior

const Thorn = preload("res://scripts/enemy_thorn.gd")


func on_death(e) -> void:
	var n := int(e.data.get("shards", 6))
	var turn := randf() * TAU
	for i in n:
		var d := Vector2.from_angle(turn + TAU * i / n)
		var th = Thorn.new()
		th.main = e.main
		th.position = e.position + d * (e.radius + 4.0)
		th.vel = d * float(e.data.get("shard_speed", 200.0))
		th.damage = float(e.data.get("shard_damage", 7.0)) * e.damage_scale
		th.life = float(e.data.get("shard_life", 1.6))
		th.look = "verre"
		e.main.projectiles_layer.call_deferred("add_child", th)
