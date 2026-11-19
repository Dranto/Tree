## Luciole flétrie (région d'Aube) : petite et rapide, elle fond sur le joueur en zigzaguant
## (« weave » : ampleur du zigzag, de 0 à 1) ; pas d'attaque propre, elle blesse au contact.
## Elles viennent en nombre (Cœur de l'aurore, nuée de la Phalène).
extends EnemyBehavior


func step(e, delta: float, dir: Vector2, _dist: float, slow: float) -> void:
	var weave := float(e.data.get("weave", 0.8))
	var side: Vector2 = dir.orthogonal() * sin(e.t * 5.0 + e.strafe * 1.7) * weave
	e.position += (dir + side).normalized() * e.speed * lerpf(1.0, slow, 0.5) * delta
