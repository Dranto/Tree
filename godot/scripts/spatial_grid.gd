## Grille spatiale : range les Flétris par cases pour ne tester que les voisins proches
## (collisions des graines, séparation, zones de dégâts) au lieu de toutes les paires.
## Reconstruite à chaque pas de jeu ; l'ordre des résultats est stable (ordre d'insertion),
## pour que deux parties avec la même graine restent identiques.
extends RefCounted

## Côté d'une case : plus grand que le plus gros Flétri (diamètre 50).
const CELL := 64.0

var cells: Dictionary = {}  # Vector2i -> Array


func clear() -> void:
	cells.clear()


func _key(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x / CELL), floori(p.y / CELL))


func insert(item, p: Vector2) -> void:
	var k := _key(p)
	var list = cells.get(k)
	if list == null:
		cells[k] = [item]
	else:
		list.append(item)


## Tous les éléments rangés dans les cases que touche le disque (centre, rayon).
## À l'appelant de vérifier la distance exacte.
func query(center: Vector2, radius: float) -> Array:
	var out: Array = []
	var a := _key(center - Vector2(radius, radius))
	var b := _key(center + Vector2(radius, radius))
	for y in range(a.y, b.y + 1):
		for x in range(a.x, b.x + 1):
			var list = cells.get(Vector2i(x, y))
			if list != null:
				out.append_array(list)
	return out
