## Boursouflé : marche sur le joueur ; en mourant, laisse une poche de spores qui éclate après une
## annonce au sol (enemy_blast.gd) et blesse aussi les Flétris voisins.
extends EnemyBehavior

const Blast = preload("res://scripts/enemy_blast.gd")


func on_death(e) -> void:
	var b = Blast.new()
	b.main = e.main
	b.position = e.position
	b.radius = float(e.data.get("blast_radius", 90.0))
	b.delay = float(e.data.get("blast_delay", 0.9))
	b.damage = float(e.data.get("blast_damage", 20.0)) * e.damage_scale
	b.enemy_damage = float(e.data.get("blast_enemy_damage", 50.0)) * e.power
	b.color = e.color
	e.main.projectiles_layer.call_deferred("add_child", b)
