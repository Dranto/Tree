## Mesures et matériau du bord du monde cuit (world_edge.gd) : mémoire des images gardées, nombre de
## cuissons, durée de la dernière. Séparé de world_edge.gd pour que ses classes internes y accèdent.
extends RefCounted

## Réductions des bandes cuites du bord en cours sur un autre fil (identifiants de WorkerThreadPool),
## attendues à la fermeture (world_edge.gd › _exit_tree).
static var resize_tasks: Array = []
static var bytes := 0
static var baked := 0
static var bake_usec := 0
## Durée du dessin d'une bande dans le SubViewport (µs) : la dernière et la plus longue.
static var paint_usec := 0
static var paint_max_usec := 0
## Durée du tirage des éléments d'une bande (µs), la plus longue.
static var items_max_usec := 0
static var _material: ShaderMaterial


## Matériau des images cuites (alpha prémultiplié, comme les lieux cuits).
static func material() -> ShaderMaterial:
	if _material == null:
		_material = ShaderMaterial.new()
		_material.shader = load("res://shaders/lieux_baked.gdshader")
	return _material
